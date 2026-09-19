import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:filenest/app/pages/preview/archive_preview_view.dart';
import 'package:filenest/app/pages/preview/code_preview_view.dart';
import 'package:filenest/app/pages/preview/csv_preview_view.dart';
import 'package:filenest/app/pages/preview/file_preview_page.dart';
import 'package:filenest/app/pages/preview/markdown_preview_view.dart';
import 'package:filenest/app/pages/preview/preview_settings_controller.dart';
import 'package:filenest/app/pages/preview/subtitle_preview_view.dart';
import 'package:filenest/app/pages/preview/text_preview_view.dart';
import 'package:filenest/app/pages/preview/unsupported_preview_view.dart';
import 'package:filenest/app/services/saf_storage.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/di/injector.dart';

import 'support/fakes.dart';
import 'support/localization.dart';

void main() {
  late FakeStorage storage;

  setUp(() {
    storage = FakeStorage();
    getIt.registerSingleton<StorageGateway>(storage);
    getIt.registerSingleton<PreviewSettingsController>(
      PreviewSettingsController(MemoryStore()),
    );
  });

  tearDown(() => getIt.reset());

  Future<void> pumpView(WidgetTester tester, Widget view) async {
    await tester.pumpWidget(localizedApp(view));
    await tester.pumpAndSettle();
  }

  testWidgets('文本预览渲染文件名与内容', (tester) async {
    await pumpView(tester, TextPreviewView(entry: entry('notes.txt')));
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('可写文本显示编辑入口，只读隐藏', (tester) async {
    await pumpView(tester, TextPreviewView(entry: entry('notes.txt')));
    expect(find.byTooltip('编辑'), findsOneWidget);
    await pumpView(
      tester,
      TextPreviewView(entry: entry('notes.txt', canWrite: false)),
    );
    expect(find.byTooltip('编辑'), findsNothing);
  });

  testWidgets('代码预览显示行号', (tester) async {
    await pumpView(tester, CodePreviewView(entry: entry('script.sh')));
    expect(find.text('1\n2'), findsOneWidget);
  });

  testWidgets('关闭行号偏好后代码预览不显示行号', (tester) async {
    await getIt<PreviewSettingsController>().setLineNumbers(false);
    await pumpView(tester, CodePreviewView(entry: entry('script.sh')));
    expect(find.text('1\n2'), findsNothing);
  });

  testWidgets('Markdown 默认阅读模式并可切换到源码', (tester) async {
    await pumpView(tester, MarkdownPreviewView(entry: entry('README.md')));
    expect(find.byType(MarkdownBody), findsOneWidget);
    await tester.tap(find.byTooltip('查看源码'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('分发页按类型选择文本查看器', (tester) async {
    await pumpView(tester, FilePreviewPage(entry: entry('notes.txt')));
    expect(find.byType(TextPreviewView), findsOneWidget);
  });

  testWidgets('未知类型分发到信息页', (tester) async {
    await pumpView(tester, FilePreviewPage(entry: entry('app.apk')));
    expect(find.byType(UnsupportedPreviewView), findsOneWidget);
  });

  testWidgets('CSV 预览渲染表头与数据', (tester) async {
    storage.readDocumentLimitedResult = Uint8List.fromList(
      utf8.encode('a,b\n1,2'),
    );
    await pumpView(
      tester,
      CsvPreviewView(entry: entry('data.csv', mime: 'text/csv')),
    );
    expect(find.text('a'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('字幕预览列出对白', (tester) async {
    storage.readDocumentLimitedResult = Uint8List.fromList(
      utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nHello\n'),
    );
    await pumpView(tester, SubtitlePreviewView(entry: entry('movie.srt')));
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('归档预览列出条目', (tester) async {
    final archive = Archive();
    final content = utf8.encode('hi');
    archive.addFile(ArchiveFile('note.txt', content.length, content));
    storage.readDocumentLimitedResult = Uint8List.fromList(
      ZipEncoder().encode(archive),
    );
    await pumpView(tester, ArchivePreviewView(entry: entry('backup.zip')));
    expect(find.text('note.txt'), findsOneWidget);
  });
}
