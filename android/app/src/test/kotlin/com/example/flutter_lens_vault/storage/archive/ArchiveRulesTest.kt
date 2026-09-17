package com.example.flutter_lens_vault.storage.archive

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ArchiveRulesTest {
    @Test
    fun rejectsUnsafeEntryPaths() {
        val unsafe = listOf(
            "",
            "/etc/passwd",
            "C:/Windows/system32",
            "..",
            "../secret.mp4",
            "a/../../secret.mp4",
            "a\\b.mp4",
            "./a.mp4",
            "a/./b.mp4",
            "a//b.mp4",
            "a\u0000b.mp4",
            "x".repeat(121) + ".mp4",
            (1..40).joinToString("/") { "dir$it" },
        )
        for (path in unsafe) {
            assertNull("应拒绝：$path", ArchiveRules.normalizePath(path))
        }
    }

    @Test
    fun normalizesSafeEntryPathsAndKeepsDirectoryMarker() {
        assertEquals("视频/现场 1.mp4", ArchiveRules.normalizePath("视频/现场 1.mp4"))
        assertEquals("empty/", ArchiveRules.normalizePath("empty/"))
        assertEquals("a/b/c.txt", ArchiveRules.normalizePath("a/b/c.txt"))
        assertEquals("图片/", ArchiveRules.normalizePath("图片/"))
    }

    @Test
    fun comparisonKeyIgnoresCaseAndTrailingSlash() {
        assertEquals(
            ArchiveRules.comparisonKey("Video/A.mp4"),
            ArchiveRules.comparisonKey("video/a.mp4/"),
        )
    }

    @Test
    fun compressionRatioChecksDeclaredSizeAgainstArchiveSize() {
        assertFalse(ArchiveRules.exceedsCompressionRatio(0, 0))
        assertFalse(ArchiveRules.exceedsCompressionRatio(1024, -1))
        // 小文件不参与比例判断，避免误伤。
        assertFalse(ArchiveRules.exceedsCompressionRatio(1024 * 1024, 1024))
        // 声明解压 2 GiB，归档仅 1 MiB，比例 2048 > 200。
        assertTrue(ArchiveRules.exceedsCompressionRatio(2L * 1024 * 1024 * 1024, 1024 * 1024))
    }

    @Test
    fun derivesDefaultZipAndFolderNames() {
        assertEquals("video.zip", ArchiveRules.zipFileName("video.mp4"))
        assertEquals("素材.zip", ArchiveRules.zipFileName("素材"))
        assertEquals("现场 1", ArchiveRules.extractFolderName("现场 1.zip"))
        assertEquals("素材", ArchiveRules.extractFolderName("素材"))
        assertEquals("解压结果", ArchiveRules.extractFolderName(".zip"))
    }
}
