import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../models/camera_capture_settings.dart';
import '../../models/camera_parameter_models.dart';

abstract interface class CameraDriver {
  Future<List<CameraDescription>> cameras();

  /// 按请求规格初始化会话；设备拒绝时沿后备阶梯降级，初始化成功的配置即"已接受值"。
  Future<void> initialize(
    CameraDescription camera,
    bool audio,
    RecordingSettings settings,
  );
  Future<void> dispose();
  Future<double> minZoom();
  Future<double> maxZoom();
  Future<void> zoom(double value);

  /// 探测当前会话镜头的参数能力；探测失败返回 null，由上层按未支持处理。
  Future<LensCapabilities?> capabilities();

  /// 设置曝光补偿（EV 单位），返回后端实际接受的值。
  Future<ParameterApplyResult> setExposureOffset(double value);

  /// 将曝光补偿恢复为 0 EV。
  Future<ParameterApplyResult> resetExposureOffset();

  /// 开启或关闭持续补光；请求失败返回结构化原因。
  Future<ParameterApplyResult> setTorch(bool enabled);

  /// 在预览归一化坐标（0..1）处设置对焦与测光区域，null 表示恢复默认。
  Future<void> setFocusPoint(Offset? point);
  Future<void> setExposurePoint(Offset? point);

  /// 当前镜头支持的防抖模式；后端未实现时返回仅含 off 或空列表。
  Future<List<VideoStabilizationMode>> supportedStabilizationModes();

  /// 应用防抖模式；返回实际生效模式，设备不支持时返回 null。
  Future<VideoStabilizationMode?> setStabilizationMode(
    VideoStabilizationMode mode,
  );

  /// 用户请求的规格文案。
  String get requestedLabel;

  /// 本次会话初始化成功的规格文案（后备降级后可能与请求不同）。
  String get acceptedLabel;

  Future<void> start();
  Future<XFile> stop();
  Widget preview();
}

/// 单一相机会话适配器；仅在设备拒绝配置时沿后备阶梯降级。
class PluginCameraDriver implements CameraDriver {
  RecordingSettings _requested = const RecordingSettings();
  String _accepted = '已接受 1080p / 30 FPS';
  @override
  String get requestedLabel => '请求 ${_requested.label}';
  @override
  String get acceptedLabel => _accepted;

  static const _presetLabels = {
    ResolutionPreset.low: '240p',
    ResolutionPreset.medium: '480p',
    ResolutionPreset.high: '720p',
    ResolutionPreset.veryHigh: '1080p',
    ResolutionPreset.ultraHigh: '1440p',
    ResolutionPreset.max: '设备最高',
  };

  @override
  Future<List<CameraDescription>> cameras() => availableCameras();

