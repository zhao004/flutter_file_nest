package com.example.flutter_lens_vault.camera

import android.content.Context
import android.graphics.Rect
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.MeteringRectangle
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Range
import android.util.Size
import android.view.Surface
import android.view.WindowManager
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * 独占的原生 Camera2 录像后端。
 *
 * 与 camera 插件互斥运行：只有在本后端取得设备时才会打开摄像头，切换后端前
 * 必须先释放本会话。所有命令在单线程队列串行执行；相机回调在独立的
 * HandlerThread 上派发，通过锁存器与命令线程同步，避免并发销毁会话。
 *
 * 预览由 PlatformView 持有的 TextureView 提供 Surface；停止、失败与页面退出
 * 时释放会话和设备，录像文件写入应用私有缓存目录，交由上层保存链路登记。
 */
class ProCameraManager(private val context: Context) {
    private val executor = Executors.newSingleThreadExecutor()
    private val callbackThread = HandlerThread("pro-camera-callback").apply { start() }
    private val callbackHandler = Handler(callbackThread.looper)
    private val mainHandler = Handler(context.mainLooper)
    private val cameraManager =
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null

    @Volatile
    private var characteristics: CameraCharacteristics? = null
    private var cameraId: String? = null

    @Volatile
    private var frontFacing = false
    private var activeArray: Rect? = null

    private var videoTarget: ProCameraRules.VideoTarget? = null

    @Volatile
    private var previewSize: Size? = null
    private var acceptedFps: Int? = null
    private var acceptedBitrateBps: Int? = null
    private var audioEnabled = false

    private var previewSurface: Surface? = null
    private var previewTexture: SurfaceTexture? = null
    private var recorder: MediaRecorder? = null
    private var videoSurface: Surface? = null
    private var outputFile: File? = null
    private var recording = false

    private var zoom = 1.0
    private var torch = false
    private var exposureIndex = 0
    private var stabilizationOn = false
    private var focusPoint: Pair<Double, Double>? = null
    private var exposurePoint: Pair<Double, Double>? = null

    /** 在命令队列中执行；所有公开入口必须通过这里串行化。 */
    fun post(action: () -> Unit) {
        executor.execute(action)
    }

    /**
     * 处理平台通道调用；必须在命令队列中执行（[post]）。
     * 返回值必须为可经 StandardMessageCodec 传递的类型。
     */
    fun handle(method: String, arguments: Any?): Any? {
        val args = arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        return when (method) {
            "cameras" -> cameras()
            "initialize" -> initialize(args)
            "dispose" -> {
                release()
                null
            }
            "zoomRange" -> mapOf("min" to 1.0, "max" to (maximumZoom() ?: 1.0))
            "capabilities" -> capabilities()
            "setZoom" -> setZoom(number(args, "ratio"))
            "setExposureOffset" -> setExposureOffset(number(args, "ev"))
            "resetExposureOffset" -> setExposureOffset(0.0)
            "setTorch" -> setTorch(args["enabled"] == true)
            "setFocusPoint" -> setFocusPoint(point(args))
            "setExposurePoint" -> setExposurePoint(point(args))
            "stabilizationModes" -> stabilizationModes()
            "setStabilization" -> setStabilization(args["mode"] as? String)
            "start" -> start()
            "stop" -> stop()
            "probeVideo" -> probeVideo(string(args, "path"))
            else -> throw ProCameraFailure("unknown_method", "不支持的专业相机操作")
        }
    }

    // ---------------------------------------------------------------- 相机枚举

    private fun cameras(): List<Map<String, Any?>> = cameraManager.cameraIdList.map { id ->
        val info = cameraManager.getCameraCharacteristics(id)
        mapOf(
            "id" to id,
            "facing" to when (info.get(CameraCharacteristics.LENS_FACING)) {
                CameraCharacteristics.LENS_FACING_FRONT -> "front"
                CameraCharacteristics.LENS_FACING_BACK -> "back"
                else -> "external"
            },
            "sensorOrientation" to
                (info.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0),
        )
    }

