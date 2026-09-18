package com.example.flutter_lens_vault.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProCameraRulesTest {
    @Test
    fun picksRequestedVideoTargetAndFallsBackToLowerTier() {
        val full = listOf(
            ProCameraRules.Size(1920, 1080),
            ProCameraRules.Size(1280, 720),
            ProCameraRules.Size(854, 480),
        )
        assertEquals("1080p", ProCameraRules.resolveVideoTarget("1080p", full)!!.quality)
        assertEquals(
            ProCameraRules.Size(1920, 1080),
            ProCameraRules.resolveVideoTarget("1080p", full)!!.size,
        )
        val limited = listOf(ProCameraRules.Size(1280, 720), ProCameraRules.Size(854, 480))
        assertEquals("720p", ProCameraRules.resolveVideoTarget("1080p", limited)!!.quality)
        assertEquals("480p", ProCameraRules.resolveVideoTarget("480p", full)!!.quality)
        assertEquals(
            ProCameraRules.Size(1920, 1080),
            ProCameraRules.resolveVideoTarget("max", full)!!.size,
        )
        assertNull(ProCameraRules.resolveVideoTarget("1080p", emptyList()))
    }

    @Test
    fun normalizesPortraitSizesWhenComparingTargets() {
        val portrait = listOf(ProCameraRules.Size(1080, 1920), ProCameraRules.Size(720, 1280))
        val target = ProCameraRules.resolveVideoTarget("720p", portrait)
        assertEquals("720p", target!!.quality)
        assertEquals(ProCameraRules.Size(1280, 720), target.size)
    }

    @Test
    fun resolvesOnlyFixedFpsRanges() {
        val ranges = listOf(
            ProCameraRules.FpsRange(15, 30),
            ProCameraRules.FpsRange(30, 30),
        )
        assertEquals(30, ProCameraRules.resolveFps(30, ranges))
        assertNull(ProCameraRules.resolveFps(60, ranges))
        assertNull(ProCameraRules.resolveFps(null, ranges))
        assertNull(ProCameraRules.resolveFps(30, emptyList()))
    }

    @Test
    fun picksPreviewSizeWithClosestAspectAndPixels() {
        val video = ProCameraRules.Size(1920, 1080)
        val previews = listOf(
            ProCameraRules.Size(1280, 720),
            ProCameraRules.Size(1920, 1080),
            ProCameraRules.Size(640, 480),
        )
        assertEquals(
            ProCameraRules.Size(1920, 1080),
            ProCameraRules.resolvePreviewSize(video, previews),
        )
        assertEquals(video, ProCameraRules.resolvePreviewSize(video, emptyList()))
    }

    @Test
    fun cropRegionCentersAndClampsZoom() {
        assertEquals(
            listOf(1000, 750, 3000, 2250),
            ProCameraRules.cropRegion(4000, 3000, 2.0, 10.0).toList(),
        )
        assertEquals(
            listOf(0, 0, 4000, 3000),
            ProCameraRules.cropRegion(4000, 3000, 1.0, 10.0).toList(),
        )
        // 超过上限与低于下限都收敛到设备范围。
        assertEquals(
            listOf(0, 0, 4000, 3000),
            ProCameraRules.cropRegion(4000, 3000, 0.2, 10.0).toList(),
        )
        assertEquals(
            listOf(1800, 1350, 2200, 1650),
            ProCameraRules.cropRegion(4000, 3000, 99.0, 10.0).toList(),
        )
    }

    @Test
    fun derivesRotationFromSensorAndDeviceOrientation() {
        assertEquals(0, ProCameraRules.rotationDegrees(0))
        assertEquals(90, ProCameraRules.rotationDegrees(1))
        assertEquals(180, ProCameraRules.rotationDegrees(2))
        assertEquals(270, ProCameraRules.rotationDegrees(3))
        assertEquals(0, ProCameraRules.rotationDegrees(9))
        // 传感器方向减去设备旋转；前摄不做角度翻转（与 CameraX 实测一致）。
        assertEquals(90, ProCameraRules.previewRotationDegrees(0, 90))
        assertEquals(0, ProCameraRules.previewRotationDegrees(90, 90))
        assertEquals(180, ProCameraRules.previewRotationDegrees(270, 90))
        assertEquals(270, ProCameraRules.previewRotationDegrees(0, 270))
        assertEquals(180, ProCameraRules.previewRotationDegrees(90, 270))
        assertEquals(0, ProCameraRules.orientationHint(270, 270))
    }

    @Test
    fun convertsExposureCompensationBetweenEvAndIndex() {
        assertEquals(2, ProCameraRules.exposureIndex(1.0, 0.5))
        assertEquals(-1, ProCameraRules.exposureIndex(-0.3, 0.5))
        assertNull(ProCameraRules.exposureIndex(1.0, 0.0))
        assertEquals(1.0, ProCameraRules.exposureEv(2, 0.5), 1e-9)
    }

    @Test
    fun buildsMeteringRectangleInsideActiveArray() {
        assertEquals(
            listOf(1850, 1350, 2150, 1650),
            ProCameraRules.meteringRect(0.5, 0.5, 4000, 3000).toList(),
        )
        val left = ProCameraRules.meteringRect(0.0, 0.0, 4000, 3000)
        assertEquals(0, left[0])
        assertEquals(0, left[1])
        assertTrue(left[2] - left[0] >= 1)
        assertTrue(left[3] - left[1] >= 1)
    }

    @Test
    fun labelsQualityTiers() {
        assertEquals("1080p", ProCameraRules.qualityLabel("1080p"))
        assertEquals("设备最高", ProCameraRules.qualityLabel("max"))
        assertEquals("自定义", ProCameraRules.qualityLabel("自定义"))
    }
}
