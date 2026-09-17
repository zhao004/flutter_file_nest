package com.example.flutter_lens_vault.storage

import java.util.Locale

/** 与 Android 无关的输入规则，防止路径字符与名称冲突进入文档提供方。 */
object StorageRules {
    fun name(value: String): String {
        val name = value.trim()
        if (name.isEmpty() || name == "." || name == ".." || name.length > 120 ||
            name.any { it.code < 32 || it.code == 127 || it in "\\/:*?\"<>|" }) {
            throw StorageFailure("invalid_name", "名称需为 1 至 120 个字符，且不能含路径或控制字符")
        }
        return name
    }

    fun uniqueName(requested: String, names: Collection<String>): String {
        val normalized = name(requested)
        val existing = names.map { it.lowercase(Locale.ROOT) }.toSet()
        if (normalized.lowercase(Locale.ROOT) !in existing) return normalized
        val dot = normalized.lastIndexOf('.').takeIf { it > 0 } ?: normalized.length
        for (number in 1..9999) {
            val candidate = normalized.substring(0, dot) + "_" + number.toString().padStart(2, '0') + normalized.substring(dot)
            if (candidate.lowercase(Locale.ROOT) !in existing) return candidate
        }
        throw StorageFailure("name_conflict", "无法生成不重复的名称")
    }

    fun string(arguments: Map<*, *>, key: String): String =
        (arguments[key] as? String)?.takeIf { it.isNotBlank() }
            ?: throw StorageFailure("invalid_argument", "缺少有效参数：$key")
}

class StorageFailure(val code: String, override val message: String, val details: Any? = null) : Exception(message)
