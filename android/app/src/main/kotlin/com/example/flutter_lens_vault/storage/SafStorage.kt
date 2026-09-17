package com.example.flutter_lens_vault.storage

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import java.io.File
import java.io.IOException
import java.util.ArrayDeque

/**
 * SAF 是文件树的权威来源。调用方必须在 IO 队列执行；保存日志使复制重试不会生成重复视频。
 * 不解析或拼接 documentId，也不把内容 URI 当作普通路径。
 */
class SafStorage(private val context: Context) {
    private val resolver = context.contentResolver
    private val documentTree = DocumentTree(context)
    private val journal = context.getSharedPreferences("recording_transfers", Context.MODE_PRIVATE)

    fun handle(method: String, arguments: Any?): Any? {
        val args = arguments as? Map<*, *> ?: throw StorageFailure("invalid_argument", "参数格式错误")
        if (method == "forgetRecording") {
            val id = StorageRules.string(args, "operationId")
            checkJournal(journal.edit().remove(id).remove("$id.complete").commit())
            return null
        }
        val rootUri = Uri.parse(StorageRules.string(args, "rootUri"))
        val root = root(rootUri)
        if (method == "validateRoot") return root
        val parentKey = if (method in setOf("listChildren", "createFolder", "saveRecording")) "parentDocumentId" else "documentId"
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
            "renameFolder" -> {
                protectRoot(rootUri, id)
                if (document["isDirectory"] != true) throw StorageFailure("not_directory", "只能重命名文件夹")
                requireFlag(document, "canRename")
                val parent = StorageRules.string(args, "parentDocumentId")
                if (children(rootUri, parent).none { it["documentId"] == id }) throw StorageFailure("not_found", "文件夹已移动")
                val name = StorageRules.name(StorageRules.string(args, "name"))
                checkName(rootUri, parent, name, id)
                val renamed = DocumentsContract.renameDocument(resolver, uri(rootUri, id), name)
                    ?: throw StorageFailure("rename_failed", "无法重命名文件夹")
                read(rootUri, DocumentsContract.getDocumentId(renamed))
            }
            "getDeletionImpact" -> {
                protectRoot(rootUri, id)
                val entries = descendants(rootUri, document)
                mapOf("fileCount" to entries.count { it["isDirectory"] != true },
                    "folderCount" to entries.count { it["isDirectory"] == true && it["documentId"] != id })
            }
            "deleteEntry" -> {
                protectRoot(rootUri, id)
                val entries = descendants(rootUri, document)
                entries.forEach { requireFlag(it, "canDelete") }
                var deleted = 0
                try {
                    for (entry in entries.asReversed()) {
                        if (!DocumentsContract.deleteDocument(resolver, uri(rootUri, entry["documentId"] as String))) {
                            throw StorageFailure("delete_failed", "无法删除 ${entry["name"]}")
                        }
                        deleted++
                    }
                } catch (error: Exception) {
                    if (deleted > 0) throw StorageFailure("partial_delete", "已删除 $deleted 项，其余项目未删除，请刷新后重试", mapOf("deletedCount" to deleted))
                    throw error
                }
                null
            }
            "saveRecording" -> save(rootUri, document, args)
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

    private fun save(tree: Uri, parent: Map<String, Any?>, args: Map<*, *>): Map<String, Any?> {
        requireFlag(parent, "canCreate")
        val id = StorageRules.string(args, "operationId")
        val parentId = parent["documentId"] as String
        val source = File(StorageRules.string(args, "sourcePath")).canonicalFile
        val staging = File(context.filesDir, "recordings").canonicalFile
        if (source.parentFile != staging || !source.isFile || source.length() == 0L) {
            throw StorageFailure("recording_missing", "待保存视频不可用")
        }
        val previous = journal.getString(id, null)?.let(Uri::parse)
        if (previous != null) {
            if (journal.getBoolean("$id.complete", false)) return read(tree, DocumentsContract.getDocumentId(previous))
            try {
                if (!DocumentsContract.deleteDocument(resolver, previous)) throw IOException()
            } catch (error: java.io.FileNotFoundException) {
                // 中断前创建的部分文件已由用户移除，可以重新创建。
            } catch (_: Exception) {
                throw StorageFailure("partial_file", "上次保存的部分文件无法清理，原视频仍保留")
            }
        }
        val name = StorageRules.uniqueName(StorageRules.string(args, "fileName"), children(tree, parentId).map { it["name"] as String })
        val destination = DocumentsContract.createDocument(resolver, uri(tree, parentId), "video/mp4", name)
            ?: throw StorageFailure("create_failed", "无法创建视频文件")
        checkJournal(journal.edit().putString(id, destination.toString()).putBoolean("$id.complete", false).commit())
        try {
            source.inputStream().buffered().use { input ->
                resolver.openOutputStream(destination, "w")?.use { output ->
                    val bytes = input.copyTo(output)
                    output.flush()
                    if (bytes != source.length()) throw IOException("copy length mismatch")
                } ?: throw IOException("output unavailable")
            }
            checkJournal(journal.edit().putBoolean("$id.complete", true).commit())
        } catch (_: Exception) {
            throw StorageFailure("write_failed", "保存失败，视频已保留，可稍后重试")
        }
        return read(tree, DocumentsContract.getDocumentId(destination)) + metadata(destination)
    }

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

    private fun checkJournal(success: Boolean) {
        if (!success) throw StorageFailure("journal_failed", "无法记录保存进度，视频已保留")
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
