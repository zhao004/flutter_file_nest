import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../models/camera_capture_settings.dart';
import '../../models/camera_parameter_models.dart';
import '../../models/camera_presets.dart';
import '../../models/storage_entry.dart';
import '../../services/recording_service.dart';
import '../../services/saf_storage.dart';
import '../../services/vault_store.dart';
import 'camera_driver.dart';

enum CaptureState {
  initializing,
  ready,
  recording,
  saving,
  pending,
  saved,
  suspended,
  failed,
}

/// 串行化相机与生命周期事件，防止快速点击或后台切换并发销毁同一会话。
class AppCameraController extends GetxController with WidgetsBindingObserver {
  AppCameraController({
    required this.folder,
    required this.driver,
    required this.recordings,
    required bool audio,
    required this.saveAudio,
  }) : audioEnabled = audio.obs;
  final StorageEntry folder;
  final CameraDriver driver;
  final RecordingService recordings;
  final Future<void> Function(bool) saveAudio;
  final state = CaptureState.initializing.obs;
  final busy = false.obs;
  final RxBool audioEnabled;
  final message = RxnString();
  final elapsed = Duration.zero.obs;
  final zoomLevel = 1.0.obs;
  final minZoom = 1.0.obs;
  final maxZoom = 1.0.obs;

  /// 规格信息：请求值与后端已接受值并列展示，不得混用。
  final specLabel = ''.obs;
  final cameraCount = 0.obs;

  /// 当前镜头能力；null 表示尚未探测或探测失败，控件按不可用处理。
  final capabilities = Rxn<LensCapabilities>();

  /// 曝光补偿：保存后端实际接受的 EV 值；拖动中的请求值由滑杆内部状态承载。
  final exposureOffset = 0.0.obs;
  final torchEnabled = false.obs;
  final focusPoint = Rxn<Offset>();
  final exposurePoint = Rxn<Offset>();
  final Map<String, LensCapabilities> _capabilityCache = {};
  bool _torchDesired = false;

  /// 用户请求的录制规格；初始化成功前保持上一次可用配置不变。
  final requestedSettings = const RecordingSettings().obs;

  /// 当前镜头支持的防抖模式；仅含 off 或为空时界面不展示防抖控件。
  final stabilizationModes = RxList<VideoStabilizationMode>(const []);
  final stabilizationMode = Rxn<VideoStabilizationMode>();

  /// 已选预设名称；null 表示未选择预设。用户手动改参后 [presetModified] 置位，
  /// 用于区分"完整预设生效"与"预设基础上的自定义配置"。
  final activePresetName = RxnString();
  final presetModified = false.obs;
  List<CameraDescription> _cameras = [];
  int _index = 0;
  RecordingJob? _job;
  XFile? _unstagedFile;
  Future<void> _tail = Future.value();
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  bool _foreground = true;
  bool _closed = false;
  bool _initialized = false;
  bool _zoomRunning = false;
  bool _stopPending = false;
  double? _requestedZoom;
  bool get canLeavePending => _unstagedFile == null && !_stopPending;
  bool get needsStop => _stopPending;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> _serial(Future<void> Function() action) {
    final work = _tail.then((_) async {
      if (_closed) return;
      busy.value = true;
      try {
        await action();
      } catch (error) {
        message.value = _stopPending
            ? '停止录制失败，尚未取得完整视频。请重试停止或放弃本次录像。'
            : cameraError(error);
        state.value = _job == null ? CaptureState.failed : CaptureState.pending;
      } finally {
        busy.value = false;
      }
    });
    _tail = work;
    return work;
  }

  Future<void> initialize() => _serial(_initialize);