    // ---------------------------------------------------------------- 会话管理

    private fun initialize(args: Map<*, *>): Map<String, Any?> {
        val id = string(args, "cameraId")
        val quality = (args["quality"] as? String)?.takeIf { it.isNotBlank() } ?: "1080p"
        val requestedFps = (args["fps"] as? Number)?.toInt()
        val requestedBitrate = (args["bitrateBps"] as? Number)?.toInt()
        val audio = args["audio"] == true
        release()
        cleanupStaleRecordings()
        val info = cameraManager.getCameraCharacteristics(id)
        val map = info.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            ?: throw ProCameraFailure("camera_unavailable", "无法读取相机配置")
        val videoSizes = map.getOutputSizes(MediaRecorder::class.java)?.toList().orEmpty()
        val target = ProCameraRules.resolveVideoTarget(quality, videoSizes.map { it.toRuleSize() })
            ?: throw ProCameraFailure("camera_unavailable", "相机未提供可用的录像尺寸")
        val fpsRanges = info.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
            ?.map { ProCameraRules.FpsRange(it.lower, it.upper) }.orEmpty()
        val resolvedFps = ProCameraRules.resolveFps(requestedFps, fpsRanges)
        val textureSizes = map.getOutputSizes(SurfaceTexture::class.java)?.toList().orEmpty()
        val preview = ProCameraRules.resolvePreviewSize(
            target.size,
            textureSizes.map { it.toRuleSize() },
        ).toAndroidSize()

        characteristics = info
        cameraId = id
        frontFacing = info.get(CameraCharacteristics.LENS_FACING) ==
            CameraCharacteristics.LENS_FACING_FRONT
        activeArray = info.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
        videoTarget = target
        previewSize = preview
        acceptedFps = resolvedFps
        acceptedBitrateBps = requestedBitrate
        audioEnabled = audio
        zoom = 1.0
        torch = false
        exposureIndex = 0
        stabilizationOn = false
        focusPoint = null
        exposurePoint = null
        openDevice(id)
        if (previewSurface != null) {
            subscribeSession(previewSurface!!, recordingTarget = false)
        }
        return acceptedSummary()
    }

    private fun acceptedSummary(): Map<String, Any?> = mapOf(
        "quality" to (videoTarget?.quality ?: "1080p"),
        "width" to (videoTarget?.size?.width ?: 0),
        "height" to (videoTarget?.size?.height ?: 0),
        "fps" to acceptedFps,
        "bitrateBps" to acceptedBitrateBps,
        "previewWidth" to (previewSize?.width ?: 0),
        "previewHeight" to (previewSize?.height ?: 0),
    )

    private fun release() {
        if (recording) {
            // 上层未完成停止即释放：尽力结束录制并保留文件（缓存目录由系统回收）。
            try {
                recorder?.stop()
            } catch (_: Exception) {
                /* 停止失败时保留文件，由缓存策略回收。 */
            }
            recording = false
        }
        recorder?.release()
        recorder = null
        videoSurface?.release()
        videoSurface = null
        session?.close()
        session = null
        device?.close()
        device = null
        characteristics = null
        cameraId = null
        videoTarget = null
        previewSize = null
        acceptedFps = null
        acceptedBitrateBps = null
        activeArray = null
        outputFile = null
    }

