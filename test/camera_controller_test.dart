import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_lens_vault/app/models/camera_capture_settings.dart';
import 'package:flutter_lens_vault/app/models/camera_presets.dart';
import 'package:flutter_lens_vault/app/pages/camera/app_camera_controller.dart';
import 'package:flutter_lens_vault/app/pages/camera/camera_view.dart';
import 'support/fakes.dart';
import 'support/camera_fakes.dart';

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

  test('能力按镜头探测并缓存，切换镜头读取对应能力', () async {
    await controller.initialize();
    expect(controller.capabilities.value?.zoomMax, 5);
    expect(controller.capabilities.value?.focusPointSupported, true);
    expect(camera.backProbeCount, 1);
    await controller.switchCamera();
    expect(controller.capabilities.value?.zoomMax, 1);
    expect(camera.frontProbeCount, 1);
    await controller.switchCamera();
    expect(camera.backProbeCount, 1);
    expect(camera.frontProbeCount, 1);
  });

  test('曝光补偿记录后端实际接受值，失败时保留原值', () async {
    await controller.initialize();
    camera.exposureActual = 0.5;
    final result = await controller.applyExposureOffset(0.3);
    expect(result.ok, true);
    expect(result.acceptedValue, 0.5);
    expect(controller.exposureOffset.value, 0.5);
    camera.failExposure = true;
    final failed = await controller.applyExposureOffset(1.0);
    expect(failed.ok, false);
    expect(controller.exposureOffset.value, 0.5);
    expect(controller.message.value, contains('曝光补偿'));
  });

  test('曝光补偿请求超出范围时先按设备范围收敛', () async {
    await controller.initialize();
    await controller.applyExposureOffset(99);
    expect(camera.exposureRequests.last, 2);
    await controller.applyExposureOffset(-99);
    expect(camera.exposureRequests.last, -2);
  });

  test('曝光复位把补偿恢复为 0 EV', () async {
    await controller.initialize();
    await controller.applyExposureOffset(1.5);
    await controller.resetExposure();
    expect(camera.exposureRequests.last, 0);
    expect(controller.exposureOffset.value, 0);
  });

  test('补光灯切换生效，切到无灯前摄关闭，切回后恢复', () async {
    camera.torchSupported = true;
    await controller.initialize();
    await controller.toggleTorch();
    expect(controller.torchEnabled.value, true);
    await controller.switchCamera();
    expect(controller.torchEnabled.value, false);
    await controller.switchCamera();
    expect(controller.torchEnabled.value, true);
    expect(camera.torchRequests, [true, true]);
  });

  test('补光灯设置失败时不显示为已开启', () async {
    camera.torchSupported = true;
    camera.failTorch = true;
    await controller.initialize();
    await controller.toggleTorch();
    expect(controller.torchEnabled.value, false);
    expect(camera.torchRequests, [true]);
  });

  test('点按对焦前摄镜像水平坐标', () async {
    await controller.initialize();
    await controller.tapFocus(const Offset(0.2, 0.4));
    expect(camera.focusPoints.last, const Offset(0.2, 0.4));
    await controller.switchCamera();
    await controller.tapFocus(const Offset(0.2, 0.4));
    expect(camera.focusPoints.last.dx, closeTo(0.8, 1e-9));
    expect(camera.focusPoints.last.dy, 0.4);
  });

  test('清除点按对焦恢复默认区域', () async {
    await controller.initialize();
    await controller.tapFocus(const Offset(0.5, 0.5));
    expect(controller.focusPoint.value, isNotNull);
    await controller.clearFocusPoint();
    expect(controller.focusPoint.value, isNull);
  });

  test('双指捏合按基准倍率缩放并限制在设备范围', () async {
    await controller.initialize();
    await controller.setZoom(2);
    controller.beginPinch();
    await controller.updatePinch(1.5);
    controller.endPinch();
    expect(camera.zooms.last, 3);
  });

  test('请求规格传给驱动，规格标签区分请求与已接受', () async {
    await controller.initialize();
    expect(camera.lastSettings?.quality, CaptureQuality.p1080);
    expect(camera.lastSettings?.fps, CaptureFps.fps30);
    expect(controller.specLabel.value, contains('请求 1080p / 30 FPS'));
    expect(controller.specLabel.value, contains('已接受 1080p / 30 FPS'));
  });

  test('预设快照包含当前规格、音频、变焦、曝光与补光', () async {
    camera.torchSupported = true;
    await controller.initialize();
    await controller.setZoom(2);
    await controller.applyExposureOffset(0.5);
    await controller.setTorch(true);
    final config = controller.capturePresetConfig();
    expect(config.quality, CaptureQuality.p1080);
    expect(config.fps, CaptureFps.fps30);
    expect(config.audioEnabled, true);
    expect(config.zoomRatio, 2);
    expect(config.exposureCompensationEv, 0.5);
    expect(config.torchEnabled, true);
  });

  test('完整应用预设后标记已选且未被修改', () async {
    await controller.initialize();
    final preset = CameraPreset(
      id: 'user:1',
      name: '室内',
      configVersion: presetConfigVersion,
      config: const PresetConfig(
        quality: CaptureQuality.p720,
        exposureCompensationEv: 0.5,
        zoomRatio: 2,
      ),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final report = await controller.applyPreset(preset);
    expect(report.fullyApplied, true);
    expect(camera.lastSettings?.quality, CaptureQuality.p720);
    expect(camera.exposureRequests.last, 0.5);
    expect(camera.zooms.last, 2);
    expect(controller.activePresetName.value, '室内');
    expect(controller.presetModified.value, false);
  });

  test('预设项不受支持时报告部分应用并标记已修改', () async {
    await controller.initialize();
    final preset = CameraPreset(
      id: 'user:2',
      name: '夜景',
      configVersion: presetConfigVersion,
      config: const PresetConfig(
        exposureCompensationEv: 0.5,
        torchEnabled: true,
        zoomRatio: 9,
      ),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final report = await controller.applyPreset(preset);
    expect(report.fullyApplied, false);
    expect(report.notes.join(), contains('补光灯'));
    expect(report.notes.join(), contains('变焦'));
    expect(controller.torchEnabled.value, false);
    expect(controller.zoomLevel.value, 5);
    expect(controller.activePresetName.value, '夜景');
    expect(controller.presetModified.value, true);
  });

  test('应用预设后手动改参标记为已修改', () async {
    await controller.initialize();
    await controller.applyPreset(
      CameraPreset(
        id: 'builtin:auto',
        name: '自动',
        configVersion: presetConfigVersion,
        config: const PresetConfig(),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    expect(controller.presetModified.value, false);
    await controller.setZoom(2);
    expect(controller.presetModified.value, true);
  });

  test('配置损坏的预设不应用且不改变会话', () async {
    await controller.initialize();
    final report = await controller.applyPreset(
      CameraPreset(
        id: 'user:bad',
        name: '损坏',
        configVersion: presetConfigVersion,
        issue: '预设配置不是有效 JSON',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    expect(report.fullyApplied, false);
    expect(report.notes.single, contains('不是有效 JSON'));
    expect(controller.activePresetName.value, isNull);
    expect(controller.state.value, CaptureState.ready);
  });

  test('应用新规格重建会话，相同请求不重复重建', () async {
    await controller.initialize();
    await controller.applyCaptureSettings(
      const RecordingSettings(
        quality: CaptureQuality.p720,
        fps: CaptureFps.auto,
      ),
    );
    expect(controller.requestedSettings.value.quality, CaptureQuality.p720);
    expect(controller.specLabel.value, contains('请求 720p / 自动帧率'));
    expect(controller.state.value, CaptureState.ready);
    final rebuilds = camera.initializedAudio.length;
    await controller.applyCaptureSettings(controller.requestedSettings.value);
    expect(camera.initializedAudio.length, rebuilds);
  });

  test('录制中应用新规格先停止保存再重建会话', () async {
    await controller.initialize();
    await controller.start();
    await controller.applyCaptureSettings(
      const RecordingSettings(quality: CaptureQuality.p480),
    );
    expect(camera.stops, 1);
    expect(recordings.commits, 1);
    expect(camera.lastSettings?.quality, CaptureQuality.p480);
    expect(controller.state.value, CaptureState.ready);
  });

  test('规格初始化失败时恢复上次可用配置并提示', () async {
    camera.rejectFps60 = true;
    await controller.initialize();
    await controller.applyCaptureSettings(
      const RecordingSettings(fps: CaptureFps.fps60),
    );
    expect(controller.requestedSettings.value.fps, CaptureFps.fps30);
    expect(controller.message.value, contains('已恢复上次可用配置'));
    expect(controller.state.value, CaptureState.ready);
  });

  test('码率请求传递给驱动，自定义超范围按未设置处理', () async {
    await controller.initialize();
    await controller.applyCaptureSettings(
      const RecordingSettings(bitrate: VideoBitratePreset.standard),
    );
    expect(camera.lastSettings?.videoBitrateBps, standardVideoBitrateBps);
    const invalid = RecordingSettings(
      bitrate: VideoBitratePreset.custom,
      customBitrateBps: 500000000,
    );
    expect(invalid.hasValidCustomBitrate, false);
    expect(invalid.videoBitrateBps, isNull);
  });

  test('防抖模式探测缓存于镜头，设置失败保持原模式', () async {
    await controller.initialize();
    expect(controller.stabilizationModes, [VideoStabilizationMode.off]);
    expect(
      await controller.setStabilization(VideoStabilizationMode.level1),
      false,
    );
    expect(controller.stabilizationMode.value, VideoStabilizationMode.off);
    camera.stabilizationSupported = true;
    await controller.toggleAudio();
    expect(
      controller.stabilizationModes,
      contains(VideoStabilizationMode.level1),
    );
    expect(
      await controller.setStabilization(VideoStabilizationMode.level1),
      true,
    );
    expect(controller.stabilizationMode.value, VideoStabilizationMode.level1);
    camera.failStabilization = true;
    expect(
      await controller.setStabilization(VideoStabilizationMode.off),
      false,
    );
    expect(controller.stabilizationMode.value, VideoStabilizationMode.level1);
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

  testWidgets('倍率快捷键按设备范围过滤，超范围候选不展示', (tester) async {
    createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.testMode = true;
    Get.put(controller);
    addTearDown(Get.reset);
    await tester.pumpWidget(const GetMaterialApp(home: CameraView()));
    await tester.pumpAndSettle();
    expect(find.text('1x'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('3x'), findsOneWidget);
    expect(find.text('5x'), findsOneWidget);
    expect(find.text('10x'), findsNothing);
    await tester.tap(find.text('2x'));
    await tester.pumpAndSettle();
    expect(camera.zooms.last, 2);
  });

  testWidgets('参数面板展示曝光补偿与补光，随镜头能力呈现', (tester) async {
    createController();
    camera.torchSupported = true;
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.testMode = true;
    Get.put(controller);
    addTearDown(Get.reset);
    await tester.pumpWidget(const GetMaterialApp(home: CameraView()));
    await tester.pumpAndSettle();
    await controller.applyExposureOffset(1.0);
    await tester.tap(find.byTooltip('拍摄参数'));
    await tester.pumpAndSettle();
    expect(find.text('拍摄参数'), findsOneWidget);
    expect(find.text('曝光补偿'), findsOneWidget);
    expect(find.text('+1.0 EV'), findsOneWidget);
    expect(find.text('补光灯'), findsOneWidget);
    await tester.tap(find.text('复位'));
    await tester.pumpAndSettle();
    expect(find.text('+0.0 EV'), findsOneWidget);
    await tester.tap(find.text('补光灯'));
    await tester.pumpAndSettle();
    expect(controller.torchEnabled.value, true);
  });

  testWidgets('录制规格面板展示请求值，切换 60 FPS 重建并更新标签', (tester) async {
    createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.testMode = true;
    Get.put(controller);
    addTearDown(Get.reset);
    await tester.pumpWidget(const GetMaterialApp(home: CameraView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('拍摄参数'));
    await tester.pumpAndSettle();
    expect(find.text('录制规格'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);
    expect(find.text('设备最高'), findsOneWidget);
    expect(find.text('码率为请求值，实际码率以成品文件为准'), findsOneWidget);
    expect(find.textContaining('已接受 1080p / 60 FPS'), findsNothing);
    await tester.tap(find.text('60 FPS'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('已接受 1080p / 60 FPS'), findsOneWidget);
  });

  testWidgets('自定义码率校验范围，合法值写入请求并传递驱动', (tester) async {
    createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.testMode = true;
    Get.put(controller);
    addTearDown(Get.reset);
    await tester.pumpWidget(const GetMaterialApp(home: CameraView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('拍摄参数'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义…'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('自定义码率'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '500');
    await tester.pumpAndSettle();
    expect(find.text('范围 1 – 100 Mbps'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12');
    await tester.pumpAndSettle();
    expect(find.text('范围 1 – 100 Mbps'), findsNothing);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(controller.requestedSettings.value.videoBitrateBps, 12000000);
    expect(camera.lastSettings?.videoBitrateBps, 12000000);
  });
}
