package com.example.flutter_lens_vault.camera

/**
 * 专业相机后端的纯规则：规格选择、坐标换算与参数范围计算。
 *
 * 与 Android 相机 API 解耦，便于单元测试；调用方负责把设备返回的
 * android.util.Size / Range 转换为本文件的数据类型。
 */
object ProCameraRules {
    /** 像素尺寸；与 android.util.Size 分离以便 JVM 测试。 */
    data class Size(val width: Int, val height: Int) {
        val pixels: Long get() = width.toLong() * height.toLong()

        /** 归一化为横向尺寸，便于跨方向比较（设备可能返回竖屏尺寸）。 */
        fun landscape(): Size = if (width >= height) this else Size(height, width)
    }

    /** 帧率范围（含上下限）。 */
    data class FpsRange(val lower: Int, val upper: Int)

    /** 已解析的录制目标：质量档位与设备尺寸。 */
    data class VideoTarget(val quality: String, val size: Size)

    /** 质量档位，顺序为设备的降级阶梯。 */
    val QUALITY_LADDER = listOf("1080p", "720p", "480p")

    /** 各档目标像素数；用于挑选最接近的设备尺寸。 */
    private val QUALITY_TARGET_PIXELS = mapOf(
        "480p" to 854L * 480L,
        "720p" to 1280L * 720L,
        "1080p" to 1920L * 1080L,
    )

    /** 候选尺寸最低像素比例：低于目标 70% 视为该档不可用，继续降级。 */
    private const val MIN_TARGET_RATIO = 0.7

    /**
     * 选择录制尺寸：从请求档位沿阶梯降级，返回第一个达到目标像素 70% 的候选；
     * 请求 "max" 时取设备最大尺寸；全部档位都不达标时取最大候选兜底。
     */
    fun resolveVideoTarget(quality: String, sizes: List<Size>): VideoTarget? {
        val candidates = sizes.map { it.landscape() }.filter { it.width > 0 && it.height > 0 }
        if (candidates.isEmpty()) return null
        if (quality == "max") {
            val largest = candidates.maxByOrNull { it.pixels } ?: return null
            return VideoTarget("max", largest)
        }
        val ladder = QUALITY_LADDER.dropWhile { it != quality }.ifEmpty {
            QUALITY_LADDER
        }
        for (tier in ladder) {
            val target = QUALITY_TARGET_PIXELS.getValue(tier)
            val size = candidates.minByOrNull { kotlin.math.abs(it.pixels - target) }!!
            if (size.pixels >= target * MIN_TARGET_RATIO) return VideoTarget(tier, size)
        }
        return VideoTarget("max", candidates.maxByOrNull { it.pixels }!!)
    }

    /**
     * 选择固定帧率范围：仅接受上下限相同的范围；请求帧率不可用时返回 null，
     * 由上层按"自动帧率"展示，不把可变范围冒充为固定帧率。
     */
    fun resolveFps(requested: Int?, ranges: List<FpsRange>): Int? {
        if (requested == null) return null
        return ranges.firstOrNull { it.lower == requested && it.upper == requested }?.upper
    }

    /**
     * 选择预览尺寸：在与目标宽高比接近（±5%）的候选中取像素最接近者；
     * 没有匹配时回落到目标尺寸本身（设备可能仍可渲染）。
     */
    fun resolvePreviewSize(video: Size, previewSizes: List<Size>): Size {
        val target = video.landscape()
        val targetRatio = target.width.toDouble() / target.height
        val matching = previewSizes.map { it.landscape() }.filter {
            it.width > 0 && it.height > 0 &&
                kotlin.math.abs(it.width.toDouble() / it.height - targetRatio) <= 0.05
        }
        return matching.minByOrNull { kotlin.math.abs(it.pixels - target.pixels) } ?: target
    }

    /**
     * 计算变焦对应的裁剪区域（active array 坐标系）。
     * 倍率 1.0 为整幅画面，倍率越大裁剪越小；越界值按上下限收敛。
     */
    fun cropRegion(activeWidth: Int, activeHeight: Int, zoom: Double, maxZoom: Double): IntArray {
        val clamped = zoom.coerceIn(1.0, maxZoom.coerceAtLeast(1.0))
        val width = (activeWidth / clamped).toInt().coerceIn(1, activeWidth)
        val height = (activeHeight / clamped).toInt().coerceIn(1, activeHeight)
        val left = (activeWidth - width) / 2
        val top = (activeHeight - height) / 2
        return intArrayOf(left, top, left + width, top + height)
    }

    /**
     * 计算 MediaRecorder 的方向提示：值等于预览显示旋转角。
     * 前摄的镜像只影响预览显示，不改变成品的旋转信息（与 CameraX 后端实测一致）。
     */
    fun orientationHint(deviceDegrees: Int, sensorOrientation: Int): Int =
        previewRotationDegrees(deviceDegrees, sensorOrientation)

    /**
     * 预览与成品的显示旋转角：传感器方向减去设备旋转角度。
     * 前摄预览由调用方额外做水平镜像，不在此处翻转角度。
     */
    fun previewRotationDegrees(deviceDegrees: Int, sensorOrientation: Int): Int {
        val normalized = (deviceDegrees % 360 + 360) % 360
        return (sensorOrientation - normalized + 360) % 360
    }

    /**
     * 显示旋转（Surface.ROTATION_* 常量）对应的旋转角度。
     * 无效值按 0 度处理。
     */
    fun rotationDegrees(rotation: Int): Int = when (rotation) {
        1 -> 90
        2 -> 180
        3 -> 270
        else -> 0
    }

    /** 曝光补偿 EV 值转换为设备索引；步长无效时返回 null。 */
    fun exposureIndex(ev: Double, stepEv: Double): Int? {
        if (stepEv <= 0) return null
        return kotlin.math.round(ev / stepEv).toInt()
    }

    /** 设备索引转换为曝光补偿 EV 值。 */
    fun exposureEv(index: Int, stepEv: Double): Double = index * stepEv

    /**
     * 计算点按区域对应的对焦/测光矩形；归一化坐标 (0..1) 超出范围时收敛。
     * 矩形以中心点为基础，边长取区域短边的 meterSideRatio；返回 left/top/right/bottom。
     */
    fun meteringRect(
        x: Double,
        y: Double,
        activeWidth: Int,
        activeHeight: Int,
        meterSideRatio: Double = 0.1,
    ): IntArray {
        val side = (kotlin.math.min(activeWidth, activeHeight) * meterSideRatio)
            .toInt()
            .coerceAtLeast(1)
        val cx = (x.coerceIn(0.0, 1.0) * activeWidth).toInt()
        val cy = (y.coerceIn(0.0, 1.0) * activeHeight).toInt()
        val left = (cx - side / 2).coerceIn(0, activeWidth - side)
        val top = (cy - side / 2).coerceIn(0, activeHeight - side)
        return intArrayOf(left, top, left + side, top + side)
    }

    /** 质量档位展示文案。 */
    fun qualityLabel(quality: String): String = when (quality) {
        "480p" -> "480p"
        "720p" -> "720p"
        "1080p" -> "1080p"
        "max" -> "设备最高"
        else -> quality
    }
}
