import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

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
  final targetLabel = ''.obs;
  final cameraCount = 0.obs;
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
      await driver.initialize(_cameras[_index], audioEnabled.value);
    } on CameraException catch (error) {
      if (!error.code.startsWith('AudioAccess')) rethrow;
      audioEnabled.value = false;
      await saveAudio(false);
      message.value = '麦克风权限未授权，已切换静音录制';
      await driver.initialize(_cameras[_index], false);
    }
    _initialized = true;
    minZoom.value = await driver.minZoom();
    maxZoom.value = await driver.maxZoom();
    zoomLevel.value = 1.0.clamp(minZoom.value, maxZoom.value);
    targetLabel.value = driver.targetLabel;
    if (!_foreground || _closed) {
      await _release();
      state.value = CaptureState.suspended;
    } else {
      state.value = CaptureState.ready;
    }
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

  Future<void> toggleAudio() => _serial(() async {
    if (state.value == CaptureState.recording) await _stop();
    if (_job != null) return;
    final next = !audioEnabled.value;
    await saveAudio(next);
    audioEnabled.value = next;
    state.value = CaptureState.initializing;
    await _initialize();
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
        }
      } catch (_) {
        message.value = '当前倍率不可用';
      } finally {
        _zoomRunning = false;
      }
    });
  }

  Future<void> _release() async {
    _initialized = false;
    _requestedZoom = null;
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
