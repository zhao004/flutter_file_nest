package com.zhao.lens.vault

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.core.content.IntentCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.zhao.lens.vault.storage.SafStorage
import com.zhao.lens.vault.storage.StorageFailure
import com.zhao.lens.vault.storage.archive.ArchiveManager
import com.zhao.lens.vault.storage.share.ShareManager
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * 管理目录选择器与平台通道生命周期。
 *
 * - 文件访问与归档任务各自使用串行队列，长任务不会阻塞其他操作。
 * - 拍照与录像交由系统相机应用完成，本应用只负责把结果导入目标目录。
 * - 进度经 EventChannel 上报，回调始终返回主线程。
 */
class MainActivity : FlutterFragmentActivity() {
    // 写操作串行以保证顺序；只读元数据与缩略图使用各自线程池，
    // 缩略图加载不会阻塞目录列表，目录切换因此保持即时响应。
    private val executor = Executors.newSingleThreadExecutor()
    private val readExecutor = Executors.newFixedThreadPool(4)
    private val thumbnailExecutor = Executors.newFixedThreadPool(2)
    private val archiveExecutor = Executors.newSingleThreadExecutor()
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
    private var events: EventChannel.EventSink? = null
    // 来自其他应用（微信/QQ 等）的待保存文件；Flutter 未监听时先缓冲。
    private var incomingSink: EventChannel.EventSink? = null
    private var pendingShares: List<Map<String, Any?>>? = null
    private var archive: ArchiveManager? = null
    private var storageHandler: SafStorage? = null
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
        ActivityResultContracts.OpenMultipleDocuments(),
    ) { uris -> finishImport(uris) }
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
                "importDocuments" -> startImportDocuments(call, result)
                "takePhoto" -> startPhotoCapture(call, result)
                "takeVideo" -> startVideoCapture(call, result)
                "openAppSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName")))
                    result.success(null)
                }
                // 缩略图单独并发；只读元数据并发；写操作串行。
                else -> {
                    val action = { storage.handle(call.method, call.arguments) }
                    when {
                        call.method in THUMBNAIL_METHODS ->
                            submit(thumbnailExecutor, result, action)
                        call.method in READ_ONLY_METHODS -> submit(readExecutor, result, action)
                        else -> submit(executor, result, action)
                    }
                }
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
        EventChannel(engine.dartExecutor.binaryMessenger, "lens_vault/incoming")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    incomingSink = sink
                    pendingShares?.let { shares ->
                        pendingShares = null
                        sink.success(shares)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    incomingSink = null
                }
            })
        // 冷启动时可能已带着分享 Intent，先解析并按需缓冲。
        dispatchIncomingShares(intent)

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
    }

    /**
     * 从系统选择器导入内容到指定目录。
     *
     * - 使用系统文档选择器（OpenMultipleDocuments），支持一次选择多个任意类型文件。
     * - 取消时返回空列表；选中后逐个复制到目标目录，临时读取授权随进程有效。
     * - 单个文件失败不阻塞其余文件，最后按失败数量上报。
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
        importResult = result
        importTarget = rootUri to parentId
        try {
            importLauncher.launch(mimeTypes)
        } catch (_: Exception) {
            importResult = null
            importTarget = null
            result.error("unavailable", "无法打开系统选择器", null)
        }
    }

    private fun finishImport(uris: List<Uri>) {
        val result = importResult
        importResult = null
        val target = importTarget
        importTarget = null
        if (result == null || target == null) return
        if (uris.isEmpty()) {
            result.success(emptyList<Any>())
            return
        }
        execute(result) { importSources(uris.map { it.toString() }, target) }
    }

    /**
     * 按来源 URI 批量导入到指定目录；供外部分享保存流程调用。
     * 只接受 content:// 与 file:// 来源，避免任意输入。
     */
    private fun startImportDocuments(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val rootUri = args["rootUri"] as? String
        val parentId = args["parentDocumentId"] as? String
        if (rootUri.isNullOrBlank() || parentId.isNullOrBlank()) {
            result.error("invalid_argument", "缺少目标目录", null)
            return
        }
        val sources = (args["sources"] as? List<*>)
            ?.filterIsInstance<String>()
            ?.filter { it.startsWith("content://") || it.startsWith("file://") }
            .orEmpty()
        if (sources.isEmpty()) {
            result.success(emptyList<Any>())
            return
        }
        execute(result) { importSources(sources, rootUri to parentId) }
    }

    /** 逐个导入来源到目标目录；单个失败不阻塞其余，最后按失败数量上报。 */
    private fun importSources(
        sources: List<String>,
        target: Pair<String, String>,
    ): List<Map<String, Any?>> {
        val entries = mutableListOf<Map<String, Any?>>()
        var failed = 0
        for (source in sources) {
            try {
                val entry = storageHandler?.handle(
                    "importDocument",
                    mapOf(
                        "sourceUri" to source,
                        "rootUri" to target.first,
                        "parentDocumentId" to target.second,
                    ),
                ) as? Map<String, Any?>
                if (entry != null) entries.add(entry) else failed++
            } catch (_: Exception) {
                // 单个文件失败不阻塞其余导入，最后统一上报失败数量。
                failed++
            }
        }
        if (failed > 0) {
            throw StorageFailure("import_partial", "已导入 ${entries.size} 个文件，$failed 个失败")
        }
        return entries
    }

    /**
     * 拍摄照片：系统相机写入应用私有临时文件，导入成功后删除临时文件。
     *
     * 相机权限由系统相机应用自行处理；无可用相机应用时返回错误且不产生残留文件。
     */
    private fun startPhotoCapture(call: MethodCall, result: MethodChannel.Result) {
        val target = pendingTarget(call, result) ?: return
        if (photoResult != null) {
            result.error("busy", "相机任务进行中", null)
            return
        }
        photoTarget = target
        launchCamera(result)
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
        launchVideoCamera(result)
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

    /** 串行队列入口（写操作与导入、临时文件流程）。 */
    private fun execute(result: MethodChannel.Result, action: () -> Any?) =
        submit(executor, result, action)

    /** 在指定队列执行存储调用，并把结果/错误切回主线程。 */
    private fun submit(
        pool: Executor,
        result: MethodChannel.Result,
        action: () -> Any?,
    ) {
        pool.execute {
            try {
                val value = action()
                runOnUiThread { if (!isDestroyed) result.success(value) }
            } catch (error: Exception) {
                val failure = SafStorage.failure(error)
                runOnUiThread { if (!isDestroyed) result.error(failure.code, failure.message, failure.details) }
            }
        }
    }

    /** 应用已在前台时收到新的打开/分享请求。 */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchIncomingShares(intent)
    }

    /**
     * 解析并下发外部文件；Flutter 尚未监听时先缓冲。
     *
     * 只提取 URI，不在主线程访问外部提供方（如微信 FileProvider 的
     * ContentResolver.query 可能阻塞启动，导致白屏/ANR）；名称与大小在
     * 保存阶段于后台线程解析。任何解析异常都不得影响 Flutter 启动。
     */
    private fun dispatchIncomingShares(intent: Intent?) {
        val shares = try {
            extractIncomingShares(intent)
        } catch (_: Exception) {
            null
        } ?: return
        val sink = incomingSink
        if (sink != null) sink.success(shares) else pendingShares = shares
    }

    /** 从 VIEW / SEND / SEND_MULTIPLE 中提取可读文件；无有效来源返回 null。 */
    private fun extractIncomingShares(intent: Intent?): List<Map<String, Any?>>? {
        if (intent == null) return null
        val uris = when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND -> listOfNotNull(
                IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java),
            )
            Intent.ACTION_SEND_MULTIPLE -> IntentCompat.getParcelableArrayListExtra(
                intent,
                Intent.EXTRA_STREAM,
                Uri::class.java,
            ).orEmpty()
            else -> return null
        }
        val readable = uris.filter { it.scheme == "content" || it.scheme == "file" }
        if (readable.isEmpty()) return null
        return readable.map { mapOf("uri" to it.toString()) }
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        archiveChannel?.setMethodCallHandler(null)
        events = null
        incomingSink = null
        pendingShares = null
        pickerResult = null
        importResult = null
        photoResult = null
        videoResult = null
        executor.shutdown()
        readExecutor.shutdown()
        thumbnailExecutor.shutdown()
        archiveExecutor.shutdown()
        super.onDestroy()
    }

    private companion object {
        /** 缩略图加载：独立并发队列，避免占用目录列表线程。 */
        val THUMBNAIL_METHODS = setOf("loadThumbnail")

        /** 不修改存储状态的元数据方法；可安全并发执行。 */
        val READ_ONLY_METHODS = setOf(
            "validateRoot",
            "listChildren",
            "getDeletionImpact",
            "videoMetadata",
            "readDocument",
            "pdfInfo",
            "pdfPageBytes",
        )
    }
}