  @override
  Future<void> initialize(
    CameraDescription camera,
    bool audio,
    RecordingSettings settings,
  ) async {
    await dispose();
    _requested = settings;
    final fps = switch (settings.fps) {
      CaptureFps.auto => null,
      CaptureFps.fps30 => 30,
      CaptureFps.fps60 => 60,
    };
    final chain = switch (settings.quality) {
      CaptureQuality.p480 => [ResolutionPreset.medium, ResolutionPreset.low],
      CaptureQuality.p720 => [
        ResolutionPreset.high,
        ResolutionPreset.medium,
        ResolutionPreset.low,
      ],
      CaptureQuality.p1080 => [
        ResolutionPreset.veryHigh,
        ResolutionPreset.high,
        ResolutionPreset.medium,
        ResolutionPreset.low,
      ],
      CaptureQuality.max => [
        ResolutionPreset.max,
        ResolutionPreset.ultraHigh,
        ResolutionPreset.veryHigh,
        ResolutionPreset.high,
        ResolutionPreset.medium,
        ResolutionPreset.low,
      ],
    };
    // 帧率降级只发生在首个预设上；更低分辨率不再重复尝试固定帧率。
    final configurations = [
      for (final (index, preset) in chain.indexed) ...[
        if (fps != null && index == 0) (preset, fps),
        (preset, null),
      ],
    ];
    for (final config in configurations) {
      final controller = CameraController(
        camera,
        config.$1,
        enableAudio: audio,
        fps: config.$2,
        videoBitrate: settings.videoBitrateBps,
      );
      try {
        await controller.initialize();
        _controller = controller;
        _accepted =
            '已接受 ${_presetLabels[config.$1]} / '
            '${config.$2 == null ? '自动帧率' : '${config.$2} FPS'}';
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
  Future<LensCapabilities?> capabilities() async {
    final controller = _controller;
    if (controller == null) return null;
    double zoomMin = 1;
    double zoomMax = 1;
    try {
      zoomMin = await controller.getMinZoomLevel();
      zoomMax = await controller.getMaxZoomLevel();
    } on CameraException {
      return null;
    }
    double exposureMin = 0;
    double exposureMax = 0;
    double exposureStep = 0;
    try {
      exposureMin = await controller.getMinExposureOffset();
      exposureMax = await controller.getMaxExposureOffset();
      exposureStep = await controller.getExposureOffsetStepSize();
    } on CameraException {
      exposureMin = 0;
      exposureMax = 0;
      exposureStep = 0;
    }
    var torch = false;
    try {
      await controller.setFlashMode(FlashMode.torch);
      torch = true;
    } on CameraException {
      torch = false;
    } finally {
      if (torch) {
        try {
          await controller.setFlashMode(FlashMode.off);
        } on CameraException {
          /* 恢复失败时保持探测到的能力，由用户操作再次修正。 */
        }
      }
    }
    return LensCapabilities(
      zoomMin: zoomMin,
      zoomMax: zoomMax,
      exposureOffsetMin: exposureMin,
      exposureOffsetMax: exposureMax,
      exposureOffsetStep: exposureStep,
      exposurePointSupported: controller.value.exposurePointSupported,
      focusPointSupported: controller.value.focusPointSupported,
      torchSupported: torch,
    );
  }

  @override
  Future<ParameterApplyResult> setExposureOffset(double value) async {
    final controller = _controller;
    if (controller == null) {
      return const ParameterApplyResult.failed(
        ParameterApplyFailure.sessionClosed,
      );
    }
    try {
      final applied = await controller.setExposureOffset(value);
      return ParameterApplyResult.accepted(applied);
    } on CameraException catch (error) {
      return ParameterApplyResult.failed(
        error.code == 'exposureOffsetOutOfBounds'
            ? ParameterApplyFailure.outOfRange
            : ParameterApplyFailure.deviceRejected,
      );
    }
  }

  @override
  Future<ParameterApplyResult> resetExposureOffset() => setExposureOffset(0);

  @override
  Future<ParameterApplyResult> setTorch(bool enabled) async {
    final controller = _controller;
    if (controller == null) {
      return const ParameterApplyResult.failed(
        ParameterApplyFailure.sessionClosed,
      );
    }
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      return ParameterApplyResult.accepted(enabled ? 1 : 0);
    } on CameraException {
      return ParameterApplyResult.failed(ParameterApplyFailure.deviceRejected);
    }
  }

  @override
  Future<void> setFocusPoint(Offset? point) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setFocusPoint(point);
  }

  @override
  Future<void> setExposurePoint(Offset? point) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setExposurePoint(point);
  }

  @override
  Future<List<VideoStabilizationMode>> supportedStabilizationModes() async {
    final controller = _controller;
    if (controller == null) return const [];
    try {
      return List.of(await controller.getSupportedVideoStabilizationModes());
    } on CameraException {
      return const [];
    }
  }

  @override
  Future<VideoStabilizationMode?> setStabilizationMode(
    VideoStabilizationMode mode,
  ) async {
    final controller = _controller;
    if (controller == null) return null;
    try {
      await controller.setVideoStabilizationMode(mode, allowFallback: false);
      return controller.value.videoStabilizationMode;
    } catch (_) {
      return null;
    }
  }

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

  CameraController? _controller;
}
