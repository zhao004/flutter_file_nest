import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lens_vault/app/models/camera_capture_settings.dart';
import 'package:flutter_lens_vault/app/models/camera_parameter_models.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/pages/camera/camera_driver.dart';
import 'package:flutter_lens_vault/app/services/recording_service.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';

import 'fakes.dart';

const backCaps = LensCapabilities(
  zoomMin: 1,
  zoomMax: 5,
  exposureOffsetMin: -2,
  exposureOffsetMax: 2,
  exposureOffsetStep: 0.5,
  exposurePointSupported: true,
  focusPointSupported: true,
  torchSupported: false,
);

const frontCaps = LensCapabilities(
  zoomMin: 1,
  zoomMax: 1,
  exposureOffsetMin: 0,
  exposureOffsetMax: 0,
  exposureOffsetStep: 0,
  exposurePointSupported: true,
  focusPointSupported: true,
  torchSupported: false,
);

/// 可编程相机假件；覆盖测试需要的探测、参数与失败注入点。
class FakeCamera implements CameraDriver {
  final initializedAudio = <bool>[];
  bool denyAudio = false;
  bool denyCamera = false;
  bool failStop = false;
  int starts = 0;
  int stops = 0;
  int disposes = 0;
  final zooms = <double>[];
  @override
  String get requestedLabel =>
      '请求 ${lastSettings?.label ?? const RecordingSettings().label}';
  @override
  String get acceptedLabel => '已接受 ${lastSettings?.label ?? ''}';

  /// 后镜头补光能力；初始化前置位可模拟带补光灯的设备。
  bool torchSupported = false;
  bool failTorch = false;
  bool failExposure = false;

  /// 模拟设备按步长取整后实际接受的曝光值；null 表示原样接受请求值。
  double? exposureActual;
  CameraLensDirection? lastLens;
  RecordingSettings? lastSettings;

  /// 置位后模拟设备拒绝 60 FPS 请求，触发规格恢复逻辑。
  bool rejectFps60 = false;
  bool stabilizationSupported = false;
  bool failStabilization = false;
  VideoStabilizationMode? stabilizationApplied;
  int backProbeCount = 0;
  int frontProbeCount = 0;
  final exposureRequests = <double>[];
  final focusPoints = <Offset>[];
  final torchRequests = <bool>[];
  @override
  Future<List<CameraDescription>> cameras() async => [
    const CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
    const CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
    ),
  ];
  @override
  Future<void> initialize(
    CameraDescription camera,
    bool audio,
    RecordingSettings settings,
  ) async {
    lastLens = camera.lensDirection;
    lastSettings = settings;
    initializedAudio.add(audio);
    if (denyCamera) throw CameraException('CameraAccessDenied', 'denied');
    if (audio && denyAudio) {
      throw CameraException('AudioAccessDenied', 'denied');
    }
    if (rejectFps60 && settings.fps == CaptureFps.fps60) {
      throw CameraException('invalid_fps', 'fps not supported');
    }
  }

  @override
  Future<void> dispose() async {
    disposes++;
  }

  @override
  Future<double> minZoom() async => 1;
  @override
  Future<double> maxZoom() async =>
      lastLens == CameraLensDirection.front ? 1 : 5;
  @override
  Future<void> zoom(double value) async {
    zooms.add(value);
  }

  @override
  Future<LensCapabilities?> capabilities() async {
    if (lastLens == CameraLensDirection.front) {
      frontProbeCount++;
      return frontCaps;
    }
    backProbeCount++;
    return LensCapabilities(
      zoomMin: backCaps.zoomMin,
      zoomMax: backCaps.zoomMax,
      exposureOffsetMin: backCaps.exposureOffsetMin,
      exposureOffsetMax: backCaps.exposureOffsetMax,
      exposureOffsetStep: backCaps.exposureOffsetStep,
      exposurePointSupported: backCaps.exposurePointSupported,
      focusPointSupported: backCaps.focusPointSupported,
      torchSupported: torchSupported,
    );
  }

  @override
  Future<ParameterApplyResult> setExposureOffset(double value) async {
    exposureRequests.add(value);
    if (failExposure) {
      return const ParameterApplyResult.failed(
        ParameterApplyFailure.deviceRejected,
      );
    }
    return ParameterApplyResult.accepted(exposureActual ?? value);
  }

  @override
  Future<ParameterApplyResult> resetExposureOffset() => setExposureOffset(0);

  @override
  Future<ParameterApplyResult> setTorch(bool enabled) async {
    torchRequests.add(enabled);
    if (failTorch || !torchSupported) {
      return const ParameterApplyResult.failed(
        ParameterApplyFailure.unsupported,
      );
    }
    return ParameterApplyResult.accepted(enabled ? 1 : 0);
  }

  @override
  Future<void> setFocusPoint(Offset? point) async {
    if (point != null) focusPoints.add(point);
  }

  @override
  Future<void> setExposurePoint(Offset? point) async {}

  @override
  Future<List<VideoStabilizationMode>> supportedStabilizationModes() async =>
      stabilizationSupported
      ? const [VideoStabilizationMode.off, VideoStabilizationMode.level1]
      : const [VideoStabilizationMode.off];

  @override
  Future<VideoStabilizationMode?> setStabilizationMode(
    VideoStabilizationMode mode,
  ) async {
    if (failStabilization) return null;
    if (stabilizationSupported &&
        (mode == VideoStabilizationMode.level1 ||
            mode == VideoStabilizationMode.off)) {
      stabilizationApplied = mode;
      return mode;
    }
    return null;
  }

  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<XFile> stop() async {
    stops++;
    if (failStop) throw CameraException('stop_failed', 'failed');
    return XFile('private/video.mp4');
  }

  @override
  Widget preview() => const SizedBox.expand();
}

/// 绕过私有暂存目录的录制服务假件，便于断言提交与清理顺序。
class FakeRecordings extends RecordingService {
  FakeRecordings(super.storage, super.store);
  bool failCommit = false;
  int staged = 0;
  int commits = 0;
  @override
  Future<RecordingJob> prepare(StorageEntry folder) async {
    final job = RecordingJob(
      id: 'test',
      sourcePath: 'private/video.mp4',
      rootUri: root.rootUri,
      parentId: folder.documentId,
      fileName: 'video.mp4',
      createdAt: DateTime.now(),
    );
    await store.addJob(job);
    return job;
  }

  @override
  Future<void> stage(RecordingJob job, XFile file) async {
    staged++;
  }

  @override
  Future<StorageEntry> commit(RecordingJob job) async {
    commits++;
    if (staged == 0 && job.temporaryPath != null) {
      await stage(job, XFile(job.temporaryPath!));
    }
    if (failCommit) {
      throw PlatformException(code: 'write_failed', message: '保存失败');
    }
    await store.removeJob(job.id);
    return entry('video.mp4');
  }

  @override
  Future<void> discard(RecordingJob job) => store.removeJob(job.id);
}
