import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:get/get.dart';

import '../../models/storage_entry.dart';
import '../../preview/epub_reader.dart';
import '../../preview/preview_limits.dart';
import '../../services/saf_storage.dart';
import 'preview_settings_controller.dart';
import 'preview_widgets.dart';

/// EPUB 阅读器：按 spine 顺序分页展示章节，支持目录跳转与字号调整。
///
/// 图片等外部资源不加载（避免相对路径解析与网络请求）；链接不跳转，
/// 仅提示地址。解析失败时提供重试与外部打开。
class EpubPreviewView extends StatefulWidget {
  const EpubPreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<EpubPreviewView> createState() => _EpubPreviewViewState();
}

class _EpubPreviewViewState extends State<EpubPreviewView> {
  late final StorageGateway _storage = Get.find<StorageGateway>();
  late final PreviewSettingsController _settings =
      Get.find<PreviewSettingsController>();
  final _pageController = PageController();

  EpubBook? _book;
  String? _error;
  bool _loading = true;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _storage.readDocumentLimited(
        widget.entry,
        maxBytes: archiveReadLimit,
      );
      await Future<void>.delayed(Duration.zero);
      final book = readEpub(result.bytes);
      if (!mounted) return;
      setState(() {
        _book = book;
        _loading = false;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure is EpubReadException
            ? failure.message
            : '无法解析此 EPUB 文件';
      });
    }
  }

  Future<void> _openToc() async {
    final book = _book;
    if (book == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: book.chapters.length,
          itemBuilder: (context, index) => ListTile(
            selected: index == _index,
            title: Text(
              book.chapters[index].title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.pop(context, index),
          ),
        ),
      ),
    );
    if (selected != null && _pageController.hasClients) {
      _pageController.jumpToPage(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          book?.title ?? widget.entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (book != null)
            IconButton(
              tooltip: '目录',
              onPressed: _openToc,
              icon: const Icon(Icons.list_alt),
            ),
          IconButton(
            tooltip: '用其他应用打开',
            onPressed: () => _storage.openFile(widget.entry),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: book == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '第 ${_index + 1} / ${book.chapters.length} 章 · '
                  '${book.chapters[_index].title}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final error = _error;
    if (error != null) {
      return PreviewErrorView(
        entry: widget.entry,
        message: error,
        icon: Icons.menu_book_outlined,
        onRetry: _load,
      );
    }
    final book = _book!;
    return PageView.builder(
      controller: _pageController,
      itemCount: book.chapters.length,
      onPageChanged: (index) => setState(() => _index = index),
      itemBuilder: (context, index) => Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: HtmlWidget(
            book.chapters[index].html,
            textStyle: TextStyle(
              fontSize: _settings.fontSize.value,
              height: 1.7,
            ),
            customWidgetBuilder: (element) =>
                element.localName == 'img' ? const SizedBox.shrink() : null,
            onTapUrl: (url) async {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('链接：$url')));
              return true;
            },
          ),
        ),
      ),
    );
  }
}
