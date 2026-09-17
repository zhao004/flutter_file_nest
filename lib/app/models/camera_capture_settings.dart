/// 用户可请求的录制规格模型。
///
/// 这里维护"用户请求值"；驱动侧初始化成功后产生"已接受配置"，两者分开展示。
/// 请求值不等于设备实际输出，实际输出以成品文件为准。
library;

/// 视频质量档位，对应 camera 插件的分辨率预设。
enum CaptureQuality {
  /// 480p（medium 预设）。
  p480,

  /// 720p（high 预设）。
  p720,

  /// 1080p（veryHigh 预设）。
  p1080,

  /// 设备最高分辨率（max 预设），不承诺具体输出。
  max,
}

/// 录制帧率请求；仅提供常见的固定帧率候选，不支持设备上按后备逻辑回退。
enum CaptureFps {
  /// 使用设备默认帧率。
  auto,

  /// 请求 30 FPS。
  fps30,

  /// 请求 60 FPS；设备不支持时录制启动可能失败并回退。
  fps60,
}

/// 视频码率档位；实际码率无法从当前后端读取，展示时必须标明为请求值。
enum VideoBitratePreset {
  /// 由设备编码器默认决定。
  auto,

  /// 低码率，适合小文件。
  low,

  /// 标准码率。
  standard,

  /// 高码率。
  high,

  /// 自定义码率，范围见 [minCustomBitrateBps]、[maxCustomBitrateBps]。
  custom,
}

/// 自定义码率允许下限（1 Mbps）。
const int minCustomBitrateBps = 1000000;

/// 自定义码率允许上限（100 Mbps）。
const int maxCustomBitrateBps = 100000000;

/// 低码率预设（4 Mbps）。
const int lowVideoBitrateBps = 4000000;

/// 标准码率预设（8 Mbps）。
const int standardVideoBitrateBps = 8000000;

/// 高码率预设（16 Mbps）。
const int highVideoBitrateBps = 16000000;

/// 录制规格请求：分辨率、帧率与码率。
///
/// 切换任一字段都需要重建相机会话；录制中必须先完成停止保存。
class RecordingSettings {
  const RecordingSettings({
    this.quality = CaptureQuality.p1080,
    this.fps = CaptureFps.fps30,
    this.bitrate = VideoBitratePreset.auto,
    this.customBitrateBps,
  });

  final CaptureQuality quality;
  final CaptureFps fps;
  final VideoBitratePreset bitrate;

  /// 自定义码率请求值（bps）；仅在 [VideoBitratePreset.custom] 时使用。
  final int? customBitrateBps;

  RecordingSettings withQuality(CaptureQuality value) => RecordingSettings(
    quality: value,
    fps: fps,
    bitrate: bitrate,
    customBitrateBps: customBitrateBps,
  );

  RecordingSettings withFps(CaptureFps value) => RecordingSettings(
    quality: quality,
    fps: value,
    bitrate: bitrate,
    customBitrateBps: customBitrateBps,
  );

  RecordingSettings withBitrate(
    VideoBitratePreset value, {
    int? customBitrateBps,
  }) => RecordingSettings(
    quality: quality,
    fps: fps,
    bitrate: value,
    customBitrateBps: customBitrateBps ?? this.customBitrateBps,
  );

  /// 自定义码率是否在允许范围内。
  bool get hasValidCustomBitrate =>
      customBitrateBps != null &&
      customBitrateBps! >= minCustomBitrateBps &&
      customBitrateBps! <= maxCustomBitrateBps;

  /// 传给后端的视频码率请求值（bps）；自动或自定义无效时为 null。
  int? get videoBitrateBps => switch (bitrate) {
    VideoBitratePreset.auto => null,
    VideoBitratePreset.low => lowVideoBitrateBps,
    VideoBitratePreset.standard => standardVideoBitrateBps,
    VideoBitratePreset.high => highVideoBitrateBps,
    VideoBitratePreset.custom =>
      hasValidCustomBitrate ? customBitrateBps : null,
  };

  /// 分辨率与帧率的展示文案，例如 "1080p / 30 FPS"。
  String get label => '$qualityLabel / $fpsLabel';

  /// 分辨率请求文案。
  String get qualityLabel => switch (quality) {
    CaptureQuality.p480 => '480p',
    CaptureQuality.p720 => '720p',
    CaptureQuality.p1080 => '1080p',
    CaptureQuality.max => '设备最高',
  };

  /// 帧率请求文案。
  String get fpsLabel => switch (fps) {
    CaptureFps.auto => '自动帧率',
    CaptureFps.fps30 => '30 FPS',
    CaptureFps.fps60 => '60 FPS',
  };

  /// 码率请求文案；实际码率不可读取，仅作为请求值展示。
  String get bitrateLabel => switch (bitrate) {
    VideoBitratePreset.auto => '自动',
    VideoBitratePreset.low => '低（4 Mbps）',
    VideoBitratePreset.standard => '标准（8 Mbps）',
    VideoBitratePreset.high => '高（16 Mbps）',
    VideoBitratePreset.custom =>
      hasValidCustomBitrate
          ? '${(customBitrateBps! / 1000000).toStringAsFixed(0)} Mbps'
          : '未设置',
  };

  @override
  bool operator ==(Object other) =>
      other is RecordingSettings &&
      quality == other.quality &&
      fps == other.fps &&
      bitrate == other.bitrate &&
      customBitrateBps == other.customBitrateBps;

  @override
  int get hashCode => Object.hash(quality, fps, bitrate, customBitrateBps);
}
