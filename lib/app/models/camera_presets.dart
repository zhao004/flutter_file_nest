/// 拍摄预设模型：版本化 JSON 配置契约、设备能力校验与内置预设。
///
/// 预设只保存拍摄参数，不保存视频目标目录、授权 URI 或摄像头 ID；应用预设
/// 不改变当前文件夹。配置版本（[presetConfigVersion]）与 Drift schemaVersion
/// 是不同概念，分别维护迁移逻辑。
library;

import 'dart:convert';

import 'camera_capture_settings.dart';
import 'camera_parameter_models.dart';

/// 预设配置契约版本；Phase 2B 手动参数落地时递增并增加迁移。
///
/// v1 覆盖 Phase 2A 参数（分辨率、帧率、码率、音频、变焦、曝光补偿、补光），
/// 手动 ISO / 快门 / 白平衡 / 对焦距离字段留待后续版本。
const int presetConfigVersion = 1;

/// 内置预设 ID 前缀；内置模板在代码中维护，不写入用户预设表。
const String builtInPresetIdPrefix = 'builtin:';

/// 配置解析失败原因；两类失败都不允许应用，但保留原数据。
enum PresetDecodeFailure {
  /// JSON 损坏或结构非法。
  corrupted,

  /// 版本高于当前应用支持的版本，拒绝应用并保留原配置。
  unsupportedVersion,
}

/// 配置解码结果。
class PresetDecodeResult {
  const PresetDecodeResult.success(PresetConfig this.config)
    : failure = null,
      message = null;

  const PresetDecodeResult.failure(this.failure, this.message) : config = null;

  final PresetConfig? config;
  final PresetDecodeFailure? failure;
  final String? message;

  bool get ok => config != null;
}

/// 单个预设的拍摄参数配置（契约 v1）。
///
/// 无法解析的字段按明确定义的默认值处理；数值越界在应用前由
/// [validatePresetConfig] 校验并在界面提示，不静默改变语义。
class PresetConfig {
  const PresetConfig({
    this.quality = CaptureQuality.p1080,
    this.fps = CaptureFps.fps30,
    this.videoBitrateBps,
    this.audioEnabled,
    this.zoomRatio = 1.0,
    this.exposureCompensationEv = 0.0,
    this.torchEnabled = false,
  });

  /// 分辨率请求。
  final CaptureQuality quality;

  /// 帧率请求。
  final CaptureFps fps;

  /// 视频码率请求（bps）；null 表示自动。
  final int? videoBitrateBps;

  /// 音频开关；null 表示不改变当前音频偏好（内置预设使用）。
  final bool? audioEnabled;

  /// 变焦倍率请求。
  final double zoomRatio;

  /// 曝光补偿请求（EV）。
  final double exposureCompensationEv;

  /// 补光灯请求。
  final bool torchEnabled;

  PresetConfig copyWith({
    CaptureQuality? quality,
    CaptureFps? fps,
    int? videoBitrateBps,
    bool clearVideoBitrate = false,
    bool? audioEnabled,
    bool clearAudio = false,
    double? zoomRatio,
    double? exposureCompensationEv,
    bool? torchEnabled,
  }) => PresetConfig(
    quality: quality ?? this.quality,
    fps: fps ?? this.fps,
    videoBitrateBps: clearVideoBitrate
        ? null
        : (videoBitrateBps ?? this.videoBitrateBps),
    audioEnabled: clearAudio ? null : (audioEnabled ?? this.audioEnabled),
    zoomRatio: zoomRatio ?? this.zoomRatio,
    exposureCompensationEv:
        exposureCompensationEv ?? this.exposureCompensationEv,
    torchEnabled: torchEnabled ?? this.torchEnabled,
  );

  /// 映射为会话重建所需的录制规格请求。
  RecordingSettings toRecordingSettings() {
    final bps = videoBitrateBps;
    if (bps == null) {
      return RecordingSettings(quality: quality, fps: fps);
    }
    return switch (bps) {
      lowVideoBitrateBps => RecordingSettings(
        quality: quality,
        fps: fps,
        bitrate: VideoBitratePreset.low,
      ),
      standardVideoBitrateBps => RecordingSettings(
        quality: quality,
        fps: fps,
        bitrate: VideoBitratePreset.standard,
      ),
      highVideoBitrateBps => RecordingSettings(
        quality: quality,
        fps: fps,
        bitrate: VideoBitratePreset.high,
      ),
      _ => RecordingSettings(
        quality: quality,
        fps: fps,
        bitrate: VideoBitratePreset.custom,
        customBitrateBps: bps,
      ),
    };
  }

