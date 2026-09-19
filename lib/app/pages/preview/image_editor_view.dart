import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/storage_entry.dart';
import '../../preview/image_editor_host.dart';
import '../../preview/media_editor_format.dart';
import '../../services/saf_storage.dart';
import 'preview_widgets.dart';

/// 图片编辑器：基于 pro_image_editor 的全屏编辑。
///
/// 读取原图字节后交给编辑器；保存采用“另存为副本”，在 [parent] 目录生成
/// `原名_edited.扩展名`，原文件不变。保存成功后以新文件名作为返回值 pop。
class ImageEditorView extends StatefulWidget {
  const ImageEditorView({
    required this.entry,
    required this.parent,
    this.onSaved,
    this.editorBuilder = buildProImageEditor,
    super.key,
  });

  final StorageEntry entry;

  /// 副本的目标目录；必须可创建文件。
  final StorageEntry parent;

  /// 保存副本成功后的回调，参数为副本文件名。
  final void Function(String name)? onSaved;

  /// 编辑器构建器；测试注入假实现，生产默认使用 pro_image_editor。
  final ImageEditorBuilder editorBuilder;

  @override
  State<ImageEditorView> createState() => _ImageEditorViewState();
}

class _ImageEditorViewState extends State<ImageEditorView> {
  late final StorageGateway _storage = Get.find<StorageGateway>();

  Uint8List? _bytes;
  String? _error;
  bool _saving = false;

  /// 防止保存成功与关闭回调重复 pop。
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _bytes = null;
    });
    try {
      final bytes = await _storage.readDocument(widget.entry);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = '无法在应用内编辑此图片，可能是不受支持的格式');
        return;
      }
      setState(() => _bytes = bytes);
    } catch (failure) {
      if (!mounted) return;
      setState(() => _error = previewErrorMessage(failure));
    }
  }

  Future<void> _onComplete(Uint8List bytes) async {
    if (_saving || _closed) return;
    setState(() => _saving = true);
    try {
      final name = await _save(bytes);
      if (!mounted) return;
      _closed = true;
      widget.onSaved?.call(name);
      Navigator.of(context).pop();
    } catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(previewErrorMessage(failure, fallback: '保存失败，请重试')),
        ),
      );
    }
  }

  void _onClose() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  /// 另存为副本；写入失败时删除半成品，避免残留空文件。
  Future<String> _save(Uint8List bytes) async {
    final format = imageOutputFormatForName(widget.entry.name);
    final children = await _storage.list(widget.parent);
    final name = editedCopyName(
      widget.entry.name,
      imageCopyExtension(format),
      children.map((value) => value.name),
    );
    final created = await _storage.createFile(widget.parent, name);
    try {
      await _storage.writeDocument(created, bytes);
    } catch (_) {
      await _storage.delete(created);
      rethrow;
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: PreviewErrorView(
          entry: widget.entry,
          message: error,
          onRetry: _load,
        ),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Stack(
        children: [
          widget.editorBuilder(
            ImageEditorHostConfig(
              bytes: bytes,
              sourceName: widget.entry.name,
              pickSticker: _storage.pickImage,
              onComplete: _onComplete,
              onClose: _onClose,
            ),
          ),
          if (_saving)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
