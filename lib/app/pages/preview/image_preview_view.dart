import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../file_type/file_type_info.dart';
import '../../models/storage_entry.dart';
import '../../services/archive_service.dart';
import '../../services/saf_storage.dart';

/// 应用内图片预览：经内容 URI 读取字节，支持缩放、双击与拖动查看。
///
/// SVG 交由 `flutter_svg` 渲染；位图沿用 Flutter 解码器，不支持的格式
/// （如部分 HEIC）展示错误并提供“用其他应用打开”。
class ImagePreviewView extends StatefulWidget {
  const ImagePreviewView({required this.entry, super.key});
  final StorageEntry entry;
  @override
  State<ImagePreviewView> createState() => _ImagePreviewViewState();
}

class _ImagePreviewViewState extends State<ImagePreviewView> {
  late final StorageGateway _storage = Get.find<StorageGateway>();
  late final Future<Uint8List?> _future = _storage.readDocument(widget.entry);
  final _controller = TransformationController();

  bool get _isSvg => widget.entry.name.toLowerCase().endsWith('.svg');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 以视口中心为基准缩放到 [scale]；1.0 表示适配窗口。
  void _zoomTo(double scale) {
    final size = context.size;
    final center = size == null
        ? Offset.zero
        : Offset(size.width / 2, size.height / 2);
    _controller.value = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  /// 双击在“适配”与 2 倍之间切换。
  void _handleDoubleTap() {
    final scale = _controller.value.getMaxScaleOnAxis();
    _zoomTo(scale > 1.01 ? 1.0 : 2.0);
  }

  Future<void> _showInfo() async {
    final entry = widget.entry;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('图片信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(dialogContext, '名称', entry.name),
            _infoRow(
              dialogContext,
              '类型',
              fileCategoryLabel(entry.fileCategory),
            ),
            _infoRow(dialogContext, '大小', formatBytes(entry.size)),
            _infoRow(
              dialogContext,
              '修改时间',
              entry.modifiedAt == null ? '未知' : _formatTime(entry.modifiedAt!),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );

  Future<void> _share() async {
    if (!Get.isRegistered<ArchiveGateway>()) return;
    await Get.find<ArchiveGateway>().share([widget.entry]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      // 沉浸式黑底查看器需显式指定图标色：主题的 AppBar 图标色会覆盖
      // foregroundColor，浅色模式下为深色，在黑底上不可见。
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        widget.entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        PopupMenuButton<double>(
          tooltip: '缩放',
          iconColor: Colors.white,
          onSelected: _zoomTo,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 1.0, child: Text('适配窗口')),
            PopupMenuItem(value: 2.0, child: Text('2 倍')),
            PopupMenuItem(value: 4.0, child: Text('4 倍')),
          ],
        ),
        IconButton(
          tooltip: '图片信息',
          onPressed: _showInfo,
          icon: const Icon(Icons.info_outline),
        ),
        if (Get.isRegistered<ArchiveGateway>())
          IconButton(
            tooltip: '分享',
            onPressed: _share,
            icon: const Icon(Icons.ios_share),
          ),
        IconButton(
          tooltip: '用其他应用打开',
          onPressed: () => _storage.openFile(widget.entry),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (bytes == null) return _errorBody(context);
          return GestureDetector(
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.5,
              maxScale: 8,
              child: Center(
                child: _isSvg
                    ? SvgPicture.memory(
                        bytes,
                        fit: BoxFit.contain,
                        placeholderBuilder: (_) =>
                            const CircularProgressIndicator(),
                        errorBuilder: (context, error, stack) =>
                            _errorBody(context),
                      )
                    : Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) =>
                            _errorBody(context),
                      ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _errorBody(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '无法在应用内预览此图片，可能是不受支持的格式（如 HEIC）',
            textAlign: TextAlign.center,
          ),
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

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