    private fun openDevice(id: String) {
        val latch = CountDownLatch(1)
        var failure: Exception? = null
        try {
            cameraManager.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    device = camera
                    latch.countDown()
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    if (device === camera) device = null
                    failure = ProCameraFailure("camera_disconnected", "相机已断开或被其他应用占用")
                    latch.countDown()
                    if (this@ProCameraManager.cameraId != null) {
                        post { release() }
                    }
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    if (device === camera) device = null
                    failure = ProCameraFailure("camera_error", "相机打开失败（错误码 $error）")
                    latch.countDown()
                }
            }, callbackHandler)
        } catch (error: CameraAccessException) {
            throw ProCameraFailure("camera_access", "无相机访问权限", error)
        } catch (error: SecurityException) {
            throw ProCameraFailure("camera_access", "无相机访问权限", error)
        } catch (error: IllegalArgumentException) {
            throw ProCameraFailure("camera_unavailable", "相机标识不可用", error)
        }
        if (!latch.await(CALLBACK_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            throw ProCameraFailure("camera_timeout", "打开相机超时")
        }
        failure?.let { throw it }
        if (device == null) throw ProCameraFailure("camera_error", "相机未能打开")
    }

    private fun subscribeSession(
        target: Surface,
        recordingTarget: Boolean,
        applyRequest: Boolean = true,
    ) {
        val camera = device ?: throw ProCameraFailure("session_closed", "相机会话已关闭")
        val surfaces = linkedSetOf(target)
        if (recordingTarget && previewSurface != null && previewSurface !== target) {
            surfaces.add(previewSurface!!)
        }
        val latch = CountDownLatch(1)
        var created: CameraCaptureSession? = null
        var failure: Exception? = null
        try {
            camera.createCaptureSession(surfaces.toList(),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(configured: CameraCaptureSession) {
                        created = configured
                        latch.countDown()
                    }

                    override fun onConfigureFailed(failed: CameraCaptureSession) {
                        failed.close()
                        failure = ProCameraFailure("session_failed", "无法配置相机会话")
                        latch.countDown()
                    }
                }, callbackHandler)
        } catch (error: CameraAccessException) {
            throw ProCameraFailure("session_failed", "无法配置相机会话", error)
        } catch (error: IllegalStateException) {
            throw ProCameraFailure("session_closed", "相机会话已关闭", error)
        }
        if (!latch.await(CALLBACK_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            throw ProCameraFailure("session_timeout", "配置相机会话超时")
        }
        failure?.let { throw it }
        session = created ?: throw ProCameraFailure("session_failed", "无法配置相机会话")
        if (applyRequest) applyRepeatingRequest()
    }

    /** 按当前状态下发重复请求；会话不可用时忽略。 */
    private fun applyRepeatingRequest() {
        val current = session ?: return
        val target = if (recording) videoSurface else previewSurface
        if (target == null) return
        try {
            current.setRepeatingRequest(
                buildRequest(
                    if (recording) CameraDevice.TEMPLATE_RECORD
                    else CameraDevice.TEMPLATE_PREVIEW,
                    target,
                ),
                null,
                callbackHandler,
            )
        } catch (error: CameraAccessException) {
            throw ProCameraFailure("session_failed", "相机请求下发失败", error)
        } catch (error: IllegalStateException) {
            throw ProCameraFailure("session_closed", "相机会话已关闭", error)
        }
    }

    /** 构建相机请求：模板 + 预览目标 + 变焦/曝光/补光/区域/防抖（手动参数在后续扩展）。 */
    private fun buildRequest(template: Int, target: Surface): CaptureRequest {
        val camera = device ?: throw ProCameraFailure("session_closed", "相机会话已关闭")
        val builder = camera.createCaptureRequest(template)
        builder.addTarget(target)
        if (previewSurface != null && previewSurface !== target) {
            builder.addTarget(previewSurface!!)
        }
        builder.set(CaptureRequest.CONTROL_MODE, CameraCharacteristics.CONTROL_MODE_AUTO)
        builder.set(
            CaptureRequest.CONTROL_AF_MODE,
            CameraCharacteristics.CONTROL_AF_MODE_CONTINUOUS_VIDEO,
        )
        val range = characteristics
            ?.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
        if (range != null) {
            builder.set(
                CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
                exposureIndex.coerceIn(range.lower, range.upper),
            )
        }
        acceptedFps?.let {
            builder.set(
                CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                Range(it, it),
            )
        }
        if (recording && stabilizationSupported()) {
            builder.set(
                CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE,
                if (stabilizationOn) {
                    CameraCharacteristics.CONTROL_VIDEO_STABILIZATION_MODE_ON
                } else {
                    CameraCharacteristics.CONTROL_VIDEO_STABILIZATION_MODE_OFF
                },
            )
        }
        builder.set(
            CaptureRequest.FLASH_MODE,
            if (torch) CameraCharacteristics.FLASH_MODE_TORCH
            else CameraCharacteristics.FLASH_MODE_OFF,
        )
        activeArray?.let { array ->
            val region = ProCameraRules.cropRegion(
                array.width(),
                array.height(),
                zoom,
                maximumZoom() ?: zoom,
            )
            builder.set(
                CaptureRequest.SCALER_CROP_REGION,
                Rect(region[0], region[1], region[2], region[3]),
            )
            focusPoint?.let { (x, y) ->
                val rect = ProCameraRules.meteringRect(x, y, array.width(), array.height())
                builder.set(
                    CaptureRequest.CONTROL_AF_REGIONS,
                    arrayOf(
                        MeteringRectangle(
                            rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1],
                            MeteringRectangle.METERING_WEIGHT_MAX,
                        ),
                    ),
                )
            }
            exposurePoint?.let { (x, y) ->
                val rect = ProCameraRules.meteringRect(x, y, array.width(), array.height())
                builder.set(
                    CaptureRequest.CONTROL_AE_REGIONS,
                    arrayOf(
                        MeteringRectangle(
                            rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1],
                            MeteringRectangle.METERING_WEIGHT_MAX,
                        ),
                    ),
                )
            }
        }
        // 调整曝光/对焦区域后触发一次对焦，连续对焦模式随后接管。
        if (focusPoint != null) {
            builder.set(
                CaptureRequest.CONTROL_AF_TRIGGER,
                CameraCharacteristics.CONTROL_AF_TRIGGER_START,
            )
        }
        return builder.build()
    }

    /** 预览视图 Surface 就绪；会话尚未创建时补建，录像中仅更新预览目标。 */
    fun attachPreview(texture: SurfaceTexture) {
        post {
            if (previewSurface != null) return@post
            previewTexture = texture
            previewSurface = Surface(texture)
            previewSize?.let { size ->
                texture.setDefaultBufferSize(size.width, size.height)
            }
            if (device == null) return@post
            val preview = previewSurface ?: return@post
            try {
                subscribeSession(preview, recordingTarget = recording)
            } catch (error: ProCameraFailure) {
                session?.close()
                session = null
            }
        }
    }

    /** 预览视图销毁；录像继续（仅移除预览目标），否则关闭会话并释放表面。 */
    fun detachPreview() {
        post {
            val texture = previewTexture
            val surface = previewSurface
            previewTexture = null
            previewSurface = null
            session?.apply {
                if (recording) {
                    try {
                        stopRepeating()
                    } catch (_: Exception) {
                        /* 会话可能已关闭。 */
                    }
                } else {
                    close()
                    session = null
                }
            }
            surface?.release()
            texture?.release()
            if (recording) {
                try {
                    applyRepeatingRequest()
                } catch (_: ProCameraFailure) {
                    /* 录像目标仍可用；预览请求失败由后续操作暴露。 */
                }
            }
        }
    }

    // ---------------------------------------------------------------- 参数控制

    private fun maximumZoom(): Double? =
        characteristics?.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)
            ?.toDouble()

    private fun minimumZoom(): Double = 1.0

    private fun setZoom(ratio: Double): Map<String, Any?> {
        val max = maximumZoom() ?: throw ProCameraFailure("unsupported", "当前镜头不支持变焦")
        zoom = ratio.coerceIn(minimumZoom(), max)
        if (session != null) applyRepeatingRequest()
        return mapOf("ratio" to zoom)
    }

    private fun setExposureOffset(ev: Double): Map<String, Any?> {
        val (range, step) = exposureCompensation() ?: throw ProCameraFailure(
            "unsupported",
            "当前镜头不支持曝光补偿",
        )
        val index = ProCameraRules.exposureIndex(ev, step)
            ?: throw ProCameraFailure("unsupported", "曝光补偿步长不可用")
        exposureIndex = index.coerceIn(range.lower, range.upper)
        if (session != null) applyRepeatingRequest()
        return mapOf("ev" to ProCameraRules.exposureEv(exposureIndex, step))
    }

    private fun setTorch(enabled: Boolean): Map<String, Any?> {
        val available = characteristics?.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        if (enabled && !available) throw ProCameraFailure("unsupported", "当前镜头没有可用补光灯")
        torch = enabled
        if (session != null) applyRepeatingRequest()
        return mapOf("enabled" to torch)
    }

    private fun setFocusPoint(point: Pair<Double, Double>?): Any? {
        if (point != null && (characteristics?.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF) ?: 0) <= 0) {
            throw ProCameraFailure("unsupported", "当前镜头不支持点按对焦")
        }
        focusPoint = point
        if (session != null) applyRepeatingRequest()
        return null
    }

    private fun setExposurePoint(point: Pair<Double, Double>?): Any? {
        if (point != null && (characteristics?.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE) ?: 0) <= 0) {
            throw ProCameraFailure("unsupported", "当前镜头不支持点按测光")
        }
        exposurePoint = point
        if (session != null) applyRepeatingRequest()
        return null
    }

    private fun stabilizationSupported(): Boolean =
        characteristics?.get(CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES)
            ?.contains(CameraCharacteristics.CONTROL_VIDEO_STABILIZATION_MODE_ON) == true

    private fun stabilizationModes(): List<String> = buildList {
        add("off")
        if (stabilizationSupported()) add("on")
    }

    private fun setStabilization(mode: String?): Map<String, Any?> {
        if (!stabilizationSupported()) throw ProCameraFailure("unsupported", "当前镜头不支持录像防抖")
        stabilizationOn = mode == "on"
        if (session != null) applyRepeatingRequest()
        return mapOf("mode" to if (stabilizationOn) "on" else "off")
    }

    private fun capabilities(): Map<String, Any?> {
        val info = characteristics ?: throw ProCameraFailure("session_closed", "相机会话尚未初始化")
        val compensation = exposureCompensation()
        val active = activeArray
        return mapOf(
            "zoomMin" to minimumZoom(),
            "zoomMax" to (maximumZoom() ?: 1.0),
            "exposureOffsetMin" to (compensation?.let {
                ProCameraRules.exposureEv(it.first.lower, it.second)
            } ?: 0.0),
            "exposureOffsetMax" to (compensation?.let {
                ProCameraRules.exposureEv(it.first.upper, it.second)
            } ?: 0.0),
            "exposureOffsetStep" to (compensation?.second ?: 0.0),
            "exposurePointSupported" to
                ((info.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE) ?: 0) > 0),
            "focusPointSupported" to
                ((info.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF) ?: 0) > 0),
            "torchSupported" to (info.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true),
            "activeWidth" to (active?.width() ?: 0),
            "activeHeight" to (active?.height() ?: 0),
        )
    }

    private fun exposureCompensation(): Pair<Range<Int>, Double>? {
        val info = characteristics ?: return null
        val range = info.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE) ?: return null
        val step = info.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
            ?.toDouble() ?: return null
        if (step <= 0) return null
        return range to step
    }

    // ---------------------------------------------------------------- 录制

    private fun start(): Map<String, Any?> {
        val camera = device ?: throw ProCameraFailure("session_closed", "相机会话已关闭")
        val target = videoTarget ?: throw ProCameraFailure("session_closed", "相机会话尚未初始化")
        if (recording) throw ProCameraFailure("already_recording", "正在录制中")
        val file = newOutputFile()
        val next = newRecorder()
        try {
            next.setVideoSource(MediaRecorder.VideoSource.SURFACE)
            if (audioEnabled) {
                next.setAudioSource(MediaRecorder.AudioSource.MIC)
            }
            next.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            next.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            if (audioEnabled) {
                next.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                next.setAudioEncodingBitRate(AUDIO_BITRATE_BPS)
                next.setAudioSamplingRate(AUDIO_SAMPLE_RATE_HZ)
            }
            next.setVideoSize(target.size.width, target.size.height)
            next.setVideoFrameRate(acceptedFps ?: DEFAULT_ENCODE_FPS)
            // 自动码率交由编码器默认值，避免用估算值冒充设备行为。
            acceptedBitrateBps?.let { bitrate -> next.setVideoEncodingBitRate(bitrate) }
            next.setOrientationHint(orientationHint())
            next.setOutputFile(file.absolutePath)
            next.prepare()
        } catch (error: Exception) {
            next.release()
            file.delete()
            throw ProCameraFailure("recording_start_failed", "无法启动录像，请检查存储空间", error)
        }
        recorder = next
        videoSurface = next.surface
        outputFile = file
        recording = true
        try {
            // 会话先就绪再启动录制器，避免编码器收到早到的帧。
            subscribeSession(videoSurface!!, recordingTarget = true, applyRequest = false)
            next.start()
            applyRepeatingRequest()
        } catch (error: Exception) {
            recording = false
            abortRecording()
            file.delete()
            outputFile = null
            throw if (error is ProCameraFailure) error else {
                ProCameraFailure("recording_start_failed", "无法启动录像", error)
            }
        }
        return mapOf(
            "path" to file.absolutePath,
            "width" to target.size.width,
            "height" to target.size.height,
        )
    }

    /** 停止录制：正常停止返回文件路径；停止失败保留文件并抛出，供上层重试或放弃。 */
    private fun stop(): Map<String, Any?> {
        val file = outputFile
        if (!recording || recorder == null) {
            throw ProCameraFailure("not_recording", "当前没有正在进行的录像")
        }
        var failure: Exception? = null
        try {
            recorder!!.stop()
        } catch (error: RuntimeException) {
            failure = error
        }
        recording = false
        recorder?.release()
        recorder = null
        videoSurface?.release()
        videoSurface = null
        // 恢复仅预览会话；没有预览时关闭会话等待视图再次就绪。
        if (previewSurface != null) {
            try {
                subscribeSession(previewSurface!!, recordingTarget = false)
            } catch (error: ProCameraFailure) {
                session?.close()
                session = null
                if (failure == null) throw error
            }
        } else {
            session?.close()
            session = null
        }
        if (failure != null) {
            throw ProCameraFailure(
                "recording_stop_failed",
                "停止录像失败，视频源已保留，可重试停止或放弃本次录像",
                failure,
            )
        }
        val path = file?.absolutePath ?: throw ProCameraFailure("recording_missing", "录像文件不可用")
        return mapOf("path" to path)
    }

    /** 关闭会话并释放录制资源；不影响已生成的输出文件。 */
    private fun abortRecording() {
        try {
            recorder?.reset()
        } catch (_: Exception) {
            /* 尽力清理。 */
        }
        recorder?.release()
        recorder = null
        videoSurface?.release()
        videoSurface = null
        if (previewSurface != null) {
            try {
                subscribeSession(previewSurface!!, recordingTarget = false)
            } catch (_: ProCameraFailure) {
                /* 后续重新初始化会恢复会话。 */
            }
        }
    }

    private fun newOutputFile(): File {
        val directory = File(context.cacheDir, RECORDINGS_DIRECTORY)
        directory.mkdirs()
        return File(directory, "rec_${System.currentTimeMillis()}.mp4")
    }

    /** 清理超过保留期的私有录像缓存，避免异常退出后文件无限累积。 */
    private fun cleanupStaleRecordings() {
        val directory = File(context.cacheDir, RECORDINGS_DIRECTORY)
        val cutoff = System.currentTimeMillis() - STALE_RECORDING_MS
        directory.listFiles()?.forEach { file ->
            if (file.isFile && file.lastModified() < cutoff) file.delete()
        }
    }

    private fun newRecorder(): MediaRecorder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

    private fun orientationHint(): Int {
        val sensorOrientation =
            characteristics?.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
        return ProCameraRules.orientationHint(deviceRotationDegrees(), sensorOrientation)
    }

    /** 读取文件视频元数据，用于停止后的成品核验；不可解析时返回空。 */
    private fun probeVideo(path: String): Map<String, Any?> {
        val file = File(path)
        if (!file.isFile || file.length() == 0L) {
            throw ProCameraFailure("recording_missing", "录像文件不存在")
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            mapOf(
                "durationMs" to retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull(),
                "width" to retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    ?.toIntOrNull(),
                "height" to retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    ?.toIntOrNull(),
                "rotation" to retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                    ?.toIntOrNull(),
                "size" to file.length(),
            )
        } catch (error: Exception) {
            throw ProCameraFailure("recording_invalid", "录像文件无法解析", error)
        } finally {
            retriever.release()
        }
    }

    /** 预览尺寸与方向快照；供 PlatformView 计算变换矩阵。 */
    fun previewSnapshot(): ProCameraPreviewView.Snapshot? {
        val size = previewSize ?: return null
        return ProCameraPreviewView.Snapshot(
            width = size.width,
            height = size.height,
            sensorOrientation = characteristics?.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0,
            deviceDegrees = deviceRotationDegrees(),
            frontFacing = frontFacing,
        )
    }

    /** 当前显示旋转角度（补偿方向）；用于预览变换与成品方向提示。 */
    @Suppress("DEPRECATION")
    fun deviceRotationDegrees(): Int {
        val windowManager =
            context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        return ProCameraRules.rotationDegrees(windowManager.defaultDisplay.rotation)
    }

    fun shutdown() {
        post { release() }
        executor.shutdown()
        callbackThread.quitSafely()
    }

    // ---------------------------------------------------------------- 工具

    private fun string(args: Map<*, *>, key: String): String =
        (args[key] as? String)?.takeIf { it.isNotBlank() }
            ?: throw ProCameraFailure("invalid_argument", "缺少参数 $key")

    private fun number(args: Map<*, *>, key: String): Double =
        (args[key] as? Number)?.toDouble()
            ?: throw ProCameraFailure("invalid_argument", "缺少参数 $key")

    private fun point(args: Map<*, *>): Pair<Double, Double>? {
        if (args["x"] == null || args["y"] == null) return null
        val x = (args["x"] as? Number)?.toDouble()
            ?: throw ProCameraFailure("invalid_argument", "坐标参数无效")
        val y = (args["y"] as? Number)?.toDouble()
            ?: throw ProCameraFailure("invalid_argument", "坐标参数无效")
        return x to y
    }

    private fun Size.toRuleSize() = ProCameraRules.Size(width, height)

    private fun ProCameraRules.Size.toAndroidSize() = Size(width, height)

    companion object {
        /** 相机回调等待上限：设备异常时不无限阻塞命令队列。 */
        const val CALLBACK_TIMEOUT_SECONDS = 5L

        /** 录音编码参数（AAC 128 kbps / 44.1 kHz）。 */
        const val AUDIO_BITRATE_BPS = 128_000
        const val AUDIO_SAMPLE_RATE_HZ = 44_100

        /** 未固定帧率时的编码器名义帧率。 */
        const val DEFAULT_ENCODE_FPS = 30

        /** 私有录像目录（位于应用缓存目录下）。 */
        const val RECORDINGS_DIRECTORY = "pro_camera"

        /** 未被上层登记的录像缓存保留期（24 小时）。 */
        const val STALE_RECORDING_MS = 24L * 60 * 60 * 1000
    }
}

/** 专业相机后端的结构化失败；code 稳定，message 面向用户。 */
class ProCameraFailure(
    val code: String,
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause) {
    companion object {
        fun failure(error: Exception): ProCameraFailure = when (error) {
            is ProCameraFailure -> error
            is CameraAccessException -> ProCameraFailure("camera_access", "无相机访问权限", error)
            is SecurityException -> ProCameraFailure("camera_access", "无相机访问权限", error)
            else -> ProCameraFailure("camera_error", "相机操作失败，请重试", error)
        }
    }
}
