package com.zhao.lens.vault.storage.archive

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import com.zhao.lens.vault.storage.DocumentTree
import com.zhao.lens.vault.storage.StorageFailure
import com.zhao.lens.vault.storage.StorageRules
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/**
 * 归档任务执行器：压缩、解压与分享缓存 ZIP。
 *
 * - 任务串行执行；进度通过 [onEvent] 上报，取消按操作 ID 生效。
 * - 归档格式使用 Android 标准库 java.util.zip（构造器显式指定 UTF-8；
 *   ZIP64 超出 4 GiB 时由库内部处理，Android 未暴露 Zip64Mode 开关），不自实现 ZIP。
 * - 只写入应用私有缓存或已授权文档树；失败与取消只清理本任务创建的产物。
 * - 不承诺全量原子回滚；清理失败时保留可见的部分结果并记录提示。
 * - 目标空间无法通过 SAF 可靠查询，写入失败按 io_error 处理。
 */
class ArchiveManager(
    context: Context,
    private val onEvent: (Map<String, Any?>) -> Unit,
) {
    private val context = context.applicationContext
    private val resolver = this.context.contentResolver
    private val tree = DocumentTree(this.context)
    private val cancellations = ConcurrentHashMap<String, AtomicBoolean>()
    private val shareCacheDir = File(this.context.cacheDir, "share_cache")

    /** 中止信号：取消不是错误，由调用方转换为 cancelled 结果。 */
    private class Cancelled : Exception()

    private class Stats(
        var items: Int = 0,
        var extracted: Int = 0,
        var skipped: Int = 0,
        var failed: Int = 0,
        var bytes: Long = 0,
    )

    private class CopyResult(val bytes: Long, val crc: Long)

    fun handle(method: String, arguments: Any?): Any? {
        val args = arguments as? Map<*, *>
            ?: throw StorageFailure("invalid_argument", "参数格式错误")
        val operationId = StorageRules.string(args, "operationId")
        val cancelled = AtomicBoolean(false)
        cancellations[operationId] = cancelled
        try {
            return when (method) {
                "zip" -> zip(args, operationId, cancelled)
                "cacheZip" -> cacheZip(args, operationId, cancelled)
                "extract" -> extract(args, operationId, cancelled)
                else -> throw StorageFailure("unknown_method", "不支持的归档操作")
            }
        } finally {
            cancellations.remove(operationId)
        }
    }

    fun cancel(operationId: String): Boolean = cancellations[operationId]?.let {
        it.set(true)
        true
    } ?: false

    /**
     * 清理分享缓存：优先保留最近文件，超期或超出预算时删除。
     * 保护期内的文件不清理，避免接收方仍在读取。
     */
    fun cleanupShareCache(): Int {
        val files = shareCacheDir.listFiles()?.filter { it.isFile } ?: return 0
        val now = System.currentTimeMillis()
        var keptBytes = 0L
        var deleted = 0
        for (file in files.sortedByDescending { it.lastModified() }) {
            val age = now - file.lastModified()
            val protected = age < ArchiveRules.SHARE_CACHE_MIN_KEEP_MS
            val expired = age > ArchiveRules.SHARE_CACHE_TTL_MS
            val overBudget = keptBytes + file.length() > ArchiveRules.MAX_SHARE_CACHE_BYTES
            if (!protected && (expired || overBudget)) {
                if (file.delete()) deleted++
            } else {
                keptBytes += file.length()
            }
        }
        return deleted
    }

    // ---- 压缩 ----

    private fun zip(args: Map<*, *>, operationId: String, cancelled: AtomicBoolean): Map<String, Any?> {
        val rootUri = Uri.parse(StorageRules.string(args, "rootUri"))
        val targetId = StorageRules.string(args, "targetDocumentId")
        val target = tree.read(rootUri, targetId)
        requireCreate(target)
        val sources = sourceEntries(args, rootUri)
        val fileName = StorageRules.uniqueName(
            StorageRules.string(args, "fileName"),
            tree.children(rootUri, targetId).map { it["name"] as String },
        )
        val created = DocumentsContract.createDocument(
            resolver, tree.uri(rootUri, targetId), "application/zip", fileName,
        ) ?: throw StorageFailure("create_failed", "无法创建压缩包")
        val createdId = DocumentsContract.getDocumentId(created)
        try {
            val stats = writeZip(rootUri, sources, created, createdId, operationId, cancelled)
            return mapOf(
                "cancelled" to false,
                "target" to tree.read(rootUri, createdId),
                "items" to stats.items,
            )
        } catch (_: Cancelled) {
            runCatching { DocumentsContract.deleteDocument(resolver, created) }
            emitTerminal(operationId, "cancelled", "压缩已取消，未完成的压缩包已清理")
            return mapOf("cancelled" to true)
        } catch (error: Exception) {
            // 失败只清理本任务创建的部分压缩包；不触碰其他用户文件。
            runCatching { DocumentsContract.deleteDocument(resolver, created) }
            emitTerminal(operationId, "failed", StorageFailure.messageOf(error))
            throw error
        }
    }

    private fun writeZip(
        rootUri: Uri,
        sources: List<Map<String, Any?>>,
        target: Uri,
        skipId: String,
        operationId: String,
        cancelled: AtomicBoolean,
    ): Stats {
        val stats = Stats()
        val output = resolver.openOutputStream(target, "w")
            ?: throw StorageFailure("write_failed", "无法写入压缩包")
        var lastEmit = 0L
        BufferedOutputStream(output).use { buffered ->
            ZipOutputStream(buffered, Charsets.UTF_8).use { zip ->
                emit(operationId, "scanning", 0, null, 0, null, true, null)

                fun report() {
                    val now = System.currentTimeMillis()
                    if (now - lastEmit >= 120) {
                        lastEmit = now
                        emit(operationId, "processing", stats.items, null, stats.bytes, null, true, null)
                    }
                }

                fun writeEntry(entry: Map<String, Any?>, prefix: String, depth: Int) {
                    checkCancelled(cancelled)
                    if (depth > ArchiveRules.MAX_DEPTH) {
                        throw StorageFailure("unsafe_tree", "目录层级超过上限（${ArchiveRules.MAX_DEPTH}），已停止压缩")
                    }
                    val name = entry["name"] as String
                    val relative = if (prefix.isEmpty()) name else "$prefix/$name"
                    if (entry["isDirectory"] == true) {
                        val id = entry["documentId"] as String
                        // 输出压缩包（如位于源目录内）不得被递归打包。
                        if (id == skipId) return
                        zip.putNextEntry(ZipEntry("$relative/"))
                        zip.closeEntry()
                        stats.items++
                        report()
                        for (child in tree.children(rootUri, id)) {
                            writeEntry(child, relative, depth + 1)
                        }
                    } else {
                        val id = entry["documentId"] as String
                        if (id == skipId) return
                        zip.putNextEntry(ZipEntry(relative))
                        val input = resolver.openInputStream(tree.uri(rootUri, id))
                            ?: throw StorageFailure("not_found", "无法读取：$name")
                        BufferedInputStream(input).use { source ->
                            val buffer = ByteArray(ArchiveRules.COPY_BUFFER_BYTES)
                            while (true) {
                                checkCancelled(cancelled)
                                val read = source.read(buffer)
                                if (read < 0) break
                                zip.write(buffer, 0, read)
                                stats.bytes += read
                            }
                        }
                        zip.closeEntry()
                        stats.items++
                        report()
                    }
                }

                for (source in sources) writeEntry(source, "", 0)
            }
        }
        emit(operationId, "completed", stats.items, stats.items, stats.bytes, stats.bytes, false, null)
        return stats
    }

    // ---- 分享缓存 ZIP ----

    private fun cacheZip(args: Map<*, *>, operationId: String, cancelled: AtomicBoolean): Map<String, Any?> {
        val rootUri = Uri.parse(StorageRules.string(args, "rootUri"))
        val sources = sourceEntries(args, rootUri)
        val requested = StorageRules.string(args, "fileName")
        if (!shareCacheDir.isDirectory && !shareCacheDir.mkdirs()) {
            throw StorageFailure("cache_unavailable", "无法创建分享缓存目录")
        }
        val file = File(shareCacheDir, "${operationId}_${sanitizeFileName(requested)}")
        try {
            emit(operationId, "scanning", 0, null, 0, null, true, null)
            val stats = Stats()
            var lastEmit = 0L
            FileOutputStream(file).use { output ->
                ZipOutputStream(BufferedOutputStream(output), Charsets.UTF_8).use { zip ->
                    fun writeEntry(entry: Map<String, Any?>, prefix: String, depth: Int) {
                        checkCancelled(cancelled)
                        if (depth > ArchiveRules.MAX_DEPTH) {
                            throw StorageFailure("unsafe_tree", "目录层级超过上限（${ArchiveRules.MAX_DEPTH}），已停止压缩")
                        }
                        val name = entry["name"] as String
                        val relative = if (prefix.isEmpty()) name else "$prefix/$name"
                        if (entry["isDirectory"] == true) {
                            zip.putNextEntry(ZipEntry("$relative/"))
                            zip.closeEntry()
                            stats.items++
                            for (child in tree.children(rootUri, entry["documentId"] as String)) {
                                writeEntry(child, relative, depth + 1)
                            }
                        } else {
                            zip.putNextEntry(ZipEntry(relative))
                            val input = resolver.openInputStream(tree.uri(rootUri, entry["documentId"] as String))
                                ?: throw StorageFailure("not_found", "无法读取：$name")
                            BufferedInputStream(input).use { source ->
                                val buffer = ByteArray(ArchiveRules.COPY_BUFFER_BYTES)
                                while (true) {
                                    checkCancelled(cancelled)
                                    val read = source.read(buffer)
                                    if (read < 0) break
                                    zip.write(buffer, 0, read)
                                    stats.bytes += read
                                }
                            }
                            zip.closeEntry()
                            stats.items++
                        }
                        val now = System.currentTimeMillis()
                        if (now - lastEmit >= 120) {
                            lastEmit = now
                            emit(operationId, "processing", stats.items, null, stats.bytes, null, true, null)
                        }
                    }

                for (source in sources) writeEntry(source, "", 0)
                }
            }
            emit(operationId, "completed", stats.items, stats.items, stats.bytes, stats.bytes, false, null)
            return mapOf("cancelled" to false, "path" to file.absolutePath, "size" to file.length())
        } catch (_: Cancelled) {
            file.delete()
            emitTerminal(operationId, "cancelled", "准备分享已取消")
            return mapOf("cancelled" to true)
        } catch (error: Exception) {
            file.delete()
            emitTerminal(operationId, "failed", StorageFailure.messageOf(error))
            throw error
        }
    }

    // ---- 解压 ----

    private fun extract(args: Map<*, *>, operationId: String, cancelled: AtomicBoolean): Map<String, Any?> {
        val rootUri = Uri.parse(StorageRules.string(args, "rootUri"))
        val archiveId = StorageRules.string(args, "archiveDocumentId")
        val parentId = StorageRules.string(args, "targetParentDocumentId")
        val parent = tree.read(rootUri, parentId)
        requireCreate(parent)
        val archive = tree.read(rootUri, archiveId)
        val archiveUri = tree.uri(rootUri, archiveId)
        val archiveBytes = (archive["size"] as? Number)?.toLong() ?: -1L
        // 清单扫描与执行分开；执行阶段重新打开归档流并重新检查路径与冲突。
        val manifest = scan(archiveUri, archiveBytes, operationId, cancelled)
        val folderName = StorageRules.uniqueName(
            StorageRules.string(args, "folderName"),
            tree.children(rootUri, parentId).map { it["name"] as String },
        )
        val folder = DocumentsContract.createDocument(
            resolver, tree.uri(rootUri, parentId), Document.MIME_TYPE_DIR, folderName,
        ) ?: throw StorageFailure("create_failed", "无法创建解压文件夹")
        val folderId = DocumentsContract.getDocumentId(folder)
        val createdFiles = mutableListOf<String>()
        val createdDirs = mutableListOf<String>()
        try {
            val stats = extractEntries(
                rootUri, archiveUri, folderId, manifest,
                createdFiles, createdDirs, operationId, cancelled,
            )
            emit(
                operationId, "completed", stats.extracted + stats.skipped, manifest.size,
                stats.bytes, null, false, null,
            )
            return mapOf(
                "cancelled" to false,
                "target" to tree.read(rootUri, folderId),
                "extracted" to stats.extracted,
                "skipped" to stats.skipped,
                "failed" to stats.failed,
            )
        } catch (_: Cancelled) {
            cleanup(rootUri, createdFiles, createdDirs, folderId)
            emitTerminal(operationId, "cancelled", "解压已取消，未完成内容已清理")
            return mapOf("cancelled" to true)
        } catch (error: Exception) {
            cleanup(rootUri, createdFiles, createdDirs, folderId)
            emitTerminal(operationId, "failed", StorageFailure.messageOf(error))
            throw error
        }
    }

    /** 扫描清单：校验路径、统计条目与声明大小、识别重复，不写入任何目标文件。 */
    private fun scan(
        archiveUri: Uri,
        archiveBytes: Long,
        operationId: String,
        cancelled: AtomicBoolean,
    ): List<ArchiveRules.Entry> {
        val entries = mutableListOf<ArchiveRules.Entry>()
        val occupied = mutableSetOf<String>()
        val fileKeys = mutableSetOf<String>()
        var declaredBytes = 0L
        var seen = 0
        openArchive(archiveUri).use { zip ->
            while (true) {
                checkCancelled(cancelled)
                val entry = zip.nextEntry ?: break
                seen++
                if (seen > ArchiveRules.MAX_ENTRIES) {
                    throw StorageFailure("unsafe_archive", "归档条目数超过上限（${ArchiveRules.MAX_ENTRIES}）")
                }
                val path = ArchiveRules.normalizePath(entry.name)
                    ?: throw StorageFailure("unsafe_archive", "归档包含不安全的条目名称：${entry.name.take(80)}")
                val key = ArchiveRules.comparisonKey(path)
                val parentIsFile = ancestorKeys(key).any { it in fileKeys }
                if (parentIsFile || !occupied.add(key)) {
                    // 重复路径、文件与目录同名或大小写冲突：保留首次出现，其余跳过。
                    continue
                }
                if (!entry.isDirectory) fileKeys.add(key)
                val declared = entry.size.takeIf { it > 0 } ?: 0L
                declaredBytes += declared
                entries.add(ArchiveRules.Entry(path, entry.isDirectory, declared))
                if (seen % 64 == 0) {
                    emit(operationId, "scanning", entries.size, null, declaredBytes, null, true, null)
                }
            }
        }
        if (ArchiveRules.exceedsCompressionRatio(declaredBytes, archiveBytes)) {
            throw StorageFailure("unsafe_archive", "归档压缩比异常，已拒绝解压")
        }
        emit(operationId, "scanning", entries.size, entries.size, declaredBytes, declaredBytes, true, null)
        return entries
    }

    private fun extractEntries(
        rootUri: Uri,
        archiveUri: Uri,
        folderId: String,
        manifest: List<ArchiveRules.Entry>,
        createdFiles: MutableList<String>,
        createdDirs: MutableList<String>,
        operationId: String,
        cancelled: AtomicBoolean,
    ): Stats {
        val stats = Stats()
        val byKey = manifest.associateBy { ArchiveRules.comparisonKey(it.path) }
        val dirIds = mutableMapOf("" to folderId)
        val occupied = mutableSetOf<String>()
        val failedFileKeys = mutableSetOf<String>()
        var lastEmit = 0L
        openArchive(archiveUri).use { zip ->
            while (true) {
                checkCancelled(cancelled)
                val entry = zip.nextEntry ?: break
                val path = ArchiveRules.normalizePath(entry.name) ?: continue
                val key = ArchiveRules.comparisonKey(path)
                val planned = byKey[key]
                if (planned == null ||
                    !occupied.add(key) ||
                    ancestorKeys(key).any { it in failedFileKeys }
                ) {
                    stats.skipped++
                    continue
                }
                val segments = path.trimEnd('/').split('/')
                if (planned.isDirectory) {
                    val id = ensureDirectory(rootUri, folderId, segments, dirIds, createdDirs)
                    if (id == null) {
                        stats.failed++
                    } else {
                        stats.extracted++
                    }
                } else {
                    val parent = ensureDirectory(
                        rootUri, folderId, segments.dropLast(1), dirIds, createdDirs,
                    )
                    if (parent == null) {
                        stats.failed++
                        failedFileKeys.add(key)
                        continue
                    }
                    try {
                        val created = DocumentsContract.createDocument(
                            resolver, tree.uri(rootUri, parent),
                            mimeTypeFor(entry.name), segments.last(),
                        ) ?: throw StorageFailure("create_failed", "无法创建 ${segments.last()}")
                        val createdId = DocumentsContract.getDocumentId(created)
                        createdFiles.add(createdId)
                        val copied = copyEntry(zip, created, cancelled)
                        zip.closeEntry()
                        stats.bytes += copied.bytes
                        if (stats.bytes > ArchiveRules.MAX_TOTAL_BYTES) {
                            throw StorageFailure("unsafe_archive", "解压内容超过大小上限，已停止")
                        }
                        if (entry.size >= 0 && copied.bytes != entry.size) {
                            throw StorageFailure("corrupt_archive", "归档内容与记录大小不一致：${segments.last()}")
                        }
                        if (entry.crc >= 0 && copied.crc != entry.crc) {
                            throw StorageFailure("corrupt_archive", "归档内容校验失败：${segments.last()}")
                        }
                        stats.extracted++
                    } catch (error: Cancelled) {
                        throw error
                    } catch (error: StorageFailure) {
                        throw error
                    } catch (_: Exception) {
                        stats.failed++
                        failedFileKeys.add(key)
                    }
                }
                val now = System.currentTimeMillis()
                if (now - lastEmit >= 120) {
                    lastEmit = now
                    emit(
                        operationId, "processing", stats.extracted + stats.skipped, manifest.size,
                        stats.bytes, null, true, null,
                    )
                }
            }
        }
        return stats
    }

    private fun copyEntry(zip: ZipInputStream, destination: Uri, cancelled: AtomicBoolean): CopyResult {
        val output = resolver.openOutputStream(destination, "w")
            ?: throw StorageFailure("write_failed", "无法写入解压文件")
        val crc = CRC32()
        var written = 0L
        BufferedOutputStream(output).use { sink ->
            val buffer = ByteArray(ArchiveRules.COPY_BUFFER_BYTES)
            while (true) {
                checkCancelled(cancelled)
                val read = zip.read(buffer)
                if (read < 0) break
                sink.write(buffer, 0, read)
                crc.update(buffer, 0, read)
                written += read
            }
            sink.flush()
        }
        return CopyResult(written, crc.value)
    }

    /** 在任务根目录下逐级创建并缓存目录；返回 null 表示该层创建失败。 */
    private fun ensureDirectory(
        rootUri: Uri,
        folderId: String,
        segments: List<String>,
        dirIds: MutableMap<String, String>,
        createdDirs: MutableList<String>,
    ): String? {
        var parentId = folderId
        var prefix = ""
        for (segment in segments) {
            prefix = if (prefix.isEmpty()) segment else "$prefix/$segment"
            val key = ArchiveRules.comparisonKey(prefix)
            dirIds[key]?.let {
                parentId = it
                continue
            }
            val created = DocumentsContract.createDocument(
                resolver, tree.uri(rootUri, parentId), Document.MIME_TYPE_DIR, segment,
            ) ?: return null
            parentId = DocumentsContract.getDocumentId(created)
            createdDirs.add(parentId)
            dirIds[key] = parentId
        }
        return parentId
    }

    /** 只清理本任务登记的产物：先文件后目录，最后删除本任务创建的解压根目录。 */
    private fun cleanup(
        rootUri: Uri,
        createdFiles: List<String>,
        createdDirs: List<String>,
        folderId: String,
    ) {
        createdFiles.asReversed().forEach {
            runCatching { DocumentsContract.deleteDocument(resolver, tree.uri(rootUri, it)) }
        }
        createdDirs.asReversed().forEach {
            runCatching { DocumentsContract.deleteDocument(resolver, tree.uri(rootUri, it)) }
        }
        runCatching { DocumentsContract.deleteDocument(resolver, tree.uri(rootUri, folderId)) }
    }

    // ---- 公共辅助 ----

    private fun sourceEntries(args: Map<*, *>, rootUri: Uri): List<Map<String, Any?>> {
        val raw = args["entries"] as? List<*>
            ?: throw StorageFailure("invalid_argument", "缺少待处理条目")
        if (raw.isEmpty()) throw StorageFailure("invalid_argument", "没有可处理的条目")
        return raw.map { value ->
            val map = value as? Map<*, *>
                ?: throw StorageFailure("invalid_argument", "条目格式错误")
            tree.read(rootUri, StorageRules.string(map, "documentId"))
        }
    }

    private fun openArchive(archiveUri: Uri): ZipInputStream {
        val input = resolver.openInputStream(archiveUri)
            ?: throw StorageFailure("not_found", "无法读取压缩包")
        return ZipInputStream(BufferedInputStream(input), Charsets.UTF_8)
    }

    private fun requireCreate(folder: Map<String, Any?>) {
        if (folder["canCreate"] != true) throw StorageFailure("read_only", "该存储位置不支持写入")
    }

    private fun checkCancelled(cancelled: AtomicBoolean) {
        if (cancelled.get()) throw Cancelled()
    }

    private fun ancestorKeys(key: String): List<String> {
        val result = mutableListOf<String>()
        var slash = key.lastIndexOf('/')
        while (slash > 0) {
            result.add(key.substring(0, slash))
            slash = key.lastIndexOf('/', slash - 1)
        }
        return result
    }

    private fun mimeTypeFor(name: String): String {
        val extension = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
        return when (extension) {
            "mp4" -> "video/mp4"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "txt" -> "text/plain"
            "json" -> "application/json"
            "zip" -> "application/zip"
            else -> "application/octet-stream"
        }
    }

    private fun sanitizeFileName(name: String): String = name
        .map { if (it.isLetterOrDigit() || it == '.' || it == '-' || it == '_') it else '_' }
        .joinToString("")
        .take(80)
        .ifBlank { "share.zip" }

    private fun emit(
        operationId: String,
        stage: String,
        items: Int,
        totalItems: Int?,
        bytes: Long,
        totalBytes: Long?,
        canCancel: Boolean,
        message: String?,
    ) {
        onEvent(mapOf(
            "operationId" to operationId,
            "stage" to stage,
            "processedItems" to items,
            "totalItems" to totalItems,
            "processedBytes" to bytes,
            "totalBytes" to totalBytes,
            "canCancel" to canCancel,
            "message" to message,
        ))
    }

    private fun emitTerminal(operationId: String, stage: String, message: String) {
        emit(operationId, stage, 0, null, 0, null, false, message)
    }
}