  /// 配置摘要文案，用于预设列表。
  String get summary {
    final bitrate = switch (videoBitrateBps) {
      null => '自动码率',
      lowVideoBitrateBps => '低码率',
      standardVideoBitrateBps => '标准码率',
      highVideoBitrateBps => '高码率',
      _ => '${videoBitrateBps! ~/ 1000000} Mbps',
    };
    final exposure = exposureCompensationEv == 0
        ? 'EV 0'
        : 'EV ${exposureCompensationEv > 0 ? '+' : ''}'
              '${exposureCompensationEv.toStringAsFixed(1)}';
    final buffer = StringBuffer()
      ..write('${_qualityNames[quality]} / ${_fpsNames[fps]}')
      ..write(' · $bitrate')
      ..write(' · $exposure')
      ..write(' · ${zoomRatio.toStringAsFixed(1)}x');
    if (torchEnabled) {
      buffer.write(' · 补光');
    }
    if (audioEnabled == false) {
      buffer.write(' · 静音');
    }
    return buffer.toString();
  }

  Map<String, Object?> toJson() => {
    'configVersion': presetConfigVersion,
    'captureMode': 'video',
    'quality': _qualityNames[quality],
    'fps': switch (fps) {
      CaptureFps.auto => null,
      CaptureFps.fps30 => 30,
      CaptureFps.fps60 => 60,
    },
    'videoBitrateBps': videoBitrateBps,
    'audioEnabled': audioEnabled,
    'zoomRatio': zoomRatio,
    'exposureCompensationEv': exposureCompensationEv,
    'torchEnabled': torchEnabled,
  };

  /// 序列化为版本化 JSON。
  String encode() => jsonEncode(toJson());

