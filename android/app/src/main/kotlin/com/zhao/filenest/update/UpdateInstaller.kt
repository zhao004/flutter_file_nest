package com.zhao.filenest.update

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/** 安装失败：code 与 Dart 侧错误码约定一致（permission_required 需先授权）。 */
class UpdateInstallFailure(val code: String, override val message: String) : Exception(message)

/**
 * 安装应用内下载的更新包。
 *
 * - 仅允许 cacheDir/updates 下的 APK，避免任意路径文件被当作安装包；
 * - Android 8.0+ 需用户授予「安装未知应用」权限，未授予时以 permission_required 上报；
 * - 安装包经 FileProvider 以范围受限的 URI 交给系统安装器，不暴露 file:// 路径。
 */
class UpdateInstaller(private val activity: Activity) {
    /** 启动系统安装器；失败抛出 [UpdateInstallFailure]。 */
    fun install(path: String) {
        val apk = resolveApk(path)
            ?: throw UpdateInstallFailure("invalid_file", "安装包不存在或路径不合法")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !activity.packageManager.canRequestPackageInstalls()
        ) {
            throw UpdateInstallFailure("permission_required", "需要允许安装未知应用")
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", apk)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_MIME)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            activity.startActivity(intent)
        } catch (_: Exception) {
            throw UpdateInstallFailure("unavailable", "无法启动系统安装程序")
        }
    }

    /** 打开「安装未知应用」授权页；Android 8.0 以下无需该权限。 */
    fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${activity.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            activity.startActivity(intent)
        } catch (_: Exception) {
            throw UpdateInstallFailure("unavailable", "无法打开安装权限设置")
        }
    }

    /** 解析并校验安装包：必须位于 updates 目录且为已存在的 .apk 文件。 */
    private fun resolveApk(path: String): File? {
        val canonical = try {
            File(path).canonicalFile
        } catch (_: Exception) {
            return null
        }
        val updates = try {
            File(activity.cacheDir, "updates").canonicalFile
        } catch (_: Exception) {
            return null
        }
        if (canonical.parentFile != updates) return null
        if (!canonical.isFile || !canonical.name.endsWith(".apk", ignoreCase = true)) return null
        return canonical
    }

    private companion object {
        const val APK_MIME = "application/vnd.android.package-archive"
    }
}