  Future<void> _initialize() async {
    if (!_foreground ||
        _closed ||
        _job != null ||
        state.value == CaptureState.saved) {
      return;
    }
    state.value = CaptureState.initializing;
    if (_cameras.isEmpty) {
      final available = await driver.cameras();
      for (final direction in [
        CameraLensDirection.back,
        CameraLensDirection.front,
      ]) {
        final candidates = available.where(
          (camera) => camera.lensDirection == direction,
        );
        if (candidates.isNotEmpty) _cameras.add(candidates.first);
      }
      if (_cameras.isEmpty && available.isNotEmpty) {
        _cameras = [available.first];
      }
      if (_cameras.isEmpty) throw CameraException('no_camera', '没有可用摄像头');
      cameraCount.value = _cameras.length;
    }
    _initialized = false;
    try {
      await driver.initialize(
        _cameras[_index],
        audioEnabled.value,
        requestedSettings.value,
      );
    } on CameraException catch (error) {
      if (!error.code.startsWith('AudioAccess')) rethrow;
      audioEnabled.value = false;
      await saveAudio(false);
      message.value = '麦克风权限未授权，已切换静音录制';
      await driver.initialize(_cameras[_index], false, requestedSettings.value);
    }
    _initialized = true;
    minZoom.value = await driver.minZoom();
    maxZoom.value = await driver.maxZoom();
    zoomLevel.value = 1.0.clamp(minZoom.value, maxZoom.value);
    specLabel.value = '${driver.requestedLabel} · ${driver.acceptedLabel}';
    await _probeCapabilities();
    await _probeStabilization();
    await _restoreParameters();
    if (!_foreground || _closed) {
      await _release();
      state.value = CaptureState.suspended;
    } else {
      state.value = CaptureState.ready;
    }
  }

  /// 按镜头探测并缓存能力；同一镜头重复探测直接命中缓存，切换镜头后读取对应能力。
  Future<void> _probeCapabilities() async {
    final camera = _cameras[_index];
    try {
      var cached = _capabilityCache[camera.name];
      cached ??= await driver.capabilities();
      if (cached == null) {
        capabilities.value = null;
        message.value = '未能读取镜头能力，部分参数不可用';
      } else {
        _capabilityCache[camera.name] = cached;
        capabilities.value = cached;
      }
    } catch (_) {
      capabilities.value = null;
      message.value = '未能读取镜头能力，部分参数不可用';
    }
  }

  /// 会话重建后参数回到设备默认；补光按用户意图在具备能力的镜头上重新应用。
  Future<void> _restoreParameters() async {
    exposureOffset.value = 0;
    focusPoint.value = null;
    exposurePoint.value = null;
    if (_torchDesired && (capabilities.value?.torchSupported ?? false)) {
      final result = await driver.setTorch(true);
      torchEnabled.value = result.ok;
      if (!result.ok) _torchDesired = false;
    } else {
      torchEnabled.value = false;
    }
  }

  /// 探测防抖模式；后端未实现时保持空列表，界面据此隐藏，每次会话重建后重新校验。
  Future<void> _probeStabilization() async {
    try {
      final modes = await driver.supportedStabilizationModes();
      stabilizationModes.assignAll(modes);
      stabilizationMode.value = VideoStabilizationMode.off;
    } catch (_) {
      stabilizationModes.assignAll(const []);
      stabilizationMode.value = null;
    }
  }

  /// 应用防抖模式；返回 null 表示设备不支持，保持原模式不变。
  Future<bool> setStabilization(VideoStabilizationMode mode) async {
    if (!_live || !stabilizationModes.contains(mode)) return false;
    var applied = false;
    await _serial(() async {
      try {
        final actual = await driver.setStabilizationMode(mode);
        applied = actual != null;
        if (applied) {
          stabilizationMode.value = actual;
          _markPresetModified();
        } else {
          message.value = '当前设备不支持所选防抖模式';
        }
      } catch (_) {
        message.value = '防抖设置失败';
      }
    });
    return applied;
  }

  /// 应用新的录制规格；录制中先完成停止保存，失败时恢复上一次可用配置。
  ///
  /// 规格（分辨率、帧率、码率）需要重建会话，不能在录制中热更新。
  Future<void> applyCaptureSettings(RecordingSettings next) =>
      _serial(() async {
        if (next == requestedSettings.value) return;
        if (state.value == CaptureState.recording) await _stop();
        if (_job != null) return;
        final previous = requestedSettings.value;
        state.value = CaptureState.initializing;
        requestedSettings.value = next;
        try {
          await _initialize();
          _markPresetModified();
        } on CameraException {
          requestedSettings.value = previous;
          message.value = '所选规格不可用，已恢复上次可用配置';
          state.value = CaptureState.initializing;
          await _initialize();
        }
      });

  void _markPresetModified() {
    if (activePresetName.value != null) {
      presetModified.value = true;
    }
  }

  /// 标记预设已完整生效；预设页在保存或覆盖当前配置后调用。
  void markPresetApplied(String name) {
    activePresetName.value = name;
    presetModified.value = false;
  }

