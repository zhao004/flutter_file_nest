import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../models/camera_capture_settings.dart';
import '../../models/camera_parameter_models.dart';
import 'camera_driver.dart';

/// 专业相机后端的主通道；由 Android 宿主的 MainActivity 注册。
const MethodChannel proCameraChannel = MethodChannel('lens_vault/pro_camera');

/// 专业相机预览的 PlatformView 类型。
const String proCameraViewType = 'lens_vault/pro_camera_preview';

/// 基于独占原生 Camera2 会话的 [CameraDriver] 实现。
///
/// 与 [PluginCameraDriver] 互斥：两者不能同时持有同一台摄像头，切换后端前
/// 必须先释放本驱动。平台错误统一转为 [CameraException]，其中权限失败使用
/// `CameraAccess*` / `AudioAccess*` 前缀，保持与上层错误处理一致。
class NativeCameraDriver implements CameraDriver {
  RecordingSettings _requested = const RecordingSettings();
  String _accepted = '已接受 1080p / 30 FPS';
  double _zoomMin = 1;
  double _zoomMax = 1;
  bool _initialized = false;

  /// 平台通道与预览视图是否可用；非 Android 或未注册时返回 false。
  static Future<bool> probe() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await proCameraChannel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  String get requestedLabel => '请求 ${_requested.label}';

  @override
  String get acceptedLabel => _accepted;

