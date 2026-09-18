package com.zhao.lens.vault.storage

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document

/**
 * SAF 文档树的共享读取入口；只读取元数据，调用方负责在自己的 IO 队列执行。
 * 不解析 documentId，也不把内容 URI 当作文件路径。
 */
class DocumentTree(private val context: Context) {
    private val resolver = context.contentResolver

    fun uri(tree: Uri, id: String): Uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)

    fun read(tree: Uri, id: String): Map<String, Any?> = query(tree, uri(tree, id)).firstOrNull()
        ?: throw StorageFailure("not_found", "文件或文件夹已移除，或存储设备不可用")

    fun children(tree: Uri, id: String): List<Map<String, Any?>> =
        query(tree, DocumentsContract.buildChildDocumentsUriUsingTree(tree, id))

    fun query(tree: Uri, target: Uri): List<Map<String, Any?>> {
        val writable = resolver.persistedUriPermissions.any { it.uri == tree && it.isWritePermission }
        return resolver.query(target, projection, null, null, null).use { cursor ->
            if (cursor == null) throw StorageFailure("unavailable", "无法读取存储位置")
            buildList {
                while (cursor.moveToNext()) {
                    fun string(key: String): String? = cursor.getColumnIndex(key).let { if (it < 0 || cursor.isNull(it)) null else cursor.getString(it) }
                    fun number(key: String): Long? = cursor.getColumnIndex(key).let { if (it < 0 || cursor.isNull(it)) null else cursor.getLong(it) }
                    val id = string(Document.COLUMN_DOCUMENT_ID) ?: throw StorageFailure("invalid_document", "文档标识缺失")
                    val mime = string(Document.COLUMN_MIME_TYPE)
                    val flags = number(Document.COLUMN_FLAGS) ?: 0L
                    fun supports(flag: Int) = writable && flags and flag.toLong() != 0L
                    add(mapOf("rootUri" to tree.toString(), "documentId" to id, "uri" to uri(tree, id).toString(),
                        "name" to (string(Document.COLUMN_DISPLAY_NAME) ?: "未命名"), "mimeType" to mime,
                        "isDirectory" to (mime == Document.MIME_TYPE_DIR),
                        "size" to number(Document.COLUMN_SIZE)?.takeIf { it >= 0 },
                        "lastModified" to number(Document.COLUMN_LAST_MODIFIED)?.takeIf { it > 0 },
                        "canCreate" to supports(Document.FLAG_DIR_SUPPORTS_CREATE),
                        "canRename" to supports(Document.FLAG_SUPPORTS_RENAME), "canDelete" to supports(Document.FLAG_SUPPORTS_DELETE),
                        "canWrite" to supports(Document.FLAG_SUPPORTS_WRITE),
                        "canMove" to supports(Document.FLAG_SUPPORTS_MOVE)))
                }
            }
        }
    }

    private companion object {
        val projection = arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE, Document.COLUMN_SIZE, Document.COLUMN_LAST_MODIFIED, Document.COLUMN_FLAGS)
    }
}
