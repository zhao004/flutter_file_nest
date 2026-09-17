import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/models/camera_capture_settings.dart';
import 'package:flutter_lens_vault/app/models/camera_parameter_models.dart';
import 'package:flutter_lens_vault/app/models/camera_presets.dart';

const _backCaps = LensCapabilities(
  zoomMin: 1,
  zoomMax: 5,
  exposureOffsetMin: -2,
  exposureOffsetMax: 2,
  exposureOffsetStep: 0.5,
  exposurePointSupported: true,
  focusPointSupported: true,
  torchSupported: false,
);

void main() {
  test('预设配置 JSON 往返保持字段一致', () {
    const config = PresetConfig(
      quality: CaptureQuality.p720,
      fps: CaptureFps.fps60,
      videoBitrateBps: highVideoBitrateBps,
      audioEnabled: false,
      zoomRatio: 2.5,
      exposureCompensationEv: -1.5,
      torchEnabled: true,
    );
    final result = PresetConfig.decode(config.encode());
    expect(result.ok, true);
    expect(result.config, config);
  });

  test('损坏 JSON 与缺少版本号分别按损坏处理', () {
    expect(
      PresetConfig.decode('not json').failure,
      PresetDecodeFailure.corrupted,
    );
    expect(PresetConfig.decode('[1,2]').failure, PresetDecodeFailure.corrupted);
    expect(
      PresetConfig.decode('{"quality":"fhd"}').failure,
      PresetDecodeFailure.corrupted,
    );
  });

  test('未知的新版本拒绝解码并保留原配置', () {
    final result = PresetConfig.decode('{"configVersion":2,"quality":"fhd"}');
    expect(result.ok, false);
    expect(result.failure, PresetDecodeFailure.unsupportedVersion);
    expect(result.message, contains('更新版本'));
  });

  test('缺失与越界字段回落到明确定义的默认值', () {
    final result = PresetConfig.decode('{"configVersion":1}');
    expect(result.ok, true);
    expect(result.config?.quality, CaptureQuality.p1080);
    expect(result.config?.fps, CaptureFps.auto);
    expect(result.config?.videoBitrateBps, isNull);
    expect(result.config?.zoomRatio, 1.0);
    expect(result.config?.exposureCompensationEv, 0.0);
    expect(result.config?.torchEnabled, false);
    final sanitized = PresetConfig.decode(
      '{"configVersion":1,"quality":"unknown","fps":25,'
      '"videoBitrateBps":999,"zoomRatio":-3,"exposureCompensationEv":"x",'
      '"audioEnabled":"yes"}',
    );
    expect(sanitized.ok, true);
    expect(sanitized.config?.quality, CaptureQuality.p1080);
    expect(sanitized.config?.fps, CaptureFps.auto);
    expect(sanitized.config?.videoBitrateBps, isNull);
    expect(sanitized.config?.zoomRatio, 1.0);
    expect(sanitized.config?.exposureCompensationEv, 0.0);
    expect(sanitized.config?.audioEnabled, isNull);
  });

  test('码率字段映射到录制规格的对应档位', () {
    expect(
      const PresetConfig().toRecordingSettings().bitrate,
      VideoBitratePreset.auto,
    );
    expect(
      const PresetConfig(
        videoBitrateBps: standardVideoBitrateBps,
      ).toRecordingSettings().bitrate,
      VideoBitratePreset.standard,
    );
    final custom = const PresetConfig(
      videoBitrateBps: 12345678,
    ).toRecordingSettings();
    expect(custom.bitrate, VideoBitratePreset.custom);
    expect(custom.customBitrateBps, 12345678);
  });

  test('预设名称拒绝空白、过长与控制字符', () {
    expect(validatePresetName(''), isNotNull);
    expect(validatePresetName('   '), isNotNull);
    expect(validatePresetName('a' * 31), isNotNull);
    expect(validatePresetName('夜间\u0001'), isNotNull);
    expect(validatePresetName('日常'), isNull);
  });

  test('校验按镜头能力收敛变焦与曝光并跳过补光', () {
    final validation = validatePresetConfig(
      const PresetConfig(
        zoomRatio: 12,
        exposureCompensationEv: 5,
        torchEnabled: true,
      ),
      _backCaps,
    );
    expect(validation.hasAdjustments, true);
    expect(validation.adjusted.zoomRatio, 5);
    expect(validation.adjusted.exposureCompensationEv, 2);
    expect(validation.adjusted.torchEnabled, false);
    expect(validation.adjustments, hasLength(3));
  });

  test('缺少能力信息时跳过曝光与补光，不改动其他字段', () {
    final validation = validatePresetConfig(
      const PresetConfig(exposureCompensationEv: 0.5, torchEnabled: true),
      null,
    );
    expect(validation.adjusted.exposureCompensationEv, 0);
    expect(validation.adjusted.torchEnabled, false);
    expect(
      validation.adjustments.map((item) => item.field),
      containsAll(['exposure', 'torch']),
    );
  });

  test('能力范围内不做任何调整', () {
    final validation = validatePresetConfig(
      const PresetConfig(
        zoomRatio: 2,
        exposureCompensationEv: 1,
        torchEnabled: false,
      ),
      _backCaps,
    );
    expect(validation.hasAdjustments, false);
    expect(validation.adjusted, validation.requested);
  });

  test('内置预设 ID 唯一且都可应用', () {
    final ids = builtInPresets.map((preset) => preset.id).toSet();
    expect(ids, hasLength(builtInPresets.length));
    expect(builtInPresets, hasLength(5));
    for (final preset in builtInPresets) {
      expect(preset.builtIn, true);
      expect(preset.usable, true);
    }
  });

  test('应用报告区分完整与部分应用', () {
    final full = PresetApplyReport('日常');
    expect(full.fullyApplied, true);
    expect(full.summary, '已应用预设：日常');
    final partial = PresetApplyReport('夜景')..note('补光不受支持');
    expect(partial.fullyApplied, false);
    expect(partial.summary, contains('部分'));
  });
}
