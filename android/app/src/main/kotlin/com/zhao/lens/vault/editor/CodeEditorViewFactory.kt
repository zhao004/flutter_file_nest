package com.zhao.lens.vault.editor

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 代码编辑器的平台视图工厂；在 MainActivity 中注册为 `lens_vault/code_editor`。
 */
class CodeEditorViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        CodeEditorPlatformView(
            context,
            viewId,
            args as? Map<*, *>,
            messenger,
        )
}
