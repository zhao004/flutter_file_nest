import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../di/injector.dart';
import '../../localization.dart';
import '../../models/storage_entry.dart';
import '../../preview/preview_defaults.dart';
import '../../preview/text_content.dart';
import '../../routes/app_routes.dart';
import '../../services/saf_storage.dart';
import 'preview_settings_controller.dart';
import 'preview_widgets.dart';

/// Markdown 预览：阅读（渲染）与源码两种模式，模式偏好持久化。
///
/// 使用 `MarkdownBody` 置于单个滚动视图中，避免与外层滚动冲突；本地
/// 图片不解析，链接暂不跳转。
class MarkdownPreviewView extends StatefulWidget {
  const MarkdownPreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<MarkdownPreviewView> createState() => _MarkdownPreviewViewState();
}

class _MarkdownPreviewViewState extends State<MarkdownPreviewView> {
  late final StorageGateway _storage = getIt<StorageGateway>();
  late final PreviewSettingsController _settings =
      getIt<PreviewSettingsController>();
  late Future<TextContent> _future = _load();

  Future<TextContent> _load() => loadTextContent(_storage, widget.entry);

  void _retry() => setState(() => _future = _load());

  /// 进入编辑页（编辑源码）；返回后重新加载以反映保存结果。
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
        SignalBuilder(
          builder: (context) {
            final reading = _settings.markdownMode.value != kMarkdownModeSource;
            return IconButton(
              tooltip: reading
                  ? context.l10n.markdownViewSource
                  : context.l10n.markdownReadingMode,
              onPressed: () => _settings.setMarkdownMode(
                reading ? kMarkdownModeSource : kDefaultMarkdownMode,
              ),
              icon: Icon(reading ? Icons.code : Icons.article_outlined),
            );
          },
        ),
        if (widget.entry.canWrite)
          IconButton(
            tooltip: context.l10n.markdownEditSource,
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
            Expanded(child: _body(content)),
          ],
        );
      },
    ),
  );

  Widget _body(TextContent content) => SignalBuilder(
    builder: (context) {
      final reading = _settings.markdownMode.value != kMarkdownModeSource;
      if (!reading) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            content.text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: _settings.fontSize.value,
              height: 1.4,
            ),
          ),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: content.text,
          selectable: true,
          onTapLink: (text, href, title) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.commonLink(href ?? text))),
            );
          },
        ),
      );
    },
  );
}
