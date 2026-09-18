package com.example.flutter_lens_vault

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import com.example.flutter_lens_vault.camera.ProCameraFailure
import com.example.flutter_lens_vault.camera.ProCameraManager
import com.example.flutter_lens_vault.camera.ProCameraPreviewView
import com.example.flutter_lens_vault.storage.SafStorage
import com.example.flutter_lens_vault.storage.archive.ArchiveManager
import com.example.flutter_lens_vault.storage.share.ShareManager
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * 管理目录选择器、相机权限与平台通道生命周期。
 *
 * - 文件访问、归档任务与专业相机各自使用串行队列，长任务不会阻塞录像保存。
 * - 进度经 EventChannel 上报，回调始终返回主线程。
 */
class MainActivity : FlutterFragmentActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val archiveExecutor = Executors.newSingleThreadExecutor()
    private val proExecutor = Executors.newSingleThreadExecutor()
    private var pickerResult: MethodChannel.Result? = null
    private var importResult: MethodChannel.Result? = null
    private var importTarget: Pair<String, String>? = null
    private var photoResult: MethodChannel.Result? = null
    private var photoTarget: Pair<String, String>? = null
    private var pendingPhotoFile: File? = null
    private var videoResult: MethodChannel.Result? = null
    private var videoTarget: Pair<String, String>? = null
    private var pendingVideoFile: File? = null
    private var channel: MethodChannel? = null
    private var archiveChannel: MethodChannel? = null
    private var proChannel: MethodChannel? = null
    private var proCamera: ProCameraManager? = null
    private var permissionResult: ((Boolean, Boolean) -> Unit)? = null
    private var events: EventChannel.EventSink? = null
    private var archive: ArchiveManager? = null
    private var storageHandler: SafStorage? = null
    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        val result = permissionResult
        permissionResult = null
        val camera = grants[Manifest.permission.CAMERA]
            ?: hasPermission(Manifest.permission.CAMERA)
        val audio = grants[Manifest.permission.RECORD_AUDIO]
            ?: hasPermission(Manifest.permission.RECORD_AUDIO)
        result?.invoke(camera, audio)
    }
    private val picker = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { response ->
        val result = pickerResult
        pickerResult = null
        val uri = response.data?.data
        if (response.resultCode != RESULT_OK || uri == null) {
            result?.success(null)
        } else if (result != null) {
            execute(result) {
                val flags = response.data!!.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                contentResolver.takePersistableUriPermission(uri, flags)
                SafStorage(applicationContext).root(uri)
            }
        }
    }
    private val importLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri -> finishImport(uri) }
    private val photoPickerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { response ->
        finishImport(if (response.resultCode == RESULT_OK) response.data?.data else null)
    }
    private val photoCaptureLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { response ->
        finishPhoto(response.resultCode == RESULT_OK)
    }
    private val videoCaptureLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { response ->
        finishVideo(response.resultCode == RESULT_OK)
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val storage = SafStorage(applicationContext)
        storageHandler = storage
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "lens_vault/saf_storage")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickRoot" -> {
                    if (pickerResult != null) {
                        result.error("busy", "目录选择器已打开", null)
                    } else {
                        pickerResult = result
                        try {
                            picker.launch(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION))
                        } catch (_: Exception) {
                            pickerResult = null
                            result.error("unavailable", "无法打开系统目录选择器", null)
                        }
                    }
                }
                "pickImport" -> startImport(call, result)
                "takePhoto" -> startPhotoCapture(call, result)
                "takeVideo" -> startVideoCapture(call, result)
                "openAppSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName")))
                    result.success(null)
                }
                else -> execute(result) { storage.handle(call.method, call.arguments) }
            }
        }

        val archiveManager = ArchiveManager(applicationContext) { event ->
            runOnUiThread { if (!isDestroyed) events?.success(event) }
        }
        archive = archiveManager
        val shareManager = ShareManager(applicationContext)
        EventChannel(engine.dartExecutor.binaryMessenger, "lens_vault/archive_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            })
        archiveChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "lens_vault/archive")
        archiveChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> {
                    val id = (call.arguments as? Map<*, *>)?.get("operationId") as? String
                    result.success(id != null && archiveManager.cancel(id))
                }
                // 分享需要主线程启动系统界面，不能放入 IO 队列。
                "share" -> {
                    try {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        result.success(shareManager.share(args))
                    } catch (error: Exception) {
                        val failure = SafStorage.failure(error)
                        result.error(failure.code, failure.message, failure.details)
                    }
                }
                "cleanupShareCache" -> archiveExecutor.execute {
                    val deleted = archiveManager.cleanupShareCache()
                    runOnUiThread { if (!isDestroyed) result.success(deleted) }
                }
                else -> archiveExecutor.execute {
                    try {
                        val value = archiveManager.handle(call.method, call.arguments)
                        runOnUiThread { if (!isDestroyed) result.success(value) }
                    } catch (error: Exception) {
                        val failure = SafStorage.failure(error)
                        runOnUiThread { if (!isDestroyed) result.error(failure.code, failure.message, failure.details) }
                    }
                }
            }
        }

        val proManager = ProCameraManager(applicationContext)
        proCamera = proManager
        engine.platformViewsController.registry.registerViewFactory(
            "lens_vault/pro_camera_preview",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context?, viewId: Int, args: Any?): PlatformView =
                    ProCameraPreviewView(context ?: this@MainActivity, proManager)
            },
        )
        proChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "lens_vault/pro_camera")
        proChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(true)
                "ensurePermissions" -> ensureProPermissions(call, result)
                // 预览视图生命周期来自主线程，其余命令统一进入相机串行队列。
                else -> proExecutor.execute {
                    try {
                        val value = proManager.handle(call.method, call.arguments)
                        runOnUiThread { if (!isDestroyed) result.success(value) }
                    } catch (error: Exception) {
                        val failure = ProCameraFailure.failure(error)
                        runOnUiThread {
                            if (!isDestroyed) result.error(failure.code, failure.message, null)
                        }
                    }
                }
            }
        }
    }

    /**
     * 从系统选择器导入内容到指定目录。
     *
     * - 图片/视频：Android 13+ 优先系统照片选择器（无需存储权限），否则 OpenDocument。
     * - PDF 等其他类型：固定 OpenDocument。
     * - 取消时返回 null；选中后立即复制到目标目录，临时读取授权随进程有效。
     */
    private fun startImport(call: MethodCall, result: MethodChannel.Result) {
        if (importResult != null) {
            result.error("busy", "选择器已打开", null)
            return
        }
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val rootUri = args["rootUri"] as? String
        val parentId = args["parentDocumentId"] as? String
        if (rootUri.isNullOrBlank() || parentId.isNullOrBlank()) {
            result.error("invalid_argument", "缺少目标目录", null)
            return
        }
        val mimeTypes = (args["mimeTypes"] as? List<*>)?.filterIsInstance<String>()?.toTypedArray()
            ?: arrayOf("*/*")
        val mediaOnly = mimeTypes.size == 2 && mimeTypes.contains("image/*") && mimeTypes.contains("video/*")
        importResult = result
        importTarget = rootUri to parentId
        try {
            if (mediaOnly && Build.VERSION.SDK_INT >= 33) {
                photoPickerLauncher.launch(
                    Intent(MediaStore.ACTION_PICK_IMAGES).apply { type = "*/*" },
                )
            } else {
                importLauncher.launch(mimeTypes)
            }
        } catch (_: Exception) {
            importResult = null
            importTarget = null
            result.error("unavailable", "无法打开系统选择器", null)
        }
    }

    private fun finishImport(uri: Uri?) {
        val result = importResult
        importResult = null
        val target = importTarget
        importTarget = null
        if (result == null || target == null) return
        if (uri == null) {
            result.success(null)
            return
        }
        execute(result) {
            storageHandler?.handle(
                "importDocument",
                mapOf(
                    "sourceUri" to uri.toString(),
                    "rootUri" to target.first,
                    "parentDocumentId" to target.second,
                ),
            )
        }
    }

    /**
     * 拍摄照片：系统相机写入应用私有临时文件，导入成功后删除临时文件。
     *
     * 应用声明了 CAMERA 权限，因此调用系统相机前必须先取得该权限；
     * 无可用相机应用时返回错误且不产生残留文件。
     */
    private fun startPhotoCapture(call: MethodCall, result: MethodChannel.Result) {
        val target = pendingTarget(call, result) ?: return
        if (photoResult != null) {
            result.error("busy", "相机任务进行中", null)
            return
        }
        photoTarget = target
        ensureCameraPermission(result) {
            launchCamera(result)
        }
    }

    private fun launchCamera(result: MethodChannel.Result) {
        // 临时照片仅服务于单次拍摄；启动前清理上次流程可能遗留的文件。
        val photos = File(cacheDir, "photos")
        photos.deleteRecursively()
        photos.mkdirs()
        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val file = File(photos, "IMG_$stamp.jpg")
        pendingPhotoFile = file
        photoResult = result
        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            photoCaptureLauncher.launch(
                Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                    .putExtra(MediaStore.EXTRA_OUTPUT, uri)
                    .addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    ),
            )
        } catch (_: Exception) {
            file.delete()
            pendingPhotoFile = null
            photoResult = null
            result.error("no_camera_app", "没有可用的相机应用", null)
        }
    }

    private fun finishPhoto(ok: Boolean) {
        val result = photoResult
        photoResult = null
        val target = photoTarget
        photoTarget = null
        val file = pendingPhotoFile
        if (result == null) return
        if (!ok || file == null || target == null) {
            file?.delete()
            pendingPhotoFile = null
            result.success(null)
            return
        }
        execute(result) {
            try {
                storageHandler?.handle(
                    "importDocument",
                    mapOf(
                        "sourceUri" to Uri.fromFile(file).toString(),
                        "rootUri" to target.first,
                        "parentDocumentId" to target.second,
                    ),
                )
            } finally {
                file.delete()
                pendingPhotoFile = null
            }
        }
    }

    /**
     * 系统相机录制视频：与拍照共用同一导入链路与临时文件治理。
     *
     * 录制画质交给系统相机决定；取消或失败返回 null，不产生残留文件。
     */
    private fun startVideoCapture(call: MethodCall, result: MethodChannel.Result) {
        val target = pendingTarget(call, result) ?: return
        if (videoResult != null) {
            result.error("busy", "相机任务进行中", null)
            return
        }
        videoTarget = target
        ensureCameraPermission(result) {
            launchVideoCamera(result)
        }
    }

    private fun launchVideoCamera(result: MethodChannel.Result) {
        val videos = File(cacheDir, "videos")
        videos.deleteRecursively()
        videos.mkdirs()
        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val file = File(videos, "VID_$stamp.mp4")
        pendingVideoFile = file
        videoResult = result
        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            videoCaptureLauncher.launch(
                Intent(MediaStore.ACTION_VIDEO_CAPTURE)
                    .putExtra(MediaStore.EXTRA_OUTPUT, uri)
                    .putExtra(MediaStore.EXTRA_VIDEO_QUALITY, 1)
                    .addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    ),
            )
        } catch (_: Exception) {
            file.delete()
            pendingVideoFile = null
            videoResult = null
            result.error("no_camera_app", "没有可用的相机应用", null)
        }
    }

    private fun finishVideo(ok: Boolean) {
        val result = videoResult
        videoResult = null
        val target = videoTarget
        videoTarget = null
        val file = pendingVideoFile
        if (result == null) return
        if (!ok || file == null || target == null) {
            file?.delete()
            pendingVideoFile = null
            result.success(null)
            return
        }
        execute(result) {
            try {
                storageHandler?.handle(
                    "importDocument",
                    mapOf(
                        "sourceUri" to Uri.fromFile(file).toString(),
                        "rootUri" to target.first,
                        "parentDocumentId" to target.second,
                    ),
                )
            } finally {
                file.delete()
                pendingVideoFile = null
            }
        }
    }

    /** 校验并缓存调用参数中的目标目录；无效时立即返回错误，null 表示已拒绝。 */
    private fun pendingTarget(call: MethodCall, result: MethodChannel.Result): Pair<String, String>? {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val rootUri = args["rootUri"] as? String
        val parentId = args["parentDocumentId"] as? String
        if (rootUri.isNullOrBlank() || parentId.isNullOrBlank()) {
            result.error("invalid_argument", "缺少目标目录", null)
            return null
        }
        return rootUri to parentId
    }

    /**
     * 确保相机权限后执行拍摄动作。
     *
     * 应用声明了 CAMERA 权限，调用 ACTION_IMAGE_CAPTURE / ACTION_VIDEO_CAPTURE
     * 前必须已授权，否则系统直接抛出 SecurityException。
     */
    private fun ensureCameraPermission(result: MethodChannel.Result, onGranted: () -> Unit) {
        if (hasPermission(Manifest.permission.CAMERA)) {
            onGranted()
            return
        }
        if (permissionResult != null) {
            result.error("busy", "权限请求已在进行", null)
            return
        }
        permissionResult = { camera, _ ->
            if (camera) {
                onGranted()
            } else {
                result.error("camera_denied", "相机权限未授权，无法拍摄", null)
            }
        }
        permissionLauncher.launch(arrayOf(Manifest.permission.CAMERA))
    }

    /** 相机与麦克风权限：静音模式不申请麦克风；结果按真实授权状态返回。 */
    private fun ensureProPermissions(call: MethodCall, result: MethodChannel.Result) {
        val audio = (call.arguments as? Map<*, *>)?.get("audio") == true
        val missing = buildList {
            if (!hasPermission(Manifest.permission.CAMERA)) add(Manifest.permission.CAMERA)
            if (audio && !hasPermission(Manifest.permission.RECORD_AUDIO)) {
                add(Manifest.permission.RECORD_AUDIO)
            }
        }
        if (missing.isEmpty()) {
            result.success(
                mapOf(
                    "camera" to true,
                    "audio" to hasPermission(Manifest.permission.RECORD_AUDIO),
                ),
            )
            return
        }
        if (permissionResult != null) {
            result.error("busy", "权限请求已在进行", null)
            return
        }
        permissionResult = { camera, audioGranted ->
            result.success(mapOf("camera" to camera, "audio" to audioGranted))
        }
        permissionLauncher.launch(missing.toTypedArray())
    }

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun execute(result: MethodChannel.Result, action: () -> Any?) {
        executor.execute {
            try {
                val value = action()
                runOnUiThread { if (!isDestroyed) result.success(value) }
            } catch (error: Exception) {
                val failure = SafStorage.failure(error)
                runOnUiThread { if (!isDestroyed) result.error(failure.code, failure.message, failure.details) }
            }
        }
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        archiveChannel?.setMethodCallHandler(null)
        proChannel?.setMethodCallHandler(null)
        proCamera?.shutdown()
        proCamera = null
        events = null
        pickerResult = null
        importResult = null
        photoResult = null
        videoResult = null
        permissionResult = null
        executor.shutdown()
        archiveExecutor.shutdown()
        proExecutor.shutdown()
        super.onDestroy()
    }
}
