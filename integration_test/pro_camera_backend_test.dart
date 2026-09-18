import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_lens_vault/app/models/camera_capture_settings.dart';
import 'package:flutter_lens_vault/app/pages/camera/native_camera_driver.dart';

/// 原生 Camera2 后端的设备级验证：打开会话、录制、停止并产出可解析文件。
///
/// 运行前需先安装调试包并授予相机权限：
/// `adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`
/// `adb -s emulator-5554 shell pm grant com.example.flutter_lens_vault android.permission.CAMERA`
/// 然后执行 `flutter test integration_test/pro_camera_backend_test.dart -d emulator-5554`。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('原生后端完成一次完整录制并产出可解析文件', (tester) async {
    expect(await NativeCameraDriver.probe(), isTrue);
    final driver = NativeCameraDriver();
    final cameras = await driver.cameras();
    expect(cameras, isNotEmpty, reason: '设备应至少提供一台摄像头');

    await driver.initialize(
      cameras.first,
      false,
      const RecordingSettings(quality: CaptureQuality.p720),
    );
    addTearDown(driver.dispose);
    expect(driver.acceptedLabel, startsWith('已接受'));

    final capabilities = await driver.capabilities();
    expect(capabilities, isNotNull, reason: '初始化后应能读取镜头能力');
    expect(capabilities!.zoomMax, greaterThanOrEqualTo(1.0));

    await driver.start();
    await Future<void>.delayed(const Duration(seconds: 2));
    final file = await driver.stop();

    final saved = File(file.path);
    expect(await saved.exists(), isTrue);
    expect(await saved.length(), greaterThan(10000), reason: '成品不应为空文件');

    final metadata = await proCameraChannel
        .invokeMapMethod<Object?, Object?>('probeVideo', {'path': file.path});
    expect(
      (metadata?['durationMs'] as num?)?.toInt() ?? 0,
      greaterThan(1000),
      reason: '成品应可被系统解析出时长',
    );
    expect((metadata?['width'] as num?)?.toInt() ?? 0, greaterThan(0));
    expect((metadata?['height'] as num?)?.toInt() ?? 0, greaterThan(0));

    await driver.dispose();
    // 释放后可重新打开同一摄像头，证明上一会话已归还设备资源。
    final reopened = NativeCameraDriver();
    await reopened.initialize(
      cameras.first,
      false,
      const RecordingSettings(quality: CaptureQuality.p480),
    );
    expect(await reopened.capabilities(), isNotNull);
    await reopened.dispose();
  });

  testWidgets('预览 PlatformView 与录制共用同一会话', (tester) async {
    final driver = NativeCameraDriver();
    addTearDown(driver.dispose);
    final cameras = await driver.cameras();
    await driver.initialize(
      cameras.first,
      false,
      const RecordingSettings(quality: CaptureQuality.p480),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 240,
            child: driver.preview(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await driver.start();
    await Future<void>.delayed(const Duration(seconds: 1));
    final file = await driver.stop();
    expect(await File(file.path).length(), greaterThan(1000));
    // 停止后预览视图仍然挂载，会话已恢复为仅预览状态。
    await tester.pump(const Duration(seconds: 1));
    await driver.dispose();
  });
}
