import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/batch_models.dart';
import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';
import 'home_controller.dart';

/// 压缩包名称对话框：默认名称预填，缺少 .zip 后缀时自动补齐并校验。
class ZipNameDialog extends StatefulWidget {
  const ZipNameDialog({required this.initialName, super.key});
  final String initialName;
  @override
  State<ZipNameDialog> createState() => _ZipNameDialogState();
}

class _ZipNameDialogState extends State<ZipNameDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialName,
  );
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _baseName(String value) {
    final text = value.trim();
    return text.toLowerCase().endsWith('.zip')
        ? text.substring(0, text.length - 4)
        : text;
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, '${_baseName(_text.text)}.zip');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('压缩为 ZIP'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        autofocus: true,
        maxLength: 116,
        decoration: const InputDecoration(
          labelText: '压缩包名称',
          suffixText: '.zip',
        ),
        validator: (value) => validateEntryName(_baseName(value ?? '')),
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('开始压缩')),
    ],
  );
}

/// 验证名称后才返回输入，避免无效名称进入原生文件操作。
class EntryNameDialog extends StatefulWidget {
  const EntryNameDialog({
    required this.title,
    this.fieldLabel = '文件夹名称',
    this.initialName,
    super.key,
  });
  final String title;
  final String fieldLabel;
  final String? initialName;
  @override
  State<EntryNameDialog> createState() => _EntryNameDialogState();
}

class _EntryNameDialogState extends State<EntryNameDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialName,
  );
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _text.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        autofocus: true,
        maxLength: 120,
        decoration: InputDecoration(labelText: widget.fieldLabel),
        validator: (value) => validateEntryName(value ?? ''),
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('确定')),
    ],
  );
}

/// 视频缩略图：按可见项惰性加载，失败回退占位图标；不阻塞列表滚动。
class EntryThumbnail extends StatefulWidget {
  const EntryThumbnail({required this.load, required this.fallback, super.key});
  final Future<Uint8List?> Function() load;
  final Widget fallback;
  @override
  State<EntryThumbnail> createState() => _EntryThumbnailState();
}

class _EntryThumbnailState extends State<EntryThumbnail> {
  Uint8List? _bytes;
  bool _disposed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.load();
      if (!_disposed && bytes != null && mounted) {
        setState(() => _bytes = bytes);
      }
    } catch (_) {
      // 加载失败保持占位图标，不缓存失败结果。
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _bytes == null
      ? widget.fallback
      : ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            _bytes!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
}

