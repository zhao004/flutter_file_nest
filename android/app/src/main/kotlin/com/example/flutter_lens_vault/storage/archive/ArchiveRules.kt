package com.example.flutter_lens_vault.storage.archive

/**
 * 归档安全规则与维护上限；与 Android API 解耦，便于单元测试。
 *
 * 上限为可维护常量：解压过程持续计量，不信任归档头声明的大小。
 * 说明：java.util.zip 不暴露 ZIP 条目的 unix 模式，无法识别符号链接条目；
 * 条目名通过本规则校验后只会在目标文档树内逐级创建普通文件，链接条目不会
 * 造成目录逃逸（会被当作普通文件解出）。
 */
object ArchiveRules {
    /** 扫描得到的清单条目；declaredSize 仅用于进度与压缩比检查，不作为可信长度。 */
    data class Entry(val path: String, val isDirectory: Boolean, val declaredSize: Long)

    /** 单次解压允许的最大条目数。 */
    const val MAX_ENTRIES = 5000

    /** 路径最大层级（以 '/' 分隔的段数）。 */
    const val MAX_DEPTH = 32

    /** 单次解压允许的累计最大解压字节数（8 GiB）。 */
    const val MAX_TOTAL_BYTES = 8L * 1024 * 1024 * 1024

    /** 声明解压总量与归档体积的比值上限，用于识别异常压缩比（zip 炸弹）。 */
    const val MAX_COMPRESSION_RATIO = 200.0

    /** 小于该声明的归档不参与压缩比检查，避免误伤小文件。 */
    const val MIN_RATIO_CHECK_BYTES = 1L * 1024 * 1024

    /** 单个路径段的最大长度。 */
    const val MAX_SEGMENT_LENGTH = 120

    /** 流式复制的缓冲区大小。 */
    const val COPY_BUFFER_BYTES = 64 * 1024

    /** 分享缓存保留时长；避免分享返回后立即删除接收方仍在读取的文件。 */
    const val SHARE_CACHE_TTL_MS = 24L * 60 * 60 * 1000

    /** 分享缓存总大小预算。 */
    const val MAX_SHARE_CACHE_BYTES = 1L * 1024 * 1024 * 1024

    /** 小于该年龄的分享缓存不清理，避免影响正在进行的分享。 */
    const val SHARE_CACHE_MIN_KEEP_MS = 5L * 60 * 1000

    /**
     * 校验并归一化归档条目路径；返回以 '/' 分隔的相对路径，目录条目以 '/' 结尾。
     *
     * 拒绝：绝对路径、Windows 盘符、路径穿越（含 ".." 段）、反斜杠分隔、
     * 空段、控制字符、超长段与超过深度上限的路径。无法安全归一化时返回 null。
     */
    fun normalizePath(raw: String): String? {
        if (raw.isEmpty()) return null
        if (raw.contains('\\')) return null
        if (raw.startsWith("/")) return null
        if (raw.length >= 2 && raw[1] == ':') return null
        val isDirectory = raw.endsWith("/")
        val body = raw.trimEnd('/')
        if (body.isEmpty()) return null
        val segments = body.split('/')
        if (segments.size > MAX_DEPTH) return null
        for (segment in segments) {
            if (segment.isEmpty() || segment == "." || segment == "..") return null
            if (segment.length > MAX_SEGMENT_LENGTH) return null
            if (segment.any { it.code < 32 || it.code == 127 }) return null
        }
        return if (isDirectory) "$body/" else body
    }

    /** 归一化用于冲突比较的键：去目录尾斜杠并忽略大小写。 */
    fun comparisonKey(path: String): String = path.trimEnd('/').lowercase()

    /** 声明解压总量相对归档体积是否异常（归档体积未知时不做判断）。 */
    fun exceedsCompressionRatio(declaredUncompressedBytes: Long, archiveBytes: Long): Boolean {
        if (archiveBytes <= 0) return false
        if (declaredUncompressedBytes <= MIN_RATIO_CHECK_BYTES) return false
        return declaredUncompressedBytes.toDouble() / archiveBytes > MAX_COMPRESSION_RATIO
    }

    /** 压缩输出的默认名称：去掉原扩展名后追加 .zip。 */
    fun zipFileName(sourceName: String): String {
        val dot = sourceName.lastIndexOf('.').takeIf { it > 0 } ?: sourceName.length
        return sourceName.substring(0, dot) + ".zip"
    }

    /** 解压目标文件夹的默认名称：去掉 .zip 扩展名。 */
    fun extractFolderName(archiveName: String): String {
        val base = if (archiveName.endsWith(".zip", ignoreCase = true)) {
            archiveName.dropLast(4)
        } else {
            archiveName
        }
        return base.trim().ifBlank { "解压结果" }
    }
}
