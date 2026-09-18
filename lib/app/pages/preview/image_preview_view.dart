import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';

/// 应用内图片预览：经内容 URI 读取字节，支持缩放与拖动查看。
///
/// Flutter 解码器不支持 HEIC/HEIF 时展示错误并提供“用其他应用打开”。
class ImagePreviewView extends StatefulWidget {
  const ImagePreviewView({required this.entry, super.key});
  final StorageEntry entry;
  @override
  State<ImagePreviewView> createState() => _ImagePreviewViewState();
}

class _ImagePreviewViewState extends State<ImagePreviewView> {
  late final Future<Uint8List?> _future = Get.find<StorageGateway>()
      .readDocument(widget.entry);
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
        IconButton(
          tooltip: '用其他应用打开',
          onPressed: () => Get.find<StorageGateway>().openFile(widget.entry),
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
          return Center(
            child: InteractiveViewer(
              maxScale: 8,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => _errorBody(context),
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
            onPressed: () => Get.find<StorageGateway>().openFile(widget.entry),
            icon: const Icon(Icons.open_in_new),
            label: const Text('用其他应用打开'),
          ),
        ],
      ),
    ),
  );
}
