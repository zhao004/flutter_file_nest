import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/storage_entry.dart';
import '../../preview/text_content.dart';
import '../../services/saf_storage.dart';
import 'preview_settings_controller.dart';
import 'preview_widgets.dart';

/// 文本/代码编辑器：按原编码、BOM 与换行风格覆盖保存。
///
/// 内容被截断（超过读取上限）时不提供编辑，避免用不完整内容覆盖原文件；
/// 未保存返回时二次确认。保存成功后返回更新后的条目。
class TextEditorView extends StatefulWidget {
  const TextEditorView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<TextEditorView> createState() => _TextEditorViewState();
}

class _TextEditorViewState extends State<TextEditorView> {
  late final StorageGateway _storage = Get.find<StorageGateway>();
  late final PreviewSettingsController _settings =
      Get.find<PreviewSettingsController>();
  final _controller = TextEditingController();

  TextContent? _content;
  String? _original;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  bool get _dirty => _content != null && _controller.text != _original;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await loadTextContent(_storage, widget.entry);
      if (!mounted) return;
      _controller.text = content.text;
      setState(() {
        _content = content;
        _original = content.text;
        _loading = false;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = previewErrorMessage(failure);
      });
    }
  }

  void _revert() {
    final original = _original;
    if (original == null) return;
    _controller.text = original;
  }

  Future<void> _save() async {
    final content = _content;
    if (content == null || _saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await encodeTextBytes(
        _controller.text,
        encoding: content.encoding,
        hasBom: content.hasBom,
        lineEnding: content.lineEnding,
      );
      final updated = await _storage.writeDocument(widget.entry, bytes);
      if (!mounted) return;
      setState(() {
        _original = _controller.text;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.of(context).pop(updated);
    } on TextEncodeException catch (failure) {
      _showError(failure.message);
    } catch (failure) {
      _showError(previewErrorMessage(failure, fallback: '保存失败，请重试'));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 有未保存修改时确认是否放弃；返回 true 表示可以离开。
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('离开将丢失本次编辑内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final discard = await _confirmDiscard();
      if (!context.mounted) return;
      if (discard) Navigator.of(context).pop();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '保存',
            onPressed: _dirty && !_saving ? _save : null,
            icon: const Icon(Icons.save_outlined),
          ),
          PopupMenuButton<_EditorMenu>(
            tooltip: '编辑选项',
            onSelected: (value) => switch (value) {
              _EditorMenu.revert => _revert(),
              _EditorMenu.openExternal => _storage.openFile(widget.entry),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _EditorMenu.revert,
                enabled: _dirty,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.undo),
                  title: Text('还原修改'),
                ),
              ),
              const PopupMenuItem(
                value: _EditorMenu.openExternal,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.open_in_new),
                  title: Text('用其他应用打开'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _body(),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final error = _error;
    if (error != null) {
      return PreviewErrorView(
        entry: widget.entry,
        message: error,
        onRetry: _load,
      );
    }
    final content = _content!;
    if (content.truncated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber, size: 56),
              const SizedBox(height: 16),
              const Text('文件过大，无法在应用内编辑', textAlign: TextAlign.center),
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
    return Column(
      children: [
        if (content.encoding != 'UTF-8' ||
            content.hasBom ||
            content.lineEnding != '\n')
          _EncodingNotice(content: content),
        Expanded(
          child: Obx(
            () => TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: _settings.fontSize.value,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                hintText: '输入内容',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _EditorMenu { revert, openExternal }

/// 编辑态编码信息条：提示保存时保持的原编码/BOM/换行。
class _EncodingNotice extends StatelessWidget {
  const _EncodingNotice({required this.content});

  final TextContent content;

  @override
  Widget build(BuildContext context) {
    final details = [
      content.encoding,
      if (content.hasBom) 'BOM',
      if (content.lineEnding == '\r\n') 'CRLF',
    ].join(' · ');
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.info_outline, size: 20),
        title: Text('保存时保持：$details'),
      ),
    );
  }
}
