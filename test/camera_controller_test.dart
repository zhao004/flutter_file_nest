import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_lens_vault/app/pages/camera/app_camera_controller.dart';
import 'package:flutter_lens_vault/app/pages/camera/camera_driver.dart';
import 'package:flutter_lens_vault/app/pages/camera/camera_view.dart';
import 'package:flutter_lens_vault/app/services/recording_service.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'support/fakes.dart';

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
  String get targetLabel => '1080p / 30 FPS（目标）';
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
  Future<void> initialize(CameraDescription camera, bool audio) async {
    initializedAudio.add(audio);
    if (denyCamera) throw CameraException('CameraAccessDenied', 'denied');
    if (audio && denyAudio) {
      throw CameraException('AudioAccessDenied', 'denied');
    }
  }

  @override
  Future<void> dispose() async {
    disposes++;
  }

  @override
  Future<double> minZoom() async => 1;
  @override
  Future<double> maxZoom() async => 5;
  @override
  Future<void> zoom(double value) async {
    zooms.add(value);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCamera camera;
  late MemoryStore store;
  late FakeRecordings recordings;
  late AppCameraController controller;
  void createController() {
    camera = FakeCamera();
    store = MemoryStore();
    recordings = FakeRecordings(FakeStorage(), store);
    controller = AppCameraController(
      folder: root,
      driver: camera,
      recordings: recordings,
      audio: true,
      saveAudio: (value) =>
          store.savePreferences(store.value.copyWith(audioEnabled: value)),
    );
  }

  setUp(createController);
  tearDown(() {
    controller.onClose();
  });

  test('麦克风拒绝时重建静音会话并持久化偏好', () async {
    camera.denyAudio = true;
    await controller.initialize();
    expect(camera.initializedAudio, [true, false]);
    expect(store.value.audioEnabled, false);
    expect(controller.state.value, CaptureState.ready);
  });
  test('拒绝相机权限时不进入可录制状态', () async {
    camera.denyCamera = true;
    await controller.initialize();
    expect(controller.state.value, CaptureState.failed);
    expect(controller.message.value, contains('相机权限'));
    expect(camera.starts, 0);
  });
  test('快速重复开始与停止不会重复录像或提交', () async {
    await controller.initialize();
    await Future.wait([controller.start(), controller.start()]);
    expect(camera.starts, 1);
    await Future.wait([controller.stop(), controller.stop()]);
    expect(camera.stops, 1);
    expect(recordings.commits, 1);
    expect(controller.state.value, CaptureState.saved);
    expect(store.jobs, isEmpty);
  });
  test('保存失败保留任务，重试不重复停止与暂存', () async {
    await controller.initialize();
    await controller.start();
    recordings.failCommit = true;
    await controller.stop();
    expect(controller.state.value, CaptureState.pending);
    expect(store.jobs, hasLength(1));
    recordings.failCommit = false;
    await controller.retrySave();
    expect(camera.stops, 1);
    expect(recordings.staged, 1);
    expect(store.jobs, isEmpty);
    expect(controller.state.value, CaptureState.saved);
  });
  test('进入后台会停止并保存，恢复前台不会重开录制', () async {
    await controller.initialize();
    await controller.start();
    controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await controller.stop();
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await controller.initialize();
    expect(camera.stops, 1);
    expect(camera.starts, 1);
    expect(controller.state.value, CaptureState.saved);
  });
  test('缩放限制在设备范围，并与镜头销毁串行执行', () async {
    await controller.initialize();
    await controller.setZoom(20);
    expect(camera.zooms.last, 5);
    await controller.setZoom(-1);
    expect(camera.zooms.last, 1);
  });

  test('停止失败不承诺离页恢复，重试先取得完整视频', () async {
    await controller.initialize();
    await controller.start();
    camera.failStop = true;
    await controller.stop();
    expect(controller.state.value, CaptureState.pending);
    expect(controller.needsStop, true);
    expect(controller.canLeavePending, false);
    expect(recordings.commits, 0);
    camera.failStop = false;
    await controller.retrySave();
    expect(camera.stops, 2);
    expect(recordings.commits, 1);
    expect(controller.state.value, CaptureState.saved);
  });

  test('停止失败后可明确放弃，释放会话并清理空任务', () async {
    await controller.initialize();
    await controller.start();
    camera.failStop = true;
    await controller.stop();
    await controller.discard();
    expect(store.jobs, isEmpty);
    expect(controller.needsStop, false);
    expect(controller.state.value, CaptureState.ready);
    expect(camera.disposes, greaterThan(0));
  });

  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('相机和停止失败状态适配 $size，放弃必须确认', (tester) async {
      createController();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.testMode = true;
      Get.put(controller);
      addTearDown(Get.reset);
      await tester.pumpWidget(const GetMaterialApp(home: CameraView()));
      await tester.pumpAndSettle();
      expect(find.byTooltip('开始录制'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await controller.start();
      camera.failStop = true;
      await controller.stop();
      await tester.pumpAndSettle();
      expect(find.text('重试停止'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('放弃录像'));
      await tester.tap(find.text('放弃录像'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(store.jobs, hasLength(1));
    });
  }
}