  /// 清除已选预设状态；删除或放弃当前预设时调用。
  void clearActivePreset() {
    activePresetName.value = null;
    presetModified.value = false;
  }

  /// 以当前会话状态生成预设配置快照（含用户当前的音频与补光选择）。
  PresetConfig capturePresetConfig() => PresetConfig(
    quality: requestedSettings.value.quality,
    fps: requestedSettings.value.fps,
    videoBitrateBps: requestedSettings.value.videoBitrateBps,
    audioEnabled: audioEnabled.value,
    zoomRatio: zoomLevel.value,
    exposureCompensationEv: exposureOffset.value,
    torchEnabled: torchEnabled.value,
  );

  /// 应用预设：先按当前镜头能力校验，再依次重建规格、音频、曝光、补光与变焦。
  ///
  /// 返回逐项结果；存在跳过或降级项时报告为"部分应用"，不冒充完整生效。
  /// 录制中由界面先确认停止保存，会话重建沿用 [applyCaptureSettings] 的停止流程。
  Future<PresetApplyReport> applyPreset(CameraPreset preset) async {
    final report = PresetApplyReport(preset.name);
    final config = preset.config;
    if (config == null) {
      report.note(preset.issue ?? '预设配置不可用');
      return report;
    }
    if (state.value == CaptureState.pending) {
      report.note('存在待保存录像，暂不能应用预设');
      return report;
    }
    if (state.value == CaptureState.recording) {
      await _serial(() async {
        if (state.value == CaptureState.recording) await _stop();
      });
      if (_job != null) {
        report.note('停止保存未完成，暂不能应用预设');
        return report;
      }
    }
    if (state.value == CaptureState.saved) {
      // 停止保存会释放会话；先重新打开，避免报告已应用但参数并未生效。
      await _serial(() async {
        state.value = CaptureState.suspended;
        await _initialize();
      });
    }
    if (!_live) {
      report.note('相机会话不可用，预设参数未应用');
      return report;
    }
    final validation = validatePresetConfig(config, capabilities.value);
    for (final adjustment in validation.adjustments) {
      report.note(adjustment.message);
    }
    final target = validation.adjusted;
    final desired = target.toRecordingSettings();
    await applyCaptureSettings(desired);
    if (requestedSettings.value != desired) {
      report.note('录制规格未按请求应用，已保留原配置');
    } else if (!driver.acceptedLabel.contains(desired.qualityLabel) ||
        !driver.acceptedLabel.contains(desired.fpsLabel)) {
      report.note('设备按能力降级：${driver.acceptedLabel}');
    }
    final audio = target.audioEnabled;
    if (audio != null && audio != audioEnabled.value) {
      await setAudio(audio);
      if (audioEnabled.value != audio) {
        report.note('麦克风权限未授权，保持静音');
      }
    }
    final caps = capabilities.value;
    if (target.exposureCompensationEv != 0) {
      if (caps != null && caps.hasExposureOffset) {
        final result = await applyExposureOffset(target.exposureCompensationEv);
        if (!result.ok) {
          report.note('曝光补偿设置失败');
        } else if (result.acceptedValue != null &&
            (result.acceptedValue! - target.exposureCompensationEv).abs() >
                1e-6) {
          report.note(
            '曝光补偿按设备步长调整为 '
            '${result.acceptedValue!.toStringAsFixed(1)} EV',
          );
        }
      }
    } else if (exposureOffset.value != 0 &&
        caps != null &&
        caps.hasExposureOffset) {
      // 预设未启用曝光补偿时复位，避免上次预设的值继续影响画面。
      await resetExposure();
    }
    if (target.torchEnabled) {
      await setTorch(true);
      if (!torchEnabled.value) {
        report.note('补光未能开启');
      }
    } else if (torchEnabled.value) {
      await setTorch(false);
    }
    await setZoom(target.zoomRatio);
    if ((zoomLevel.value - target.zoomRatio).abs() > 0.01) {
      report.note('变焦按设备范围调整为 ${zoomLevel.value.toStringAsFixed(1)}x');
    }
    activePresetName.value = preset.name;
    presetModified.value = !report.fullyApplied;
    return report;
  }

