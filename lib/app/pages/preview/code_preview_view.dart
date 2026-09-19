import 'package:material_ui/material_ui.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../di/injector.dart';
import '../../file_type/file_extension_map.dart';
import '../../localization.dart';
import '../../models/storage_entry.dart';
import '../../preview/code_language.dart';
import '../../preview/text_content.dart';
import '../../routes/app_routes.dart';
import '../../services/saf_storage.dart';
import 'preview_settings_controller.dart';
import 'preview_widgets.dart';
import 'text_search.dart';

/// 代码与结构化配置预览：语法高亮、行号、搜索与横向滚动。
///
/// 高亮使用纯 Dart 的 `highlight`，按亮/暗主题选择配色；搜索时切换为纯文本
/// 高亮，避免语法着色与命中底色相互覆盖。不支持的语言按纯文本展示。
class CodePreviewView extends StatefulWidget {
  const CodePreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<CodePreviewView> createState() => _CodePreviewViewState();
}

class _CodePreviewViewState extends State<CodePreviewView> {
  late final StorageGateway _storage = getIt<StorageGateway>();
  late final PreviewSettingsController _settings =
      getIt<PreviewSettingsController>();
  late Future<TextContent> _future = _load();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _query = signal('');
  bool _searching = false;

  Future<TextContent> _load() => loadTextContent(_storage, widget.entry);

  void _retry() => setState(() => _future = _load());

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search.clear();
        _query.value = '';
      }
    });
    if (_searching) _searchFocus.requestFocus();
  }

  Future<void> _copyAll() async {
    try {
      final content = await _future;
      await Clipboard.setData(ClipboardData(text: content.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.textCopiedAll)));
    } catch (_) {
      /* 复制失败不提示。 */
    }
  }

  /// 进入编辑页；返回后重新加载以反映保存结果。
  Future<void> _edit() async {
    await context.push<void>(Routes.textEditor, extra: widget.entry);
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: _searching
              ? context.l10n.commonCloseSearch
              : context.l10n.commonSearch,
          onPressed: _toggleSearch,
          icon: Icon(_searching ? Icons.search_off : Icons.search),
        ),
        PopupMenuButton<_CodeMenu>(
          tooltip: context.l10n.codeOptions,
          onSelected: (value) => switch (value) {
            _CodeMenu.zoomIn => _settings.stepFontSize(2),
            _CodeMenu.zoomOut => _settings.stepFontSize(-2),
            _CodeMenu.copyAll => _copyAll(),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _CodeMenu.zoomIn,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.zoom_in),
                title: Text(context.l10n.textZoomIn),
              ),
            ),
            PopupMenuItem(
              value: _CodeMenu.zoomOut,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.zoom_out),
                title: Text(context.l10n.textZoomOut),
              ),
            ),
            PopupMenuItem(
              value: _CodeMenu.copyAll,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.copy_all_outlined),
                title: Text(context.l10n.textCopyAll),
              ),
            ),
          ],
        ),
        if (widget.entry.canWrite)
          IconButton(
            tooltip: context.l10n.commonEdit,
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        IconButton(
          tooltip: context.l10n.commonOpenExternal,
          onPressed: () => _storage.openFile(widget.entry),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: FutureBuilder<TextContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = snapshot.error;
        if (error != null) {
          return PreviewErrorView(
            entry: widget.entry,
            message: previewErrorMessage(error),
            onRetry: _retry,
          );
        }
        final content = snapshot.data!;
        return Column(
          children: [
            if (content.truncated) TruncatedNotice(entry: widget.entry),
            if (_searching) _searchField(),
            Expanded(child: _body(content)),
          ],
        );
      },
    ),
  );

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    child: TextField(
      controller: _search,
      focusNode: _searchFocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        hintText: context.l10n.codeSearchHint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) => _query.value = value,
    ),
  );

  Widget _body(TextContent content) => SignalBuilder(
    builder: (context) {
      final query = _query.value;
      final brightness = Theme.of(context).brightness;
      final language = highlightLanguageFor(fileExtension(widget.entry.name));
      final fontSize = _settings.fontSize.value;
      final base = TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        height: 1.4,
      );
      final code = Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: _code(content, query, language, brightness, base),
      );
      // 代码预览保持横向滚动，行号才能与行内容对齐；自动换行仅作用于文本预览与编辑器。
      return SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_settings.lineNumbers.value)
              _lineNumbers(context, content.text, base),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: code,
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _code(
    TextContent content,
    String query,
    String? language,
    Brightness brightness,
    TextStyle base,
  ) {
    if (query.isNotEmpty || language == null) {
      return SelectableText.rich(
        highlightMatches(
          content.text,
          query,
          base: base,
          matchStyle: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.3),
          ),
        ),
        style: base,
      );
    }
    return SelectionArea(
      child: HighlightView(
        content.text,
        language: language,
        theme: brightness == Brightness.dark
            ? atomOneDarkTheme
            : atomOneLightTheme,
        padding: EdgeInsets.zero,
        textStyle: TextStyle(fontSize: base.fontSize),
      ),
    );
  }

  Widget _lineNumbers(BuildContext context, String text, TextStyle base) {
    final count = '\n'.allMatches(text).length + 1;
    final numbers = List.generate(count, (index) => '${index + 1}').join('\n');
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(
        numbers,
        textAlign: TextAlign.right,
        style: base.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

enum _CodeMenu { zoomIn, zoomOut, copyAll }