  /// 解析版本化 JSON；损坏与未知版本分别返回结构化失败。
  static PresetDecodeResult decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      return const PresetDecodeResult.failure(
        PresetDecodeFailure.corrupted,
        '预设配置不是有效 JSON',
      );
    }
    if (decoded is! Map) {
      return const PresetDecodeResult.failure(
        PresetDecodeFailure.corrupted,
        '预设配置结构非法',
      );
    }
    final version = decoded['configVersion'];
    if (version is! int) {
      return const PresetDecodeResult.failure(
        PresetDecodeFailure.corrupted,
        '预设配置缺少版本号',
      );
    }
    if (version != presetConfigVersion) {
      return PresetDecodeResult.failure(
        version > presetConfigVersion
            ? PresetDecodeFailure.unsupportedVersion
            : PresetDecodeFailure.corrupted,
        version > presetConfigVersion ? '预设由更新版本创建，请升级应用后再应用' : '预设配置版本无法识别',
      );
    }
    return PresetDecodeResult.success(_fromMap(decoded));
  }

  /// 容错解析：缺失或非法字段回落到明确定义的默认值。
  static PresetConfig _fromMap(Map<Object?, Object?> map) {
    final quality = switch (map['quality']) {
      '480p' || 'sd' => CaptureQuality.p480,
      '720p' || 'hd' => CaptureQuality.p720,
      '1080p' || 'fhd' => CaptureQuality.p1080,
      'max' => CaptureQuality.max,
      _ => CaptureQuality.p1080,
    };
    final fps = switch (map['fps']) {
      30 => CaptureFps.fps30,
      60 => CaptureFps.fps60,
      _ => CaptureFps.auto,
    };
    final rawBitrate = map['videoBitrateBps'];
    final bitrate =
        rawBitrate is int &&
            rawBitrate >= minCustomBitrateBps &&
            rawBitrate <= maxCustomBitrateBps
        ? rawBitrate
        : null;
    final audio = map['audioEnabled'];
    final rawZoom = map['zoomRatio'];
    final zoom = rawZoom is num && rawZoom.isFinite && rawZoom > 0
        ? rawZoom.toDouble()
        : 1.0;
    final rawExposure = map['exposureCompensationEv'];
    final exposure = rawExposure is num && rawExposure.isFinite
        ? rawExposure.toDouble()
        : 0.0;
    return PresetConfig(
      quality: quality,
      fps: fps,
      videoBitrateBps: bitrate,
      audioEnabled: audio is bool ? audio : null,
      zoomRatio: zoom,
      exposureCompensationEv: exposure,
      torchEnabled: map['torchEnabled'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PresetConfig &&
      quality == other.quality &&
      fps == other.fps &&
      videoBitrateBps == other.videoBitrateBps &&
      audioEnabled == other.audioEnabled &&
      zoomRatio == other.zoomRatio &&
      exposureCompensationEv == other.exposureCompensationEv &&
      torchEnabled == other.torchEnabled;

  @override
  int get hashCode => Object.hash(
    quality,
    fps,
    videoBitrateBps,
    audioEnabled,
    zoomRatio,
    exposureCompensationEv,
    torchEnabled,
  );
}

const _qualityNames = {
  CaptureQuality.p480: '480p',
  CaptureQuality.p720: '720p',
  CaptureQuality.p1080: '1080p',
  CaptureQuality.max: '设备最高',
};

const _fpsNames = {
  CaptureFps.auto: '自动帧率',
  CaptureFps.fps30: '30 FPS',
  CaptureFps.fps60: '60 FPS',
};

/// 用户预设或内置预设；config 为 null 表示配置损坏、不可应用。
class CameraPreset {
  const CameraPreset({
    required this.id,
    required this.name,
    required this.configVersion,
    required this.createdAt,
    required this.updatedAt,
    this.config,
    this.issue,
  });

  final String id;
  final String name;
  final int configVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 解析后的配置；损坏或版本不支持时为 null。
  final PresetConfig? config;

  /// 配置不可用时的说明文案。
  final String? issue;

  bool get builtIn => id.startsWith(builtInPresetIdPrefix);
  bool get usable => config != null;

  CameraPreset copyWith({
    String? name,
    PresetConfig? config,
    int? configVersion,
    DateTime? updatedAt,
    String? issue,
    bool clearIssue = false,
  }) => CameraPreset(
    id: id,
    name: name ?? this.name,
    config: config ?? this.config,
    configVersion: configVersion ?? this.configVersion,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    issue: clearIssue ? null : (issue ?? this.issue),
  );
}

/// 预设名称校验；返回错误文案，合法返回 null。
String? validatePresetName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '请输入预设名称';
  }
  if (trimmed.runes.length > 30) {
    return '预设名称不能超过 30 个字符';
  }
  for (final rune in trimmed.runes) {
    if (rune < 0x20 || rune == 0x7f) {
      return '预设名称不能包含控制字符';
    }
  }
  return null;
}

/// 单个校验调整项。
class PresetAdjustment {
  const PresetAdjustment(this.field, this.message);

  final String field;
  final String message;
}

/// 预设应用前校验结果：调整后的配置与逐项说明。
class PresetValidation {
  const PresetValidation({
    required this.requested,
    required this.adjusted,
    required this.adjustments,
  });

  final PresetConfig requested;
  final PresetConfig adjusted;
  final List<PresetAdjustment> adjustments;

  bool get hasAdjustments => adjustments.isNotEmpty;
}

