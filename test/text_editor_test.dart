import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_lens_vault/app/pages/preview/preview_settings_controller.dart';
import 'package:flutter_lens_vault/app/pages/preview/text_editor_view.dart';
import 'package:flutter_lens_vault/app/services/saf_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

void main() {
  late FakeStorage storage;

  setUp(() {
    Get.testMode = true;
    storage = FakeStorage()
      ..readDocumentLimitedResult = Uint8List.fromList(utf8.encode('hello'));
    Get.put<StorageGateway>(storage);
    Get.put<PreviewSettingsController>(
      PreviewSettingsController(MemoryStore()),
    );
  });

  tearDown(Get.reset);

  /// 从带返回按钮的页面进入编辑页，便于验证未保存拦截。
  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TextEditorView(entry: entry('notes.txt')),
                  ),
                ),
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

  testWidgets('编辑文本并按原编码保存', (tester) async {
    await openEditor(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'hello');

    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(storage.writes, 1);
    expect(utf8.decode(storage.writtenBytes.values.single), 'hello world');
    expect(find.byType(TextEditorView), findsNothing);
  });

  testWidgets('未保存返回时二次确认', (tester) async {
    await openEditor(tester);
    await tester.enterText(find.byType(TextField), 'changed');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsOneWidget);

    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.byType(TextEditorView), findsOneWidget);
    expect(storage.writes, 0);
  });

  testWidgets('内容被截断时不允许编辑', (tester) async {
    storage
      ..readDocumentLimitedResult = Uint8List.fromList(utf8.encode('partial'))
      ..readDocumentTruncated = true;
    await openEditor(tester);
    expect(find.text('文件过大，无法在应用内编辑'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('保存'), findsOneWidget);
  });
}
