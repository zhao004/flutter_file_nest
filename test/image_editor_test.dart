import 'package:filenest/app/di/injector.dart';
import 'package:filenest/app/pages/preview/image_editor_view.dart';
import 'package:filenest/app/preview/image_editor_host.dart';
import 'package:filenest/app/services/saf_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/localization.dart';

void main() {
  late FakeStorage storage;
  late ImageEditorHostConfig? captured;
  String? saved;

  setUp(() {
    storage = FakeStorage();
    captured = null;
    saved = null;
    getIt.registerSingleton<StorageGateway>(storage);
  });

  tearDown(() => getIt.reset());

  Widget builder(ImageEditorHostConfig config) {
    captured = config;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('editor:${config.sourceName}'),
        ElevatedButton(
          onPressed: () => config.onComplete(Uint8List.fromList(const [9, 9])),
          child: const Text('完成'),
        ),
        ElevatedButton(onPressed: config.onClose, child: const Text('关闭')),
      ],
    );
  }

  Future<void> openEditor(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.push<String>(
                    context,
                    MaterialPageRoute<String>(
                      builder: (_) => ImageEditorView(
                        entry: entry(name),
                        parent: root,
                        editorBuilder: builder,
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

  testWidgets('保存 JPEG 原图时另存为 jpg 副本并返回文件名', (tester) async {
    await openEditor(tester, 'photo.jpg');

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(storage.fileCreates, 1);
    expect(storage.writes, 1);
    expect(
      storage.contents[root.documentId]!.map((value) => value.name),
      contains('photo_edited.jpg'),
    );
    expect(saved, 'photo_edited.jpg');
    expect(find.byType(ImageEditorView), findsNothing);
  });

  testWidgets('PNG 原图另存为 png 副本', (tester) async {
    await openEditor(tester, 'photo.png');

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(saved, 'photo_edited.png');
  });

  testWidgets('写入失败删除半成品并停留编辑页', (tester) async {
    storage.writeFailure = PlatformException(
      code: 'write_failed',
      message: '写入失败',
    );
    await openEditor(tester, 'photo.jpg');

    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(storage.fileCreates, 1);
    expect(storage.writes, 0);
    expect(storage.deletes, 1);
    expect(find.byType(ImageEditorView), findsOneWidget);
    expect(find.text('写入失败'), findsOneWidget);
  });

  testWidgets('贴纸取图走系统选择器', (tester) async {
    await openEditor(tester, 'photo.jpg');

    final bytes = await captured!.pickSticker();
    expect(storage.imagePicks, 1);
    expect(bytes, isNotNull);
  });

  testWidgets('关闭不保存直接返回', (tester) async {
    await openEditor(tester, 'photo.jpg');

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(storage.fileCreates, 0);
    expect(saved, isNull);
    expect(find.byType(ImageEditorView), findsNothing);
  });
}
