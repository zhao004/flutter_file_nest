import 'package:pro_video_editor/pro_video_editor.dart';

import '../models/video_export_request.dart';

/// 视频渲染器：把导出请求渲染为本地文件并返回其路径。
///
/// 抽象出该接缝，页面逻辑可在测试中用假实现替换原生渲染。
abstract interface class VideoRenderer {
  Future<String> render(
    VideoExportRequest request, {
    required String outputPath,
  });
}

/// 基于 pro_video_editor 的渲染实现（Android/iOS/macOS）。
class ProVideoRenderer implements VideoRenderer {
  const ProVideoRenderer();

  @override
  Future<String> render(
    VideoExportRequest request, {
    required String outputPath,
  }) => ProVideoEditor.instance.renderVideoToFile(
    outputPath,
    buildVideoRenderData(request),
  );
}

/// 纯映射：导出请求 → pro_video_editor 渲染数据（可单元测试）。
VideoRenderData buildVideoRenderData(VideoExportRequest request) {
  final segments = request.clips
      .map(
        (clip) => VideoSegment(
          video: EditorVideo.file(clip.path),
          startTime: clip.startTime,
          endTime: clip.endTime,
        ),
      )
      .toList();

  return VideoRenderData(
    outputFormat: VideoOutputFormat.mp4,
    videoSegments: request.useSegments ? segments : [segments.single],
    imageLayers: request.hasLayers && request.layersImage != null
        ? [ImageLayer(image: EditorLayerImage.memory(request.layersImage!))]
        : null,
    transform: request.transform == null
        ? null
        : ExportTransform(
            width: request.transform!.width,
            height: request.transform!.height,
            rotateTurns: request.transform!.rotateTurns,
            x: request.transform!.x,
            y: request.transform!.y,
            flipX: request.transform!.flipX,
            flipY: request.transform!.flipY,
          ),
    blur: request.blur == 0 ? null : request.blur,
    colorFilters: request.colorMatrix == null
        ? const []
        : [ColorFilter(matrix: request.colorMatrix!)],
    enableAudio: request.enableAudio,
    bitrate: request.bitrate,
    startTime: request.useSegments ? null : request.startTime,
    endTime: request.useSegments ? null : request.endTime,
  );
}
