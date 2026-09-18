package com.zhao.lens.vault.editor

import android.content.Context
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.github.rosemoe.sora.event.ContentChangeEvent
import io.github.rosemoe.sora.widget.CodeEditor
import io.github.rosemoe.sora.widget.schemes.SchemeDarcula
import io.github.rosemoe.sora.widget.schemes.SchemeGitHub

/**
 * 基于 sora-editor 的代码编辑器平台视图。
 *
 * 每个实例对应一个 Flutter 平台视图，并创建独立的 MethodChannel
 * （`lens_vault/code_editor/<viewId>`）用于文本读写、可编辑性、主题与撤销重做。
 * 内容变化通过 `onChanged` 事件回推，供 Dart 侧维护“未保存”状态。
 */
class CodeEditorPlatformView(
    context: Context,
    viewId: Int,
    creationParams: Map<*, *>?,
    messenger: BinaryMessenger,
) : PlatformView {
    private val editor = CodeEditor(context)
    private val channel = MethodChannel(messenger, "$CHANNEL_PREFIX$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())

    // 程序化 setText（初始化/还原）期间抑制变化事件，避免被当作“未保存修改”。
    private var suppressChange = false

    init {
        editor.typefaceText = Typeface.MONOSPACE
        editor.isEditable = creationParams?.get("editable") as? Boolean ?: true
        applyDark(creationParams?.get("dark") as? Boolean ?: false)
        editor.subscribeEvent(ContentChangeEvent::class.java) { _, _ ->
            if (suppressChange) return@subscribeEvent
            mainHandler.post { channel.invokeMethod("onChanged", null) }
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setText" -> {
                    suppressChange = true
                    editor.setText(call.arguments as? String ?: "")
                    suppressChange = false
                    result.success(null)
                }
                "getText" -> result.success(editor.text.toString())
                "setEditable" -> {
                    editor.isEditable = call.arguments as? Boolean ?: true
                    result.success(null)
                }
                "setDark" -> {
                    applyDark(call.arguments as? Boolean ?: false)
                    result.success(null)
                }
                "undo" -> {
                    editor.undo()
                    result.success(null)
                }
                "redo" -> {
                    editor.redo()
                    result.success(null)
                }
                "canUndo" -> result.success(editor.canUndo())
                "canRedo" -> result.success(editor.canRedo())
                else -> result.notImplemented()
            }
        }
        mainHandler.post { channel.invokeMethod("onReady", null) }
    }

    /** 切换亮/暗配色；sora 内置方案颜色固定，与 Flutter 主题亮度对齐即可。 */
    private fun applyDark(dark: Boolean) {
        editor.colorScheme = if (dark) SchemeDarcula() else SchemeGitHub()
    }

    override fun getView(): View = editor

    override fun dispose() {
        channel.setMethodCallHandler(null)
        editor.release()
    }

    companion object {
        const val CHANNEL_PREFIX = "lens_vault/code_editor/"
    }
}
