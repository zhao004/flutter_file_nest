import 'dart:io';

import 'package:filenest/app/di/injector.dart';
import 'package:filenest/app/models/video_export_request.dart';
import 'package:filenest/app/pages/preview/video_editor_view.dart';
import 'package:filenest/app/preview/video_editor_host.dart';
import 'package:filenest/app/preview/video_render.dart';
import 'package:filenest/app/services/saf_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// 假渲染器：直接回传输出路径，或按需抛出错误。
class FakeRenderer implements VideoRenderer {
  PlatformException? failure;
  int calls = 0;

  @override
  Future<String> render(
    VideoExportRequest request, {
    required String outputPath,
  }) async {
    calls++;
    final error = failure;
    if (error != null) throw error;
    return outputPath;
  }
}

void main() {
  late FakeStorage storage;
  late FakeRenderer renderer;
  late VideoEditorHostConfig? captured;
  String? saved;

  setUp(() {
    storage = FakeStorage();
    renderer = FakeRenderer();
    captured = null;
    saved = null;
    getIt.registerSingleton<StorageGateway>(storage);
  });

  tearDown(() => getIt.reset());

  Widget builder(VideoEditorHostConfig config) {
    captured = config;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('video:${config.filePath}'),
        ElevatedButton(
          onPressed: () => config.onExport(
            const VideoExportRequest(
              clips: [VideoClipSpec(path: '/src.mp4')],
              useSegments: false,
            ),
          ),
          child: const Text('导出'),
        ),
        ElevatedButton(onPressed: config.onClose, child: const Text('关闭')),
      ],
    );
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.push<String>(
                    context,
                    MaterialPageRoute<String>(
                      builder: (_) => VideoEditorView(
                        entry: entry('clip.mp4', mime: 'video/mp4'),
                        parent: root,
                        editorBuilder: builder,
                        renderer: renderer,
                        audioTrackPicker: (_) async => const [],
                        tempDirectoryProvider: () async => Directory.systemTemp,
                      ),
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('导出渲染并导入保险库后回调副本文件名', (tester) async {
    storage.importResults = [entry('clip_edited.mp4', mime: 'video/mp4')];
    await openEditor(tester);

    expect(storage.cacheExports, 1);
    await tester.tap(find.text('导出'));
    await tester.pumpAndSettle();

    expect(renderer.calls, 1);
    expect(storage.importDocumentCalls, hasLength(1));
    expect(saved, 'clip_edited.mp4');
    expect(find.byType(VideoEditorView), findsNothing);
  });

  testWidgets('渲染失败提示并停留编辑页', (tester) async {
    renderer.failure = PlatformException(
      code: 'render_failed',
      message: '导出失败',
    );
    await openEditor(tester);

    await tester.tap(find.text('导出'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(VideoEditorView), findsOneWidget);
    expect(find.text('导出失败'), findsOneWidget);
    expect(storage.importDocumentCalls, isEmpty);
  });

  testWidgets('关闭不导出直接返回', (tester) async {
    await openEditor(tester);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(renderer.calls, 0);
    expect(saved, isNull);
    expect(find.byType(VideoEditorView), findsNothing);
  });

  testWidgets('片段选择经存储网关取回本地路径', (tester) async {
    await openEditor(tester);

    final path = await captured!.pickClip();
    expect(storage.videoPicks, 1);
    expect(path, storage.pickVideoResult);
  });
}
