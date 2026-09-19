import 'dart:typed_data';

import 'package:filenest/app/models/video_export_request.dart';
import 'package:filenest/app/preview/video_render.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  test('单片段请求映射为单段并应用全局裁剪', () {
    final data = buildVideoRenderData(
      VideoExportRequest(
        clips: [const VideoClipSpec(path: '/a.mp4')],
        useSegments: false,
        startTime: const Duration(seconds: 1),
        endTime: const Duration(seconds: 3),
        bitrate: 1000,
      ),
    );

    expect(data.videoSegments, hasLength(1));
    expect(data.startTime, const Duration(seconds: 1));
    expect(data.endTime, const Duration(seconds: 3));
    expect(data.bitrate, 1000);
    expect(data.outputFormat, VideoOutputFormat.mp4);
  });

  test('多片段使用逐段裁剪且无全局裁剪', () {
    final data = buildVideoRenderData(
      VideoExportRequest(
        clips: [
          const VideoClipSpec(path: '/a.mp4', endTime: Duration(seconds: 2)),
          const VideoClipSpec(path: '/b.mp4', startTime: Duration(seconds: 1)),
        ],
        useSegments: true,
        startTime: const Duration(seconds: 5),
      ),
    );

    expect(data.videoSegments, hasLength(2));
    expect(data.videoSegments!.first.endTime, const Duration(seconds: 2));
    expect(data.videoSegments!.last.startTime, const Duration(seconds: 1));
    expect(data.startTime, isNull);
  });

  test('图层与滤镜映射到渲染数据', () {
    final data = buildVideoRenderData(
      VideoExportRequest(
        clips: [const VideoClipSpec(path: '/a.mp4')],
        useSegments: false,
        hasLayers: true,
        layersImage: Uint8List.fromList(const [1, 2, 3]),
        colorMatrix: const [
          1, 0, 0, 0, 0, //
          0, 1, 0, 0, 0, //
          0, 0, 1, 0, 0, //
          0, 0, 0, 1, 0, //
        ],
      ),
    );

    expect(data.imageLayers, hasLength(1));
    expect(data.colorFilters, hasLength(1));
  });
}