/// 应用内目录选择器：仅限当前已授权根目录内的导航。
///
/// 祖先关系通过导航轨迹 [trail] 表达，不解析 documentId 字符串。
class FolderPickerDialog extends StatefulWidget {
  const FolderPickerDialog({
    required this.storage,
    required this.root,
    super.key,
  });
  final StorageGateway storage;
  final StorageEntry root;
  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  final _trail = <StorageEntry>[];
  List<StorageEntry> _children = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open(widget.root);
  }

  Future<void> _open(StorageEntry folder) async {
    setState(() {
      _loading = true;
      _error = null;
      _trail.add(folder);
    });
    await _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final children = await widget.storage.list(_trail.last);
      if (!mounted) return;
      setState(() {
        _children = children.where((value) => value.isDirectory).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        _loading = false;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = userError(failure);
        _loading = false;
      });
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= _trail.length) return;
    setState(() {
      _trail.removeRange(index + 1, _trail.length);
      _children = const [];
      _loading = true;
    });
    _loadChildren();
  }

  /// 返回所选目标及其完整轨迹；取消时返回 null。
  List<StorageEntry>? _confirm() => List.of(_trail);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('选择目标文件夹', style: Theme.of(context).dialogTheme.titleTextStyle),
    content: SizedBox(
      width: 360,
      height: 400,
      child: Column(
        children: [
          Row(
            children: [
              if (_trail.length > 1)
                IconButton(
                  tooltip: '上一级',
                  onPressed: _loading ? null : () => _goTo(_trail.length - 2),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Text(
                  _trail.map((value) => value.name).join(' / '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _loading ? null : _loadChildren,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : _loading
                ? const Center(child: CircularProgressIndicator())
                : _children.isEmpty
                ? const Center(child: Text('没有子文件夹'))
                : ListView.separated(
                    itemCount: _children.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(
                        _children[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: _loading ? null : () => _open(_children[index]),
                    ),
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _loading ? null : () => Navigator.pop(context, _confirm()),
        child: const Text('选择此位置'),
      ),
    ],
  );
}

/// 批量重命名对话框：前缀、后缀、文本替换与序号，先预览后执行。
class BatchRenameDialog extends StatefulWidget {
  const BatchRenameDialog({required this.controller, super.key});
  final HomeController controller;
  @override
  State<BatchRenameDialog> createState() => _BatchRenameDialogState();
}

class _BatchRenameDialogState extends State<BatchRenameDialog> {
  final _prefix = TextEditingController();
  final _suffix = TextEditingController();
  final _replaceFrom = TextEditingController();
  final _replaceTo = TextEditingController();
  bool _numbering = false;
  int _startNumber = 1;
  List<RenamePreview> _previews = const [];
  bool _running = false;

  @override
  void dispose() {
    _prefix.dispose();
    _suffix.dispose();
    _replaceFrom.dispose();
    _replaceTo.dispose();
    super.dispose();
  }

  void _update() {
    final plan = BatchRenamePlan(
      prefix: _prefix.text,
      suffix: _suffix.text,
      replaceFrom: _replaceFrom.text,
      replaceTo: _replaceTo.text,
      numbering: _numbering,
      startNumber: _startNumber,
    );
    setState(
      () => _previews = plan.empty
          ? const []
          : widget.controller.previewRenameSelected(plan),
    );
  }

  Future<void> _execute() async {
    setState(() => _running = true);
    final job = await widget.controller.renameSelected(_previews);
    if (!mounted) return;
    // 先弹出结果对话框，再关闭重命名对话框，保证结果浮层在最上层。
    if (job != null) showBatchResult(context, job);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('批量重命名'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prefix,
                  decoration: const InputDecoration(labelText: '前缀'),
                  onChanged: (_) => _update(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _suffix,
                  decoration: const InputDecoration(labelText: '后缀'),
                  onChanged: (_) => _update(),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replaceFrom,
                  decoration: const InputDecoration(labelText: '查找文本'),
                  onChanged: (_) => _update(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _replaceTo,
                  decoration: const InputDecoration(labelText: '替换为'),
                  onChanged: (_) => _update(),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('使用序号（替换原名称）'),
            value: _numbering,
            onChanged: (value) {
              setState(() {
                _numbering = value;
                _update();
              });
            },
          ),
          if (_numbering)
            Row(
              children: [
                Text('起始序号'),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 99,
                    divisions: 99,
                    value: _startNumber.toDouble(),
                    label: '$_startNumber',
                    onChanged: (value) {
                      setState(() {
                        _startNumber = value.round();
                        _update();
                      });
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          const Text('预览', style: TextStyle(fontWeight: FontWeight.bold)),
          Flexible(
            child: SizedBox(
              height: 220,
              child: _previews.isEmpty
                  ? const Center(child: Text('请输入重命名规则'))
                  : ListView.separated(
                      itemCount: _previews.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final preview = _previews[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${preview.entry.name} → ${preview.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: preview.error == null
                              ? null
                              : Text(
                                  preview.error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                          leading: Icon(
                            preview.error == null
                                ? Icons.check
                                : Icons.error_outline,
                            color: preview.error == null
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _running ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed:
            _running ||
                _previews.isEmpty ||
                _previews.any((preview) => preview.error != null)
            ? null
            : _execute,
        child: const Text('执行重命名'),
      ),
    ],
  );
}

/// 批量任务逐项结果；失败项给出原因，部分成功不冒充全部成功。
void showBatchResult(BuildContext context, BatchJob job) {
  final kindLabel = switch (job.kind) {
    BatchKind.delete => '批量删除',
    BatchKind.move => '批量移动',
    BatchKind.rename => '批量重命名',
  };
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$kindLabel · ${job.summary()}'),
      content: SizedBox(
        width: 400,
        height: 320,
        child: ListView.separated(
          itemCount: job.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = job.items[index];
            final (icon, color) = switch (item.status) {
              BatchItemStatus.pending => (Icons.schedule, Colors.grey),
              BatchItemStatus.success => (Icons.check_circle, Colors.green),
              BatchItemStatus.failed => (
                Icons.error_outline,
                Theme.of(context).colorScheme.error,
              ),
              BatchItemStatus.copiedSourceKept => (
                Icons.warning_amber,
                Colors.orange,
              ),
            };
            return ListTile(
              dense: true,
              leading: Icon(icon, color: color),
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: item.message == null ? null : Text(item.message!),
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 文件详情：名称、所属目录、大小、时间与可读视频属性；缺失显示未知。
class EntryDetailsDialog extends StatelessWidget {
  const EntryDetailsDialog({
    required this.controller,
    required this.entry,
    required this.location,
    super.key,
  });
  final HomeController controller;
  final StorageEntry entry;
  final String location;
  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('名称', entry.name),
      ('位置', location),
      ('类型', entry.isDirectory ? '文件夹' : entry.mimeType ?? '未知'),
      ('大小', entry.isDirectory ? '—' : formatBytes(entry.size)),
      (
        '修改时间',
        entry.modifiedAt == null ? '未知' : _formatTime(entry.modifiedAt!),
      ),
    ];
    return AlertDialog(
      title: const Text('文件详情'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                    Expanded(child: SelectableText(value)),
                  ],
                ),
              ),
            if (entry.isVideo)
              FutureBuilder<Map<String, Object?>>(
                future: controller.videoDetails(entry),
                builder: (context, snapshot) {
                  final details = snapshot.data ?? const {};
                  final durationMs = details['durationMs'] as num?;
                  final width = details['width'] as num?;
                  final height = details['height'] as num?;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow(
                        '时长',
                        durationMs == null
                            ? '未知'
                            : formatDuration(
                                Duration(milliseconds: durationMs.toInt()),
                              ),
                      ),
                      _detailRow(
                        '尺寸',
                        width == null || height == null
                            ? '未知'
                            : '$width × $height',
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(color: Colors.blueGrey)),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

String _formatTime(DateTime time) {
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${time.year}/${pad(time.month)}/${pad(time.day)} '
      '${pad(time.hour)}:${pad(time.minute)}';
}
