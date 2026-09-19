import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../di/injector.dart';
import '../../localization.dart';
import '../../models/storage_entry.dart';
import '../../preview/text_content.dart';
import '../../routes/app_routes.dart';
import '../../services/saf_storage.dart';
import 'preview_settings_controller.dart';
import 'preview_widgets.dart';
import 'text_search.dart';

/// 纯文本预览：支持搜索高亮、自动换行切换、字号调整与编码提示。
///
/// 内容经受限读取解码，超过上限时提示仅展示前一部分并提供外部打开。
class TextPreviewView extends StatefulWidget {
  const TextPreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<TextPreviewView> createState() => _TextPreviewViewState();
}

class _TextPreviewViewState extends State<TextPreviewView> {
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
        PopupMenuButton<_TextMenu>(
          tooltip: context.l10n.textOptions,
          onSelected: (value) => switch (value) {
            _TextMenu.zoomIn => _settings.stepFontSize(2),
            _TextMenu.zoomOut => _settings.stepFontSize(-2),
            _TextMenu.copyAll => _copyAll(),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _TextMenu.zoomIn,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.zoom_in),
                title: Text(context.l10n.textZoomIn),
              ),
            ),
            PopupMenuItem(
              value: _TextMenu.zoomOut,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.zoom_out),
                title: Text(context.l10n.textZoomOut),
              ),
            ),
            PopupMenuItem(
              value: _TextMenu.copyAll,
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
            if (content.encoding != 'UTF-8')
              _Notice(
                icon: Icons.translate,
                text: context.l10n.textDecodedAs(content.encoding),
              ),
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
        hintText: context.l10n.textSearchHint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) => _query.value = value,
    ),
  );

  Widget _body(TextContent content) => SignalBuilder(
    builder: (context) {
      final theme = Theme.of(context);
      final base = TextStyle(fontSize: _settings.fontSize.value, height: 1.4);
      final span = highlightMatches(
        content.text,
        _query.value,
        base: base,
        matchStyle: TextStyle(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      );
      final child = Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText.rich(span, style: base),
      );
      // 关闭自动换行时改为横向滚动；长行保持单行显示。
      if (_settings.wrap.value) return SingleChildScrollView(child: child);
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      );
    },
  );
}

enum _TextMenu { zoomIn, zoomOut, copyAll }

/// 顶部说明条：用于编码等非错误提示。
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(text),
    ),
  );
}
