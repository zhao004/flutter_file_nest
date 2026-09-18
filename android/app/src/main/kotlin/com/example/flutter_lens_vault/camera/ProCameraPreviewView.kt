package com.example.flutter_lens_vault.camera

import android.content.Context
import android.graphics.Matrix
import android.graphics.RectF
import android.graphics.SurfaceTexture
import android.view.TextureView
import android.view.View
import io.flutter.plugin.platform.PlatformView

/**
 * 专业相机预览的平台视图：持有 TextureView，Surface 就绪时交给后端，
 * 并按预览尺寸、传感器方向与设备旋转计算 center-crop 变换，避免画面拉伸。
 *
 * 视图销毁时先通知后端停止使用该表面，再由后端在会话停止后释放，
 * 防止相机继续向已释放的 SurfaceTexture 写入帧。
 */
class ProCameraPreviewView(
    context: Context,
    private val manager: ProCameraManager,
) : PlatformView, TextureView.SurfaceTextureListener {
    private val textureView = TextureView(context)

    init {
        textureView.surfaceTextureListener = this
    }

    override fun getView(): View = textureView

    override fun dispose() {
        textureView.surfaceTextureListener = null
        manager.detachPreview()
    }

    override fun onSurfaceTextureAvailable(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        manager.attachPreview(surface)
        applyTransform(width, height)
    }

    override fun onSurfaceTextureSizeChanged(
        surface: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        applyTransform(width, height)
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        textureView.surfaceTextureListener = null
        manager.detachPreview()
        // 返回 false：由后端在停止会话后释放表面，避免释放时仍有帧写入。
        return false
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit

    /** 计算显示变换：先按比例居中，再按旋转角与镜像要求缩放铺满视图。 */
    private fun applyTransform(viewWidth: Int, viewHeight: Int) {
        if (viewWidth <= 0 || viewHeight <= 0) return
        val snapshot = manager.previewSnapshot() ?: return
        if (snapshot.width <= 0 || snapshot.height <= 0) return
        val rotation = ProCameraRules.previewRotationDegrees(
            snapshot.deviceDegrees,
            snapshot.sensorOrientation,
        )
        val bufferAspect = snapshot.width.toDouble() / snapshot.height
        var fitWidth = viewWidth.toDouble()
        var fitHeight = fitWidth / bufferAspect
        if (fitHeight > viewHeight) {
            fitHeight = viewHeight.toDouble()
            fitWidth = fitHeight * bufferAspect
        }
        val rotated = rotation % 180 != 0
        val cover = if (rotated) {
            maxOf(viewWidth / fitHeight, viewHeight / fitWidth)
        } else {
            maxOf(viewWidth / fitWidth, viewHeight / fitHeight)
        }
        val centerX = viewWidth / 2f
        val centerY = viewHeight / 2f
        val matrix = Matrix()
        matrix.setRectToRect(
            RectF(0f, 0f, snapshot.width.toFloat(), snapshot.height.toFloat()),
            RectF(0f, 0f, viewWidth.toFloat(), viewHeight.toFloat()),
            Matrix.ScaleToFit.CENTER,
        )
        matrix.postScale(cover.toFloat(), cover.toFloat(), centerX, centerY)
        matrix.postRotate(rotation.toFloat(), centerX, centerY)
        if (snapshot.frontFacing) {
            matrix.postScale(-1f, 1f, centerX, centerY)
        }
        textureView.setTransform(matrix)
    }

    /** 预览尺寸与方向快照；由后端在命令队列写入，视图在主线程读取。 */
    data class Snapshot(
        val width: Int,
        val height: Int,
        val sensorOrientation: Int,
        val deviceDegrees: Int,
        val frontFacing: Boolean,
    )
}
