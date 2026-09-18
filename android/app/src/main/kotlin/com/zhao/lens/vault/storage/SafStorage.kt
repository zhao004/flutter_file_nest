package com.zhao.lens.vault.storage

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.provider.OpenableColumns
import android.util.Size
import android.webkit.MimeTypeMap
import android.graphics.pdf.PdfRenderer
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.ArrayDeque

/**
 * SAF 是文件树的权威来源。调用方必须在 IO 队列执行。
 * 不解析或拼接 documentId，也不把内容 URI 当作普通路径。
 */
class SafStorage(private val context: Context) {
    private val resolver = context.contentResolver
    private val documentTree = DocumentTree(context)

    fun handle(method: String, arguments: Any?): Any? {
        val args = arguments as? Map<*, *> ?: throw StorageFailure("invalid_argument", "参数格式错误")
        val rootUri = Uri.parse(StorageRules.string(args, "rootUri"))
        val root = root(rootUri)
        if (method == "validateRoot") return root
        val parentKey = if (method in setOf("listChildren", "createFolder", "importDocument")) "parentDocumentId" else "documentId"
        val id = StorageRules.string(args, parentKey)
        val document = read(rootUri, id)
        return when (method) {
            "listChildren" -> children(rootUri, id)
            "createFolder" -> {
                requireFlag(document, "canCreate")
                val name = StorageRules.name(StorageRules.string(args, "name"))
                checkName(rootUri, id, name)
                val created = DocumentsContract.createDocument(resolver, uri(rootUri, id), Document.MIME_TYPE_DIR, name)
                    ?: throw StorageFailure("create_failed", "无法创建文件夹")
                read(rootUri, DocumentsContract.getDocumentId(created))
            }
            "renameEntry" -> {
                protectRoot(rootUri, id)
                requireFlag(document, "canRename")
                val parent = StorageRules.string(args, "parentDocumentId")
                if (children(rootUri, parent).none { it["documentId"] == id }) throw StorageFailure("not_found", "文件或文件夹已移动")
                val name = StorageRules.name(StorageRules.string(args, "name"))
                checkName(rootUri, parent, name, id)
                val renamed = DocumentsContract.renameDocument(resolver, uri(rootUri, id), name)
                    ?: throw StorageFailure("rename_failed", "无法重命名文件")
                read(rootUri, DocumentsContract.getDocumentId(renamed))
            }
            "moveEntry" -> move(rootUri, document, args)
            "loadThumbnail" -> thumbnail(uri(rootUri, id), (args["maxDimension"] as? Number)?.toInt() ?: 128)
            "getDeletionImpact" -> {
                protectRoot(rootUri, id)
                val entries = descendants(rootUri, document)
                mapOf("fileCount" to entries.count { it["isDirectory"] != true },
                    "folderCount" to entries.count { it["isDirectory"] == true && it["documentId"] != id })
            }
            "deleteEntry" -> {
                protectRoot(rootUri, id)
                deleteEntryInternal(rootUri, document)
                null
            }
            "importDocument" -> import(sourceUri(args), rootUri, document)
            "readDocument" -> readBytes(uri(rootUri, id))
            "pdfInfo" -> pdfInfo(uri(rootUri, id))
            "pdfPageBytes" -> pdfPage(uri(rootUri, id), (args["page"] as? Number)?.toInt() ?: 0)
            "videoMetadata" -> metadata(uri(rootUri, id))
            "openFile" -> {
                val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri(rootUri, id), document["mimeType"] as? String ?: "application/octet-stream")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                null
            }
            else -> throw StorageFailure("unknown_method", "不支持的文件操作")
        }
    }

    fun root(tree: Uri): Map<String, Any?> {
        if (tree.scheme != "content" || !DocumentsContract.isTreeUri(tree)) throw StorageFailure("invalid_root", "目录标识无效")
        val permission = resolver.persistedUriPermissions.firstOrNull { it.uri == tree && it.isReadPermission }
            ?: throw StorageFailure("permission_denied", "目录访问权限已失效，请重新选择")
        val entry = read(tree, DocumentsContract.getTreeDocumentId(tree)).toMutableMap()
        if (entry["isDirectory"] != true) throw StorageFailure("invalid_root", "所选位置不是文件夹")
        if (!permission.isWritePermission) entry["canCreate"] = false
        return entry
    }

    private fun read(tree: Uri, id: String): Map<String, Any?> = documentTree.read(tree, id)

    private fun children(tree: Uri, id: String): List<Map<String, Any?>> = documentTree.children(tree, id)

    private fun descendants(tree: Uri, target: Map<String, Any?>): List<Map<String, Any?>> {
        val pending = ArrayDeque<Map<String, Any?>>()
        val seen = mutableSetOf<String>()
        val entries = mutableListOf<Map<String, Any?>>()
        pending.add(target)
        while (!pending.isEmpty()) {
            val entry = pending.removeFirst()
            val id = entry["documentId"] as String
            if (!seen.add(id)) throw StorageFailure("invalid_tree", "目录结构重复，操作已停止")
            entries.add(entry)
            if (entry["isDirectory"] == true) pending.addAll(children(tree, id))
        }
        return entries
    }

    /** 删除条目及其后代；部分删除抛出 partial_delete，供调用方提示已删除数量。 */
    private fun deleteEntryInternal(tree: Uri, document: Map<String, Any?>) {
        val id = document["documentId"] as String
        val entries = descendants(tree, document)
        entries.forEach { requireFlag(it, "canDelete") }
        var deleted = 0
        try {
            for (entry in entries.asReversed()) {
                if (!DocumentsContract.deleteDocument(resolver, uri(tree, entry["documentId"] as String))) {
                    throw StorageFailure("delete_failed", "无法删除 ${entry["name"]}")
                }
                deleted++
            }
        } catch (error: Exception) {
            if (deleted > 0) throw StorageFailure("partial_delete", "已删除 $deleted 项，其余项目未删除，请刷新后重试", mapOf("deletedCount" to deleted))
            throw error
        }
    }

    /**
     * 同根移动：优先使用提供方的移动能力；不支持时回退为复制、校验、再删除源。
     * 目标提交成功前不删除源；源删除失败时返回 sourceDeleted=false，由上层提示"复制完成，源未删除"。
     */
    private fun move(tree: Uri, document: Map<String, Any?>, args: Map<*, *>): Map<String, Any?> {
        val id = document["documentId"] as String
        protectRoot(tree, id)
        requireFlag(document, "canDelete")
        val sourceParentId = StorageRules.string(args, "parentDocumentId")
        val targetParentId = StorageRules.string(args, "targetParentDocumentId")
        if (targetParentId == sourceParentId || targetParentId == id) {
            throw StorageFailure("move_invalid_target", "目标位置与来源相同")
        }
        val target = read(tree, targetParentId)
        if (target["isDirectory"] != true) throw StorageFailure("not_directory", "目标位置不是文件夹")
        requireFlag(target, "canCreate")
        if (document["canMove"] == true) {
            val moved = try {
                DocumentsContract.moveDocument(resolver, uri(tree, id), uri(tree, sourceParentId), uri(tree, targetParentId))
            } catch (_: UnsupportedOperationException) {
                // 提供方声明支持但拒绝执行时同样回退复制。
                null
            } catch (_: SecurityException) {
                null
            }
            if (moved != null) {
                return mapOf("entry" to read(tree, DocumentsContract.getDocumentId(moved)), "sourceDeleted" to true)
            }
        }
        val created = copyDocument(tree, document, targetParentId)
        var sourceDeleted = true
        try {
            deleteEntryInternal(tree, document)
        } catch (_: Exception) {
            sourceDeleted = false
        }
        return mapOf("entry" to created, "sourceDeleted" to sourceDeleted)
    }

    /** 递归复制条目；文件按声明大小校验，名称冲突时自动避让，不覆盖已有项目。 */
    private fun copyDocument(tree: Uri, source: Map<String, Any?>, targetParentId: String): Map<String, Any?> {
        val sourceId = source["documentId"] as String
        val isDirectory = source["isDirectory"] == true
        val name = StorageRules.uniqueName(source["name"] as String, children(tree, targetParentId).map { it["name"] as String })
        val mime = if (isDirectory) Document.MIME_TYPE_DIR else source["mimeType"] as? String ?: "application/octet-stream"
        val created = DocumentsContract.createDocument(resolver, uri(tree, targetParentId), mime, name)
            ?: throw StorageFailure("create_failed", "无法创建目标文件")
        val createdId = DocumentsContract.getDocumentId(created)
        if (isDirectory) {
            for (child in children(tree, sourceId)) {
                copyDocument(tree, child, createdId)
            }
        } else {
            copyStream(tree, sourceId, createdId, (source["size"] as? Number)?.toLong())
        }
        return read(tree, createdId)
    }

    private fun copyStream(tree: Uri, sourceId: String, targetId: String, expectedSize: Long?) {
        resolver.openInputStream(uri(tree, sourceId))?.use { input ->
            resolver.openOutputStream(uri(tree, targetId), "w")?.use { output ->
                val copied = input.copyTo(output)
                output.flush()
                if (expectedSize != null && copied != expectedSize) throw IOException("copy length mismatch")
            } ?: throw IOException("output unavailable")
        } ?: throw StorageFailure("read_failed", "无法读取源文件")
    }

    /** 缩略图：优先系统 loadThumbnail（API 29+，图片与视频均适用），旧版本回退视频帧。 */
    private fun thumbnail(target: Uri, size: Int): ByteArray? {
        if (Build.VERSION.SDK_INT >= 29) {
            try {
                val bitmap = resolver.loadThumbnail(target, Size(size, size), null)
                try {
                    val output = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 80, output)
                    return output.toByteArray()
                } finally {
                    // 及时回收原生位图，避免连续加载造成内存抖动。
                    bitmap.recycle()
                }
            } catch (_: Exception) {
                // 图片或视频格式不受支持时回退到帧解码。
            }
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, target)
            val frame = retriever.getFrameAtTime(0) ?: return null
            val scale = size.toDouble() / maxOf(frame.width, frame.height).coerceAtLeast(1)
            val bitmap = Bitmap.createScaledBitmap(frame, (frame.width * scale).toInt().coerceAtLeast(1), (frame.height * scale).toInt().coerceAtLeast(1), true)
            try {
                val output = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 80, output)
                output.toByteArray()
            } finally {
                // createScaledBitmap 可能原样返回源位图，避免重复回收。
                if (bitmap !== frame) bitmap.recycle()
                frame.recycle()
            }
        } catch (_: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    /**
     * 导入外部内容（相册、PDF 或文件选择器结果）到已授权目录。
     * sourceUri 为不透明内容标识或应用私有临时文件的 file:// 标识；复制完成才提交，
     * 复制失败时清理本任务创建的部分产物，不覆盖目标目录中的同名文件。
     */
    private fun import(source: Uri, tree: Uri, parent: Map<String, Any?>): Map<String, Any?> {
        requireFlag(parent, "canCreate")
        val parentId = parent["documentId"] as String
        val (name, mime, size) = sourceMeta(source)
        val target = StorageRules.uniqueName(name, children(tree, parentId).map { it["name"] as String })
        val created = DocumentsContract.createDocument(resolver, uri(tree, parentId), mime ?: "application/octet-stream", target)
            ?: throw StorageFailure("create_failed", "无法创建目标文件")
        try {
            copyUri(source, uri(tree, DocumentsContract.getDocumentId(created)), size)
        } catch (error: Exception) {
            try {
                DocumentsContract.deleteDocument(resolver, created)
            } catch (_: Exception) {
                // 清理失败时保留提示，由用户在目标目录手动移除。
            }
            throw error
        }
        return read(tree, DocumentsContract.getDocumentId(created))
    }

    /** 读取来源的名称、类型与大小；PDF 等特殊文件按扩展名推断 MIME。 */
    private fun sourceMeta(source: Uri): Triple<String, String?, Long?> {
        if (source.scheme == "file") {
            val file = File(source.path ?: throw StorageFailure("invalid_argument", "来源标识无效"))
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase())
            return Triple(file.name, mime, file.length())
        }
        val cursor = resolver.query(source, null, null, null, null)
            ?: throw StorageFailure("not_found", "所选内容不可用，请重新选择")
        return cursor.use {
            if (!it.moveToFirst()) throw StorageFailure("not_found", "所选内容不可用，请重新选择")
            val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            var name = if (nameIndex >= 0 && !it.isNull(nameIndex)) it.getString(nameIndex) else null
            val sizeIndex = it.getColumnIndex(OpenableColumns.SIZE)
            val size = if (sizeIndex >= 0 && !it.isNull(sizeIndex)) it.getLong(sizeIndex).takeIf { value -> value >= 0 } else null
            val mimeIndex = it.getColumnIndex("mime_type")
            var mime = if (mimeIndex >= 0 && !it.isNull(mimeIndex)) it.getString(mimeIndex) else null
            if (mime == null) mime = resolver.getType(source)
            val safeName = try {
                StorageRules.name(name ?: "")
            } catch (_: Exception) {
                "导入_${System.currentTimeMillis()}"
            }
            val extension = safeName.substringAfterLast('.', "")
            if (mime == null && extension.isNotEmpty()) {
                mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase())
            }
            Triple(safeName, mime, size)
        }
    }

    /** 来源 URI 为 content:// 时经 ContentResolver 流式复制，file:// 时直接读流；按已知大小校验完整性。 */
    private fun copyUri(source: Uri, target: Uri, expectedSize: Long?) {
        val input = if (source.scheme == "file") {
            FileInputStream(File(source.path ?: throw StorageFailure("invalid_argument", "来源标识无效"))).buffered()
        } else {
            resolver.openInputStream(source) ?: throw StorageFailure("read_failed", "无法读取所选内容")
        }
        input.use { stream ->
            resolver.openOutputStream(target, "w")?.use { output ->
                val copied = stream.copyTo(output)
                output.flush()
                if (expectedSize != null && copied != expectedSize) throw IOException("copy length mismatch")
            } ?: throw IOException("output unavailable")
        }
    }

    /** 图片预览的字节读取；仅用于应用内预览，不绕过内容提供方。 */
    private fun readBytes(target: Uri): ByteArray {
        val input = resolver.openInputStream(target)
            ?: throw StorageFailure("read_failed", "无法读取文件")
        return input.use { it.readBytes() }
    }

    /** PDF 元信息：页数；受密码保护的 PDF 返回 pdf_protected。 */
    private fun pdfInfo(target: Uri): Map<String, Any?> {
        openPdf(target).use { renderer -> return mapOf("pageCount" to renderer.pageCount) }
    }

    /** 渲染 PDF 单页为 JPEG 字节；按 1080px 宽度等比缩放，白底保证透明背景可见。 */
    private fun pdfPage(target: Uri, index: Int): ByteArray {
        openPdf(target).use { renderer ->
            if (index < 0 || index >= renderer.pageCount) throw StorageFailure("invalid_argument", "页码超出范围")
            renderer.openPage(index).use { page ->
                val scale = 1080.0 / maxOf(page.width, 1)
                val width = (page.width * scale).toInt().coerceAtLeast(1)
                val height = (page.height * scale).toInt().coerceAtLeast(1)
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                val output = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, output)
                bitmap.recycle()
                return output.toByteArray()
            }
        }
    }

    private fun openPdf(target: Uri): PdfRenderer {
        val descriptor = resolver.openFileDescriptor(target, "r")
            ?: throw StorageFailure("not_found", "文件不可用")
        try {
            return PdfRenderer(descriptor)
        } catch (error: SecurityException) {
            descriptor.close()
            throw StorageFailure("pdf_protected", "此 PDF 受密码保护，无法在应用内预览")
        } catch (error: Exception) {
            descriptor.close()
            throw StorageFailure("pdf_invalid", "无法读取此 PDF，文件可能已损坏")
        }
    }

    private fun sourceUri(args: Map<*, *>): Uri = Uri.parse(StorageRules.string(args, "sourceUri"))

    private fun metadata(target: Uri): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, target)
            mapOf("durationMs" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull(),
                "width" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull(),
                "height" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull())
        } catch (_: Exception) { emptyMap() } finally { retriever.release() }
    }

    private fun checkName(tree: Uri, parent: String, name: String, except: String? = null) {
        if (children(tree, parent).any { it["documentId"] != except && (it["name"] as String).equals(name, true) }) {
            throw StorageFailure("name_conflict", "当前目录已存在同名项目")
        }
    }

    private fun protectRoot(tree: Uri, id: String) {
        if (DocumentsContract.getTreeDocumentId(tree) == id) throw StorageFailure("root_protected", "不能修改存储根目录")
    }

    private fun requireFlag(entry: Map<String, Any?>, flag: String) {
        if (entry[flag] != true) throw StorageFailure("read_only", "该存储位置不支持此操作")
    }

    private fun uri(tree: Uri, id: String) = documentTree.uri(tree, id)

    companion object {
        fun failure(error: Exception): StorageFailure = when (error) {
            is StorageFailure -> error
            is SecurityException -> StorageFailure("permission_denied", "目录访问权限已失效，请重新选择")
            is ActivityNotFoundException -> StorageFailure("no_handler", "没有可打开此文件的应用")
            is java.io.FileNotFoundException -> StorageFailure("not_found", "文件或存储设备不可用")
            is IOException -> StorageFailure("io_error", "文件读写失败，请检查存储空间和设备连接")
            else -> StorageFailure("storage_error", "文件操作失败，请刷新后重试")
        }
    }
}