/// 按当前镜头能力校验预设；不支持的项记录说明并给出建议降级值。
///
/// 只做"建议调整"：是否按调整后的配置应用由用户确认，不静默改变语义。
PresetValidation validatePresetConfig(
  PresetConfig config,
  LensCapabilities? capabilities,
) {
  var adjusted = config;
  final adjustments = <PresetAdjustment>[];
  final zoomMin = capabilities?.zoomMin ?? 1.0;
  final zoomMax = capabilities?.zoomMax ?? 1.0;
  if (config.zoomRatio < zoomMin - 1e-6 || config.zoomRatio > zoomMax + 1e-6) {
    final clamped = config.zoomRatio.clamp(zoomMin, zoomMax).toDouble();
    adjustments.add(
      PresetAdjustment(
        'zoomRatio',
        '变焦 ${config.zoomRatio.toStringAsFixed(1)}x 超出当前镜头范围，'
            '将调整为 ${clamped.toStringAsFixed(1)}x',
      ),
    );
    adjusted = adjusted.copyWith(zoomRatio: clamped);
  }
  if (config.exposureCompensationEv != 0) {
    if (capabilities == null || !capabilities.hasExposureOffset) {
      adjustments.add(const PresetAdjustment('exposure', '当前镜头不支持曝光补偿，将跳过该设置'));
      adjusted = adjusted.copyWith(exposureCompensationEv: 0);
    } else if (config.exposureCompensationEv <
            capabilities.exposureOffsetMin - 1e-6 ||
        config.exposureCompensationEv > capabilities.exposureOffsetMax + 1e-6) {
      final clamped = config.exposureCompensationEv
          .clamp(capabilities.exposureOffsetMin, capabilities.exposureOffsetMax)
          .toDouble();
      adjustments.add(
        PresetAdjustment(
          'exposure',
          '曝光补偿 ${config.exposureCompensationEv.toStringAsFixed(1)} EV '
              '超出设备范围，将调整为 ${clamped.toStringAsFixed(1)} EV',
        ),
      );
      adjusted = adjusted.copyWith(exposureCompensationEv: clamped);
    }
  }
  if (config.torchEnabled && !(capabilities?.torchSupported ?? false)) {
    adjustments.add(const PresetAdjustment('torch', '当前镜头没有可用补光灯，将跳过补光'));
    adjusted = adjusted.copyWith(torchEnabled: false);
  }
  return PresetValidation(
    requested: config,
    adjusted: adjusted,
    adjustments: adjustments,
  );
}

/// 预设应用报告：逐项结果，部分应用不得报告为完整成功。
class PresetApplyReport {
  PresetApplyReport(this.presetName);

  final String presetName;
  final List<String> notes = [];

  bool get fullyApplied => notes.isEmpty;

  void note(String message) => notes.add(message);

  /// 供界面展示的结果文案。
  String get summary =>
      fullyApplied ? '已应用预设：$presetName' : '已应用预设（部分）：${notes.join('；')}';
}

/// 内置预设示例；数值为保守起点，应用前按本机能力校验，真机效果待验收。
///
/// 内置模板不写入用户预设表，升级内置模板不覆盖用户已保存的配置。
final List<CameraPreset> builtInPresets = List.unmodifiable([
  CameraPreset(
    id: '${builtInPresetIdPrefix}auto',
    name: '自动',
    configVersion: presetConfigVersion,
    config: const PresetConfig(),
    createdAt: _builtInTimestamp,
    updatedAt: _builtInTimestamp,
  ),
  // 日常记录：1080p/30，标准码率，保持默认曝光。
  CameraPreset(
    id: '${builtInPresetIdPrefix}daily',
    name: '日常',
    configVersion: presetConfigVersion,
    config: const PresetConfig(
      videoBitrateBps: standardVideoBitrateBps,
      audioEnabled: true,
    ),
    createdAt: _builtInTimestamp,
    updatedAt: _builtInTimestamp,
  ),
  // 室内：适度提亮曝光补偿，弥补室内光线下偏暗的画面。
  CameraPreset(
    id: '${builtInPresetIdPrefix}indoor',
    name: '室内',
    configVersion: presetConfigVersion,
    config: const PresetConfig(exposureCompensationEv: 0.5, audioEnabled: true),
    createdAt: _builtInTimestamp,
    updatedAt: _builtInTimestamp,
  ),
  // 运动：720p/60 提高流畅度、减少快速移动拖影（60 FPS 需真机验证）。
  CameraPreset(
    id: '${builtInPresetIdPrefix}sport',
    name: '运动',
    configVersion: presetConfigVersion,
    config: const PresetConfig(
      quality: CaptureQuality.p720,
      fps: CaptureFps.fps60,
      videoBitrateBps: highVideoBitrateBps,
      audioEnabled: true,
    ),
    createdAt: _builtInTimestamp,
    updatedAt: _builtInTimestamp,
  ),
  // 夜景：避免过曝并保留更多暗部细节（无手动 ISO，仅作曝光补偿起点）。
  CameraPreset(
    id: '${builtInPresetIdPrefix}night',
    name: '夜景',
    configVersion: presetConfigVersion,
    config: const PresetConfig(exposureCompensationEv: 0.3, audioEnabled: true),
    createdAt: _builtInTimestamp,
    updatedAt: _builtInTimestamp,
  ),
]);

/// 内置预设的时间戳占位；界面不展示内置预设的时间信息。
final DateTime _builtInTimestamp = DateTime.utc(2026);
