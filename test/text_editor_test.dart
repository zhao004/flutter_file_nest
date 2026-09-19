import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:filenest/app/pages/preview/preview_settings_controller.dart';
import 'package:filenest/app/pages/preview/text_editor_view.dart';
import 'package:filenest/app/preview/editor_surface.dart';
import 'package:filenest/app/services/saf_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/di/injector.dart';

import 'support/fakes.dart';
import 'support/localization.dart';

/// 假编辑器控制器：记录文本与操作，方法均为同步语义。
class FakeCodeEditor implements CodeEditorController {
  FakeCodeEditor([this.text = '']);

  String text;
  bool editable = true;
  bool dark = false;
  double fontSize = 14;
  bool wrap = true;
  bool lineNumbers = true;
  int tabWidth = 4;
  bool autoIndent = true;
  int undos = 0;
  int redos = 0;

  @override
  Future<void> setText(String value) async => text = value;
  @override
  Future<String> readText() async => text;
  @override
  Future<void> setEditable(bool value) async => editable = value;
  @override
  Future<void> setDark(bool value) async => dark = value;
  @override
  Future<void> setFontSize(double value) async => fontSize = value;
  @override
  Future<void> setWrap(bool value) async => wrap = value;
  @override
  Future<void> setLineNumbers(bool value) async => lineNumbers = value;
  @override
  Future<void> setTabWidth(int value) async => tabWidth = value;
  @override
  Future<void> setAutoIndent(bool value) async => autoIndent = value;
  @override
  Future<void> undo() async => undos++;
  @override
  Future<void> redo() async => redos++;
}

class _FakeHolder {
  FakeCodeEditor? controller;
  CodeEditorHostConfig? config;
}

/// 假编辑器宿主：仅在一帧后回调控制器，模拟原生平台视图就绪。
class _FakeEditorHost extends StatefulWidget {
  const _FakeEditorHost({required this.config, required this.holder});

  final CodeEditorHostConfig config;
  final _FakeHolder holder;

  @override
  State<_FakeEditorHost> createState() => _FakeEditorHostState();
}

class _FakeEditorHostState extends State<_FakeEditorHost> {
  late final FakeCodeEditor controller = FakeCodeEditor();

  @override
  void initState() {
    super.initState();
    widget.holder
      ..controller = controller
      ..config = widget.config;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.config.onController(controller);
    });
  }

  @override
  void didUpdateWidget(_FakeEditorHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.holder.config = widget.config;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  late FakeStorage storage;
  late _FakeHolder holder;

  setUp(() {
    holder = _FakeHolder();
    storage = FakeStorage()
      ..readDocumentLimitedResult = Uint8List.fromList(utf8.encode('hello'));
    getIt.registerSingleton<StorageGateway>(storage);
    getIt.registerSingleton<PreviewSettingsController>(
      PreviewSettingsController(MemoryStore()),
    );
  });

  tearDown(() => getIt.reset());

  Widget builder(CodeEditorHostConfig config) =>
      _FakeEditorHost(config: config, holder: holder);

  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TextEditorView(
                      entry: entry('notes.txt'),
                      editorBuilder: builder,
                    ),
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

  testWidgets('加载文本到编辑器并按原编码保存', (tester) async {
    await openEditor(tester);
    expect(holder.controller!.text, 'hello');

    holder.controller!.text = 'hello world';
    holder.config!.onChanged();
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(storage.writes, 1);
    expect(utf8.decode(storage.writtenBytes.values.single), 'hello world');
    // 保存后停留编辑页，并清除未保存状态（保存按钮禁用）。
    expect(find.byType(TextEditorView), findsOneWidget);
    final saveButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.save_outlined),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('编辑器按偏好应用字号、换行、行号与缩进', (tester) async {
    final settings = getIt<PreviewSettingsController>();
    await settings.setFontSize(20);
    await settings.setWrap(false);
    await settings.setLineNumbers(false);
    await settings.setTabWidth(2);
    await settings.setAutoIndent(false);
    await openEditor(tester);

    final config = holder.config!;
    expect(config.fontSize, 20);
    expect(config.wrap, isFalse);
    expect(config.lineNumbers, isFalse);
    expect(config.tabWidth, 2);
    expect(config.autoIndent, isFalse);
  });

  testWidgets('未保存返回时二次确认', (tester) async {
    await openEditor(tester);
    holder.controller!.text = 'changed';
    holder.config!.onChanged();
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
    expect(holder.controller, isNull);
  });
}
