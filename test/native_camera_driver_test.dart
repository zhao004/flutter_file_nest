import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/models/camera_capture_settings.dart';
import 'package:flutter_lens_vault/app/models/camera_parameter_models.dart';
import 'package:flutter_lens_vault/app/pages/camera/native_camera_driver.dart';

/// 专业相机驱动的平台协议测试：只覆盖 Dart 侧映射与错误转换，
/// 原生会话行为由集成测试在设备/模拟器上验证。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;
  late Object? Function(MethodCall call) handler;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(proCameraChannel, (call) async {
          calls.add(call);
          return handler(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(proCameraChannel, null);
  });

  test('解析相机列表为 CameraDescription', () async {
    handler = (call) => switch (call.method) {
      'cameras' => <Object?>[
        <Object?, Object?>{
          'id': '0',
          'facing': 'back',
          'sensorOrientation': 90,
        },
        <Object?, Object?>{
          'id': '1',
          'facing': 'front',
          'sensorOrientation': 270,
        },
      ],
      _ => null,
    };
    final driver = NativeCameraDriver();
    final cameras = await driver.cameras();
    expect(cameras, hasLength(2));
    expect(cameras.first.name, '0');
    expect(cameras.first.lensDirection, CameraLensDirection.back);
    expect(cameras.first.sensorOrientation, 90);
    expect(cameras.last.lensDirection, CameraLensDirection.front);
  });

  test('初始化传递请求规格并记录设备已接受配置', () async {
    Map<Object?, Object?>? initializeArgs;
    handler = (call) => switch (call.method) {
      'ensurePermissions' => {'camera': true, 'audio': false},
      'initialize' => {
        'quality': '720p',
        'fps': null,
        'width': 1280,
        'height': 720,
      },
      'zoomRange' => {'min': 1.0, 'max': 8.0},
      _ => null,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(proCameraChannel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') {
            initializeArgs = call.arguments as Map<Object?, Object?>;
          }
          return handler(call);
        });
    final driver = NativeCameraDriver();
    await driver.initialize(
      const CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      false,
      const RecordingSettings(quality: CaptureQuality.p1080),
    );
    expect(initializeArgs?['quality'], '1080p');
    expect(initializeArgs?['fps'], 30);
    expect(initializeArgs?['cameraId'], '0');
    expect(driver.requestedLabel, contains('1080p'));
    expect(driver.acceptedLabel, '已接受 720p / 自动帧率');
    expect(await driver.maxZoom(), 8.0);
  });

  test('相机权限拒绝抛出 CameraAccess 错误', () async {
    handler = (call) => switch (call.method) {
      'ensurePermissions' => {'camera': false, 'audio': false},
      _ => null,
    };
    final driver = NativeCameraDriver();
    await expectLater(
      driver.initialize(
        const CameraDescription(
          name: '0',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        false,
        const RecordingSettings(),
      ),
      throwsA(
        isA<CameraException>().having(
          (error) => error.code,
          'code',
          startsWith('CameraAccess'),
        ),
      ),
    );
  });

  test('音频权限拒绝抛出 AudioAccess 错误且不申请静音权限', () async {
    final permissionArgs = <Object?>[];
    handler = (call) => switch (call.method) {
      'ensurePermissions' => {'camera': true, 'audio': false},
      _ => null,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(proCameraChannel, (call) async {
          calls.add(call);
          if (call.method == 'ensurePermissions') {
            permissionArgs.add(call.arguments);
          }
          return handler(call);
        });
    final driver = NativeCameraDriver();
    await expectLater(
      driver.initialize(
        const CameraDescription(
          name: '0',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        true,
        const RecordingSettings(),
      ),
      throwsA(
        isA<CameraException>().having(
          (error) => error.code,
          'code',
          startsWith('AudioAccess'),
        ),
      ),
    );
    expect((permissionArgs.single as Map<Object?, Object?>)['audio'], true);
  });

  test('能力探测映射为 LensCapabilities，失败返回 null', () async {
    handler = (call) => switch (call.method) {
      'ensurePermissions' => {'camera': true, 'audio': false},
      'initialize' => {'quality': '1080p', 'fps': 30},
      'zoomRange' => {'min': 1.0, 'max': 6.0},
      'capabilities' => {
        'zoomMin': 1.0,
        'zoomMax': 6.0,
        'exposureOffsetMin': -2.0,
        'exposureOffsetMax': 2.0,
        'exposureOffsetStep': 0.5,
        'exposurePointSupported': true,
        'focusPointSupported': false,
        'torchSupported': true,
      },
      _ => null,
    };
    final driver = NativeCameraDriver();
    expect(await driver.capabilities(), isNull);
    await driver.initialize(
      const CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      false,
      const RecordingSettings(),
    );
    final caps = await driver.capabilities();
    expect(caps?.zoomMax, 6.0);
    expect(caps?.exposureOffsetStep, 0.5);
    expect(caps?.hasExposureOffset, true);
    expect(caps?.focusPointSupported, false);
    expect(caps?.torchSupported, true);
  });

  test('参数失败转换为结构化原因', () async {
    handler = (call) => switch (call.method) {
      'ensurePermissions' => {'camera': true, 'audio': false},
      'initialize' => {'quality': '1080p', 'fps': 30},
      'zoomRange' => {'min': 1.0, 'max': 1.0},
      'setExposureOffset' => throw PlatformException(code: 'unsupported'),
      'setTorch' => throw PlatformException(code: 'session_closed'),
      _ => null,
    };
    final driver = NativeCameraDriver();
    await driver.initialize(
      const CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      false,
      const RecordingSettings(),
    );
    final exposure = await driver.setExposureOffset(1);
    expect(exposure.ok, false);
    expect(exposure.failure, ParameterApplyFailure.unsupported);
    final torch = await driver.setTorch(true);
    expect(torch.failure, ParameterApplyFailure.sessionClosed);
  });

  test('停止返回文件路径，缺失路径时抛出错误', () async {
    var stopResults = <Object?>[];
    handler = (call) => switch (call.method) {
      'ensurePermissions' => {'camera': true, 'audio': false},
      'initialize' => {'quality': '1080p', 'fps': 30},
      'zoomRange' => {'min': 1.0, 'max': 1.0},
      'stop' => () {
        final result = stopResults.removeAt(0);
        if (result is Exception) throw result;
        return result;
      }(),
      _ => null,
    };
    final driver = NativeCameraDriver();
    await driver.initialize(
      const CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      false,
      const RecordingSettings(),
    );
    stopResults = [
      {'path': 'cache/pro_camera/rec_1.mp4'},
    ];
    final file = await driver.stop();
    expect(file.path, 'cache/pro_camera/rec_1.mp4');
    stopResults = [PlatformException(code: 'recording_stop_failed')];
    await expectLater(
      driver.stop(),
      throwsA(
        isA<CameraException>().having(
          (error) => error.code,
          'code',
          'recording_stop_failed',
        ),
      ),
    );
  });

  test('防抖模式映射为 level1 与 off', () async {
    handler = (call) => switch (call.method) {
      'ensurePermissions' => {'camera': true, 'audio': false},
      'initialize' => {'quality': '1080p', 'fps': 30},
      'zoomRange' => {'min': 1.0, 'max': 1.0},
      'stabilizationModes' => <Object?>['off', 'on'],
      'setStabilization' => {'mode': 'on'},
      _ => null,
    };
    final driver = NativeCameraDriver();
    await driver.initialize(
      const CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      false,
      const RecordingSettings(),
    );
    final modes = await driver.supportedStabilizationModes();
    expect(modes, [VideoStabilizationMode.off, VideoStabilizationMode.level1]);
    expect(
      await driver.setStabilizationMode(VideoStabilizationMode.level1),
      VideoStabilizationMode.level1,
    );
  });
}
