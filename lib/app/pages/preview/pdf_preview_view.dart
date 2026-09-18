import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';

/// 应用内 PDF 预览：原生 PdfRenderer 按页渲染，页面视图支持滑动与缩放。
///
/// 受密码保护的 PDF 显示明确原因；渲染按需进行并保留最近几页缓存。
class PdfPreviewView extends StatefulWidget {
  const PdfPreviewView({required this.entry, super.key});
  final StorageEntry entry;
  @override
  State<PdfPreviewView> createState() => _PdfPreviewViewState();
}

class _PdfPreviewViewState extends State<PdfPreviewView> {
  late final StorageGateway _storage = Get.find<StorageGateway>();
  late final Future<int> _pageCount = _loadPageCount();
  final PageController _controller = PageController();
  final LinkedHashMap<int, Future<Uint8List?>> _pages = LinkedHashMap();
  int _current = 0;

  /// 最多同时保留的已渲染页；超出时淘汰最早加载的页，控制内存占用。
  static const int _maxCachedPages = 6;

  Future<int> _loadPageCount() async {
    final info = await _storage.pdfInfo(widget.entry);
    return (info['pageCount'] as num?)?.toInt() ?? 0;
  }

  Future<Uint8List?> _pageBytes(int index) {
    final existing = _pages[index];
    if (existing != null) return existing;
    final future = _storage.pdfPage(widget.entry, page: index);
    _pages[index] = future;
    while (_pages.length > _maxCachedPages) {
      _pages.remove(_pages.keys.first);
    }
    return future;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(
        widget.entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: '用其他应用打开',
          onPressed: () => _storage.openFile(widget.entry),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<int>(
        future: _pageCount,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = snapshot.error;
          if (error != null) {
            return _errorBody(context, error);
          }
          final count = snapshot.data ?? 0;
          if (count <= 0) {
            return const Center(child: Text('此 PDF 没有可显示的页面'));
          }
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: count,
                  onPageChanged: (index) => setState(() => _current = index),
                  itemBuilder: (context, index) =>
                      _PdfPage(load: () => _pageBytes(index)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '第 ${_current + 1} / $count 页',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _errorBody(BuildContext context, Object error) {
    final message = switch (error) {
      PlatformException(code: 'pdf_protected') => '此 PDF 受密码保护，无法在应用内预览',
      PlatformException(code: 'pdf_invalid') => '无法读取此 PDF，文件可能已损坏',
      _ => '无法读取此 PDF，请稍后重试',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _storage.openFile(widget.entry),
              icon: const Icon(Icons.open_in_new),
              label: const Text('用其他应用打开'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单页渲染视图；加载中显示进度，失败显示原因。
class _PdfPage extends StatefulWidget {
  const _PdfPage({required this.load});
  final Future<Uint8List?> Function() load;
  @override
  State<_PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<_PdfPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Center(
      child: FutureBuilder<Uint8List?>(
        future: widget.load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('此页无法渲染', style: TextStyle(color: Colors.white70)),
            );
          }
          return InteractiveViewer(
            maxScale: 8,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) =>
                  const Text('此页无法渲染', style: TextStyle(color: Colors.white70)),
            ),
          );
        },
      ),
    );
  }
}
