import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_lens_vault/app/models/camera_presets.dart';
import 'package:flutter_lens_vault/app/pages/camera/app_camera_controller.dart';
import 'package:flutter_lens_vault/app/pages/presets/presets_controller.dart';
import 'package:flutter_lens_vault/app/pages/presets/presets_view.dart';
import 'support/fakes.dart';
import 'support/camera_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCamera camera;
  late MemoryStore store;
  late FakeRecordings recordings;
  late AppCameraController cam;
  late PresetsController presets;

  void create() {
    camera = FakeCamera();
    store = MemoryStore();
    recordings = FakeRecordings(FakeStorage(), store);
    cam = AppCameraController(
      folder: root,
      driver: camera,
      recordings: recordings,
      audio: true,
      saveAudio: (value) =>
          store.savePreferences(store.value.copyWith(audioEnabled: value)),
    );
    presets = PresetsController(camera: cam, store: store);
  }

  CameraPreset userPreset({
    String id = 'user:1',
    String name = '我的预设',
    PresetConfig config = const PresetConfig(),
    DateTime? updatedAt,
  }) => CameraPreset(
    id: id,
    name: name,
    configVersion: presetConfigVersion,
    config: config,
    createdAt: DateTime.utc(2026),
    updatedAt: updatedAt ?? DateTime.utc(2026),
  );

  setUp(create);
  tearDown(() {
    cam.onClose();
  });

  test('载入区分内置预设与用户预设', () async {
    store.presets.add(userPreset());
    await presets.load();
    expect(presets.builtIns, hasLength(5));
    expect(presets.userPresets.single.name, '我的预设');
  });

  test('保存当前配置为新预设并标记已选', () async {
    await cam.initialize();
    await cam.setZoom(2);
    final created = await presets.createFromCurrent('夜间手持');
    expect(created, true);
    expect(store.presets.single.name, '夜间手持');
    expect(store.presets.single.config?.zoomRatio, 2);
    expect(cam.activePresetName.value, '夜间手持');
    expect(cam.presetModified.value, false);
    expect(presets.userPresets, hasLength(1));
  });

  test('重命名保留配置，覆盖更新配置', () async {
    await cam.initialize();
    store.presets.add(userPreset(config: const PresetConfig(zoomRatio: 3)));
    await presets.load();
    final target = presets.userPresets.single;
    await presets.rename(target, '新的名字');
    var stored = store.presets.single;
    expect(stored.name, '新的名字');
    expect(stored.config?.zoomRatio, 3);
    expect(cam.activePresetName.value, isNull);
    await cam.setZoom(4);
    await presets.overwriteFromCurrent(presets.userPresets.single);
    stored = store.presets.single;
    expect(stored.config?.zoomRatio, 4);
    expect(cam.activePresetName.value, '新的名字');
  });

  test('删除不影响其他预设并清除已选状态', () async {
    store.presets.addAll([
      userPreset(id: 'user:1', name: '甲'),
      userPreset(id: 'user:2', name: '乙'),
    ]);
    await presets.load();
    cam.markPresetApplied('甲');
    await presets.delete(presets.userPresets.singleWhere((p) => p.name == '甲'));
    expect(store.presets.single.name, '乙');
    expect(cam.activePresetName.value, isNull);
    expect(presets.userPresets.single.name, '乙');
  });

  test('名称为空或过长时拒绝保存', () async {
    expect(await presets.createFromCurrent('   '), false);
    expect(presets.error.value, isNotNull);
    expect(await presets.createFromCurrent('a' * 31), false);
    expect(store.presets, isEmpty);
  });

  test('应用前校验暴露不支持项', () async {
    await cam.initialize();
    store.presets.add(
      userPreset(config: const PresetConfig(torchEnabled: true, zoomRatio: 9)),
    );
    await presets.load();
    final validation = presets.validate(presets.userPresets.single);
    expect(validation.hasAdjustments, true);
    expect(validation.adjustments, hasLength(2));
  });

  test('录制中应用预设先停止保存并重新打开会话', () async {
    await cam.initialize();
    await cam.start();
    store.presets.add(userPreset(name: '自动', config: const PresetConfig()));
    await presets.load();
    final report = await presets.apply(presets.userPresets.single);
    expect(report.fullyApplied, true);
    expect(camera.stops, 1);
    expect(recordings.commits, 1);
    expect(cam.state.value, CaptureState.ready);
    expect(cam.activePresetName.value, '自动');
    expect(store.jobs, isEmpty);
  });

  testWidgets('预设页展示内置预设并保存当前配置', (tester) async {
    // 在测试体内创建控制器，避免 setUp 的真实 zone 与 fake async zone 混用。
    create();
    await cam.initialize();
    Get.testMode = true;
    Get.put(presets);
    addTearDown(Get.reset);
    await tester.pumpWidget(const GetMaterialApp(home: PresetsView()));
    await tester.pumpAndSettle();
    expect(find.text('内置预设'), findsOneWidget);
    expect(find.text('我的预设'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);
    expect(find.text('运动'), findsOneWidget);
    await tester.tap(find.text('保存当前配置'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '我的日常');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.presets.single.name, '我的日常');
    expect(find.text('我的日常'), findsOneWidget);
  });

  testWidgets('应用含不支持项的预设先确认调整再报告部分应用', (tester) async {
    create();
    await cam.initialize();
    store.presets.add(
      userPreset(
        name: '带补光',
        config: const PresetConfig(torchEnabled: true, zoomRatio: 9),
      ),
    );
    await presets.load();
    Get.testMode = true;
    Get.put(presets);
    addTearDown(Get.reset);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GetMaterialApp(home: PresetsView()));
    await tester.pumpAndSettle();
    final applyButton = find.descendant(
      of: find.widgetWithText(ListTile, '带补光'),
      matching: find.text('应用'),
    );
    await tester.ensureVisible(applyButton);
    await tester.pumpAndSettle();
    await tester.tap(applyButton);
    await tester.pumpAndSettle();
    expect(find.text('按设备能力调整后应用？'), findsOneWidget);
    await tester.tap(find.text('调整并应用'));
    await tester.pumpAndSettle();
    expect(find.textContaining('部分'), findsOneWidget);
    expect(cam.activePresetName.value, '带补光');
    expect(cam.presetModified.value, true);
    expect(cam.zoomLevel.value, 5);
  });

  testWidgets('录制中应用预设先确认停止保存', (tester) async {
    create();
    await cam.initialize();
    await cam.start();
    await presets.load();
    Get.testMode = true;
    Get.put(presets);
    addTearDown(Get.reset);
    await tester.pumpWidget(const GetMaterialApp(home: PresetsView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用').first);
    await tester.pumpAndSettle();
    expect(find.text('应用预设前停止录像？'), findsOneWidget);
    await tester.tap(find.text('停止并应用'));
    await tester.pumpAndSettle();
    expect(camera.stops, 1);
    expect(recordings.commits, 1);
    expect(cam.activePresetName.value, '自动');
    expect(cam.state.value, CaptureState.ready);
  });
}
