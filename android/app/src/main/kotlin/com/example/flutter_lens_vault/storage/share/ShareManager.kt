package com.example.flutter_lens_vault.storage.share

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import com.example.flutter_lens_vault.storage.StorageFailure
import java.io.File

/**
 * 系统分享入口。
 *
 * - 文档提供方的 URI 经临时读授权直接分享，不额外授予写权限。
 * - 应用私有分享缓存（文件夹临时 ZIP）经 FileProvider 以范围受限的 URI 暴露。
 * - 无接收方时不打开空分享，返回 no_app 由界面提示。
 */
class ShareManager(private val context: Context) {

    fun share(args: Map<*, *>): Map<String, Any?> {
        val documentUris = (args["documentUris"] as? List<*>)?.filterIsInstance<String>().orEmpty()
        val cachePaths = (args["cachePaths"] as? List<*>)?.filterIsInstance<String>().orEmpty()
        val mimeTypes = (args["mimeTypes"] as? List<*>)?.filterIsInstance<String>().orEmpty()
        val title = (args["title"] as? String)?.takeIf { it.isNotBlank() }

        val uris = mutableListOf<Uri>()
        documentUris.forEach { uris.add(Uri.parse(it)) }
        for (path in cachePaths) {
            val file = File(path)
            if (!file.isFile) throw StorageFailure("not_found", "分享缓存已失效，请重新准备")
            uris.add(FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file))
        }
        if (uris.isEmpty()) throw StorageFailure("invalid_argument", "没有可分享的内容")

        val intent = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).apply {
                type = mimeTypes.firstOrNull() ?: "*/*"
                putExtra(Intent.EXTRA_STREAM, uris.first())
            }
        } else {
            Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                type = commonMimeType(mimeTypes)
                putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
            }
        }
        val clip = ClipData.newUri(context.contentResolver, "Lens Vault", uris.first())
        for (uri in uris.drop(1)) clip.addItem(ClipData.Item(uri))
        intent.clipData = clip
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).isEmpty()) {
            return mapOf("result" to "no_app")
        }
        context.startActivity(Intent.createChooser(intent, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return mapOf("result" to "shared", "count" to uris.size)
    }

    /** 多文件分享的公共 MIME：同类型直接用，同大类退化为 type/*，否则 */*。 */
    private fun commonMimeType(mimeTypes: List<String>): String {
        val distinct = mimeTypes.filter { it.isNotBlank() }.distinct()
        if (distinct.isEmpty()) return "*/*"
        if (distinct.size == 1) return distinct.first()
        val prefixes = distinct.map { it.substringBefore('/') }.distinct()
        return if (prefixes.size == 1) "${prefixes.first()}/*" else "*/*"
    }
}
