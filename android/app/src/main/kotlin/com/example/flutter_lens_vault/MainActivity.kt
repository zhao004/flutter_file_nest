package com.example.flutter_lens_vault

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.flutter_lens_vault.storage.SafStorage
import java.util.concurrent.Executors

/** 管理目录选择器生命周期；文件访问在串行 IO 队列执行，回调始终返回主线程。 */
class MainActivity : FlutterFragmentActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private var pickerResult: MethodChannel.Result? = null
    private var channel: MethodChannel? = null
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

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val storage = SafStorage(applicationContext)
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
                "openAppSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName")))
                    result.success(null)
                }
                else -> execute(result) { storage.handle(call.method, call.arguments) }
            }
        }
    }

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
        pickerResult = null
        executor.shutdown()
        super.onDestroy()
    }
}