  Future<void> start() => _serial(() async {
    if (state.value != CaptureState.ready || !_foreground) return;
    message.value = null;
    _job = await recordings.prepare(folder);
    try {
      await driver.start();
    } catch (_) {
      await recordings.discard(_job!);
      _job = null;
      rethrow;
    }
    state.value = CaptureState.recording;
    _clock
      ..reset()
      ..start();
    elapsed.value = Duration.zero;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => elapsed.value = _clock.elapsed,
    );
  });

  Future<void> stop() => _serial(_stop);
  Future<void> _stop() async {
    if (state.value != CaptureState.recording) return;
    _clock.stop();
    _timer?.cancel();
    state.value = CaptureState.saving;
    _stopPending = true;
    _unstagedFile = await driver.stop();
    _stopPending = false;
    await _savePending();
  }

  Future<void> _savePending() async {
    var job = _job;
    if (job == null) return;
    state.value = CaptureState.saving;
    if (_stopPending) {
      if (!_initialized) throw CameraException('session_closed', '相机会话已关闭');
      _unstagedFile = await driver.stop();
      _stopPending = false;
    }
    if (_unstagedFile != null) {
      job = await recordings.attachSource(job, _unstagedFile!);
      _job = job;
      _unstagedFile = null;
    }
    await recordings.commit(job);
    _job = null;
    message.value = '视频已保存';
    state.value = CaptureState.saved;
    await _release();
  }

  Future<void> retrySave() => _serial(_savePending);

  Future<void> discard() => _serial(() async {
    final job = _job;
    if (job == null) return;
    await _release();
    await recordings.discard(
      _unstagedFile == null ? job : job.withTemporaryPath(_unstagedFile!.path),
    );
    _job = null;
    _unstagedFile = null;
    _stopPending = false;
    message.value = null;
    state.value = CaptureState.suspended;
    await _initialize();
  });

  Future<void> switchCamera() => _serial(() async {
    if (state.value == CaptureState.recording) await _stop();
    if (_job != null || _cameras.length < 2) return;
    state.value = CaptureState.initializing;
    _index = (_index + 1) % _cameras.length;
    await _initialize();
  });

  Future<void> toggleAudio() => setAudio(!audioEnabled.value);

  /// 显式设置音频开关；与当前值相同时不重建会话。
  Future<void> setAudio(bool enabled) => _serial(() async {
    if (enabled == audioEnabled.value) return;
    if (state.value == CaptureState.recording) await _stop();
    if (_job != null) return;
    await saveAudio(enabled);
    audioEnabled.value = enabled;
    state.value = CaptureState.initializing;
    await _initialize();
    _markPresetModified();
  });

  Future<void> setZoom(double value) async {
    if (!_initialized ||
        (busy.value && !_zoomRunning) ||
        ![CaptureState.ready, CaptureState.recording].contains(state.value)) {
      return;
    }
    _requestedZoom = value.clamp(minZoom.value, maxZoom.value);
    if (_zoomRunning) return;
    _zoomRunning = true;
    await _serial(() async {
      try {
        while (_requestedZoom != null && _initialized) {
          final requested = _requestedZoom!;
          _requestedZoom = null;
          await driver.zoom(requested);
          zoomLevel.value = requested;
          _markPresetModified();
        }
      } catch (_) {
        message.value = '当前倍率不可用';
      } finally {
        _zoomRunning = false;
      }
    });
  }

  /// 设置曝光补偿；返回结构化结果，失败时保留后端最后一次接受值。
  Future<ParameterApplyResult> applyExposureOffset(double value) async {
    final caps = capabilities.value;
    if (!_live || caps == null || !caps.hasExposureOffset) {
      return const ParameterApplyResult.failed(
        ParameterApplyFailure.unsupported,
      );
    }
    final requested = value
        .clamp(caps.exposureOffsetMin, caps.exposureOffsetMax)
        .toDouble();
    var result = const ParameterApplyResult.failed(
      ParameterApplyFailure.unsupported,
    );
    await _serial(() async {
      try {
        result = await driver.setExposureOffset(requested);
        if (result.ok && result.acceptedValue != null) {
          exposureOffset.value = result.acceptedValue!;
          _markPresetModified();
        } else {
          message.value = '曝光补偿设置失败，已保留原值';
        }
      } catch (_) {
        result = const ParameterApplyResult.failed(
          ParameterApplyFailure.deviceRejected,
        );
        message.value = '曝光补偿设置失败，已保留原值';
      }
    });
    return result;
  }

  /// 将曝光补偿复位为 0 EV。
  Future<ParameterApplyResult> resetExposure() => applyExposureOffset(0);

  /// 切换持续补光；仅在已探测到补光能力的镜头上执行。
  Future<void> toggleTorch() => setTorch(!torchEnabled.value);

  /// 显式设置补光；能力不支持或状态相同时直接返回。
  Future<void> setTorch(bool enabled) async {
    final caps = capabilities.value;
    if (!_live ||
        caps == null ||
        !caps.torchSupported ||
        enabled == torchEnabled.value) {
      return;
    }
    _torchDesired = enabled;
    await _serial(() async {
      try {
        final result = await driver.setTorch(enabled);
        if (result.ok) {
          torchEnabled.value = enabled;
          _markPresetModified();
        } else {
          _torchDesired = torchEnabled.value;
          message.value = enabled ? '补光灯不可用' : '补光灯关闭失败';
        }
      } catch (_) {
        _torchDesired = torchEnabled.value;
        message.value = '补光灯不可用';
      }
    });
  }

  /// 点按对焦与测光；前摄预览为镜像显示，水平坐标需翻转后下发。
  Future<void> tapFocus(Offset normalizedPoint) async {
    final caps = capabilities.value;
    if (!_live || caps == null) return;
    if (!caps.focusPointSupported && !caps.exposurePointSupported) {
      message.value = '当前镜头不支持点按对焦/测光';
      return;
    }
    final camera = _cameras[_index];
    final mirrored = camera.lensDirection == CameraLensDirection.front
        ? Offset(1 - normalizedPoint.dx, normalizedPoint.dy)
        : normalizedPoint;
    focusPoint.value = normalizedPoint;
    if (caps.focusPointSupported && caps.exposurePointSupported) {
      exposurePoint.value = normalizedPoint;
    }
    await _serial(() async {
      try {
        if (caps.focusPointSupported) await driver.setFocusPoint(mirrored);
        if (caps.exposurePointSupported) {
          await driver.setExposurePoint(mirrored);
        }
      } catch (_) {
        message.value = '对焦/测光设置失败';
      }
    });
  }

  /// 清除点按对焦与测光区域，恢复为默认中央区域。
  Future<void> clearFocusPoint() async {
    if (!_live) return;
    await _serial(() async {
      try {
        await driver.setFocusPoint(null);
        await driver.setExposurePoint(null);
        focusPoint.value = null;
        exposurePoint.value = null;
      } catch (_) {
        message.value = '重置对焦/测光失败';
      }
    });
  }

  /// 双指捏合的基准倍率；手势期间的连续请求合并到现有变焦循环。
  double? _pinchBaseZoom;

  void beginPinch() {
    if (_live) _pinchBaseZoom = zoomLevel.value;
  }

  Future<void> updatePinch(double scale) {
    final base = _pinchBaseZoom;
    if (base == null) return Future.value();
    return setZoom(base * scale);
  }

  void endPinch() {
    _pinchBaseZoom = null;
  }

  bool get _live =>
      _initialized &&
      [CaptureState.ready, CaptureState.recording].contains(state.value);

  Future<void> _release() async {
    _initialized = false;
    _requestedZoom = null;
    _pinchBaseZoom = null;
    focusPoint.value = null;
    exposurePoint.value = null;
    await driver.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      initialize();
    } else {
      _foreground = false;
      _serial(() async {
        try {
          if (this.state.value == CaptureState.recording) await _stop();
        } finally {
          await _release();
        }
        if (_job == null && this.state.value != CaptureState.saved) {
          this.state.value = CaptureState.suspended;
        }
      });
    }
  }

  @override
  void onClose() {
    _closed = true;
    _timer?.cancel();
    _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    _tail.then((_) => _release());
    super.onClose();
  }
}

String cameraError(Object error) {
  if (error is CameraException) {
    if (error.code.startsWith('CameraAccess')) return '相机权限未授权，请在系统设置中允许相机访问';
    if (error.code.startsWith('AudioAccess')) return '麦克风权限未授权，可使用静音录制';
    if (error.code == 'no_camera') return '没有可用摄像头';
    return '相机会话中断，请重试';
  }
  return userError(error);
}