  @override
  Future<List<CameraDescription>> cameras() async {
    final result = await _invoke<List<Object?>>('cameras');
    return [
      for (final value in result ?? const [])
        if (value is Map)
          CameraDescription(
            name: value['id'] as String,
            lensDirection: switch (value['facing']) {
              'front' => CameraLensDirection.front,
              'back' => CameraLensDirection.back,
              _ => CameraLensDirection.external,
            },
            sensorOrientation:
                (value['sensorOrientation'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  @override
  Future<void> initialize(
    CameraDescription camera,
    bool audio,
    RecordingSettings settings,
  ) async {
    await dispose();
    _requested = settings;
    final permissions = await _permissions(audio);
    if (permissions?['camera'] != true) {
      throw CameraException('CameraAccessDenied', '相机权限未授权');
    }
    if (audio && permissions?['audio'] != true) {
      throw CameraException('AudioAccessDenied', '麦克风权限未授权');
    }
    final accepted = await _invoke<Map<Object?, Object?>>('initialize', {
      'cameraId': camera.name,
      'audio': audio,
      'quality': _qualityName(settings.quality),
      'fps': switch (settings.fps) {
        CaptureFps.auto => null,
        CaptureFps.fps30 => 30,
        CaptureFps.fps60 => 60,
      },
      'bitrateBps': settings.videoBitrateBps,
    });
    _initialized = true;
    final quality = _qualityLabel(accepted?['quality'] as String?);
    final fps = accepted?['fps'] as num?;
    _accepted = '已接受 $quality / ${fps == null ? '自动帧率' : '${fps.toInt()} FPS'}';
    final range = await _invoke<Map<Object?, Object?>>('zoomRange');
    _zoomMin = (range?['min'] as num?)?.toDouble() ?? 1;
    _zoomMax = (range?['max'] as num?)?.toDouble() ?? 1;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    try {
      await proCameraChannel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      /* 宿主不可用时无需释放。 */
    } on PlatformException {
      /* 释放失败不能阻塞页面退出。 */
    }
  }

  @override
  Future<double> minZoom() async => _zoomMin;

  @override
  Future<double> maxZoom() async => _zoomMax;

  @override
  Future<void> zoom(double value) async {
    await _invoke<Map<Object?, Object?>>('setZoom', {'ratio': value});
  }

  @override
  Future<LensCapabilities?> capabilities() async {
    if (!_initialized) return null;
    try {
      final value = await _invoke<Map<Object?, Object?>>('capabilities');
      if (value == null) return null;
      return LensCapabilities(
        zoomMin: (value['zoomMin'] as num?)?.toDouble() ?? 1,
        zoomMax: (value['zoomMax'] as num?)?.toDouble() ?? 1,
        exposureOffsetMin:
            (value['exposureOffsetMin'] as num?)?.toDouble() ?? 0,
        exposureOffsetMax:
            (value['exposureOffsetMax'] as num?)?.toDouble() ?? 0,
        exposureOffsetStep:
            (value['exposureOffsetStep'] as num?)?.toDouble() ?? 0,
        exposurePointSupported: value['exposurePointSupported'] == true,
        focusPointSupported: value['focusPointSupported'] == true,
        torchSupported: value['torchSupported'] == true,
      );
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<ParameterApplyResult> setExposureOffset(double value) async {
    try {
      final result = await proCameraChannel.invokeMapMethod<Object?, Object?>(
        'setExposureOffset',
        {'ev': value},
      );
      return ParameterApplyResult.accepted(
        (result?['ev'] as num?)?.toDouble() ?? value,
      );
    } on PlatformException catch (error) {
      return ParameterApplyResult.failed(_parameterFailure(error));
    }
  }

  @override
  Future<ParameterApplyResult> resetExposureOffset() => setExposureOffset(0);

  @override
  Future<ParameterApplyResult> setTorch(bool enabled) async {
    try {
      final result = await proCameraChannel.invokeMapMethod<Object?, Object?>(
        'setTorch',
        {'enabled': enabled},
      );
      return ParameterApplyResult.accepted(result?['enabled'] == true ? 1 : 0);
    } on PlatformException catch (error) {
      return ParameterApplyResult.failed(_parameterFailure(error));
    }
  }

  @override
  Future<void> setFocusPoint(Offset? point) async {
    await _invoke<void>('setFocusPoint', _point(point));
  }

  @override
  Future<void> setExposurePoint(Offset? point) async {
    await _invoke<void>('setExposurePoint', _point(point));
  }

  @override
  Future<List<VideoStabilizationMode>> supportedStabilizationModes() async {
    if (!_initialized) return const [];
    try {
      final modes = await _invoke<List<Object?>>('stabilizationModes');
      return [
        for (final mode in modes ?? const [])
          if (mode == 'on')
            VideoStabilizationMode.level1
          else if (mode == 'off')
            VideoStabilizationMode.off,
      ];
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<VideoStabilizationMode?> setStabilizationMode(
    VideoStabilizationMode mode,
  ) async {
    if (!_initialized) return null;
    try {
      final result = await _invoke<Map<Object?, Object?>>('setStabilization', {
        'mode': mode == VideoStabilizationMode.off ? 'off' : 'on',
      });
      return result?['mode'] == 'on'
          ? VideoStabilizationMode.level1
          : VideoStabilizationMode.off;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> start() async {
    await _invoke<Map<Object?, Object?>>('start');
  }

  @override
  Future<XFile> stop() async {
    final result = await _invoke<Map<Object?, Object?>>('stop');
    final path = result?['path'] as String?;
    if (path == null || path.isEmpty) {
      throw CameraException('recording_missing', '录像文件不可用');
    }
    return XFile(path);
  }

  @override
  Widget preview() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return const AndroidView(viewType: proCameraViewType);
  }

  Map<String, Object?> _point(Offset? point) => point == null
      ? const {'x': null, 'y': null}
      : {'x': point.dx, 'y': point.dy};

  Future<Map<String, Object?>?> _permissions(bool audio) async {
    try {
      final value = await proCameraChannel.invokeMapMethod<Object?, Object?>(
        'ensurePermissions',
        {'audio': audio},
      );
      return value?.cast<String, Object?>();
    } on PlatformException catch (error) {
      throw CameraException(error.code, error.message ?? '权限请求失败');
    }
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await proCameraChannel.invokeMethod<T>(method, args);
    } on PlatformException catch (error) {
      throw _cameraException(error);
    }
  }

  CameraException _cameraException(PlatformException error) {
    final code = switch (error.code) {
      'camera_access' => 'CameraAccessDenied',
      _ => error.code,
    };
    return CameraException(code, error.message ?? '相机操作失败');
  }

  ParameterApplyFailure _parameterFailure(PlatformException error) =>
      switch (error.code) {
        'unsupported' => ParameterApplyFailure.unsupported,
        'session_closed' => ParameterApplyFailure.sessionClosed,
        'invalid_argument' => ParameterApplyFailure.outOfRange,
        _ => ParameterApplyFailure.deviceRejected,
      };

  String _qualityName(CaptureQuality quality) => switch (quality) {
    CaptureQuality.p480 => '480p',
    CaptureQuality.p720 => '720p',
    CaptureQuality.p1080 => '1080p',
    CaptureQuality.max => 'max',
  };

  String _qualityLabel(String? quality) => switch (quality) {
    '480p' => '480p',
    '720p' => '720p',
    '1080p' => '1080p',
    'max' => '设备最高',
    _ => '设备分辨率',
  };
}
