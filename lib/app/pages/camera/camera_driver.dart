import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

abstract interface class CameraDriver {
  Future<List<CameraDescription>> cameras();
  Future<void> initialize(CameraDescription camera, bool audio);
  Future<void> dispose();
  Future<double> minZoom();
  Future<double> maxZoom();
  Future<void> zoom(double value);
  Future<void> start();
  Future<XFile> stop();
  Widget preview();
  String get targetLabel;
}

/// 单一相机会话适配器；仅在设备拒绝配置时尝试较低的目标规格。
class PluginCameraDriver implements CameraDriver {
  CameraController? _controller;
  @override
  String targetLabel = '1080p / 30 FPS（目标）';

  @override
  Future<List<CameraDescription>> cameras() => availableCameras();

  @override
  Future<void> initialize(CameraDescription camera, bool audio) async {
    await dispose();
    final configurations = [
      (ResolutionPreset.veryHigh, 30, '1080p / 30 FPS（目标）'),
      (ResolutionPreset.veryHigh, null, '1080p / 自动帧率（目标）'),
      (ResolutionPreset.high, null, '720p / 自动帧率（目标）'),
      (ResolutionPreset.medium, null, '480p / 自动帧率（目标）'),
      (ResolutionPreset.low, null, '低分辨率 / 自动帧率（目标）'),
    ];
    for (final config in configurations) {
      final controller = CameraController(
        camera,
        config.$1,
        enableAudio: audio,
        fps: config.$2,
      );
      try {
        await controller.initialize();
        _controller = controller;
        targetLabel = config.$3;
        return;
      } on CameraException catch (error) {
        await controller.dispose();
        if (error.code.contains('Access') || config == configurations.last) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  Future<double> minZoom() => _controller!.getMinZoomLevel();
  @override
  Future<double> maxZoom() => _controller!.getMaxZoomLevel();
  @override
  Future<void> zoom(double value) => _controller!.setZoomLevel(value);
  @override
  Future<void> start() async {
    await _controller!.lockCaptureOrientation();
    await _controller!.startVideoRecording();
  }

  @override
  Future<XFile> stop() async {
    final result = await _controller!.stopVideoRecording();
    try {
      await _controller!.unlockCaptureOrientation();
    } catch (_) {
      /* 清理失败不能丢弃已结束的录像。 */
    }
    return result;
  }

  @override
  Widget preview() => _controller == null
      ? const SizedBox.shrink()
      : Center(child: CameraPreview(_controller!));
}
