import 'dart:typed_data';

/// 单个视频片段（可能经过裁剪）。
class VideoClipSpec {
  const VideoClipSpec({required this.path, this.startTime, this.endTime});

  final String path;
  final Duration? startTime;
  final Duration? endTime;
}

/// 导出时的裁剪/旋转/翻转变换。
class VideoExportTransform {
  const VideoExportTransform({
    this.width,
    this.height,
    this.rotateTurns = 0,
    this.x,
    this.y,
    this.flipX = false,
    this.flipY = false,
  });

  final int? width;
  final int? height;
  final int rotateTurns;
  final int? x;
  final int? y;
  final bool flipX;
  final bool flipY;
}

/// 视频导出请求：由编辑器宿主按编辑器回传参数构造，页面据此渲染。
///
/// 只包含渲染所需的纯数据，不依赖第三方类型，便于单元测试。
class VideoExportRequest {
  const VideoExportRequest({
    required this.clips,
    required this.useSegments,
    this.startTime,
    this.endTime,
    this.blur = 0,
    this.colorMatrix,
    this.layersImage,
    this.hasLayers = false,
    this.transform,
    this.enableAudio = true,
    this.bitrate,
  });

  final List<VideoClipSpec> clips;

  /// 多片段合并时使用逐片段裁剪；单片段时使用全局 [startTime]/[endTime]。
  final bool useSegments;
  final Duration? startTime;
  final Duration? endTime;
  final double blur;
  final List<double>? colorMatrix;
  final Uint8List? layersImage;
  final bool hasLayers;
  final VideoExportTransform? transform;
  final bool enableAudio;
  final int? bitrate;
}
