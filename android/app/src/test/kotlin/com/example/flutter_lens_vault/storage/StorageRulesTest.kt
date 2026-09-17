package com.example.flutter_lens_vault.storage

import org.junit.Assert.*
import org.junit.Test
import java.io.IOException

class StorageRulesTest {
    @Test fun rejectsInvalidNames() {
        for (name in listOf("", " ", ".", "..", "../video", "a/b", "a\\b", "a\u0000b", "x".repeat(121))) {
            assertThrows(StorageFailure::class.java) { StorageRules.name(name) }
        }
        assertEquals("现场 1", StorageRules.name(" 现场 1 "))
    }

    @Test fun suffixPreservesExtensionAndSkipsExistingNames() {
        assertEquals("video_02.mp4", StorageRules.uniqueName("video.mp4", listOf("VIDEO.MP4", "video_01.mp4")))
        assertEquals("video.mp4", StorageRules.uniqueName("video.mp4", emptyList()))
    }

    @Test fun rejectsMissingAndWrongTypeArguments() {
        assertThrows(StorageFailure::class.java) { StorageRules.string(mapOf("name" to 1), "name") }
        assertThrows(StorageFailure::class.java) { StorageRules.string(emptyMap<String, Any>(), "rootUri") }
    }

    @Test fun mapsPermissionAndIoFailuresWithoutLeakingPaths() {
        assertEquals("permission_denied", SafStorage.failure(SecurityException("secret path")).code)
        assertEquals("io_error", SafStorage.failure(IOException("secret path")).code)
        assertFalse(SafStorage.failure(IOException("secret path")).message.contains("secret"))
    }
}
