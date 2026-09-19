import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../file_type/file_category.dart';
import '../../file_type/file_category_icon.dart';
import '../../file_type/file_icon_mapper.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../localization.dart';
import '../../models/batch_models.dart';
import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';
import '../../theme/app_colors.dart';
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
    title: Text(context.l10n.zipDialogTitle),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        autofocus: true,
        maxLength: 116,
        decoration: InputDecoration(
          labelText: context.l10n.zipNameLabel,
          suffixText: '.zip',
        ),
        validator: (value) =>
            validateEntryName(_baseName(value ?? ''), context.l10n),
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.zipStart)),
    ],
  );
}

/// 验证名称后才返回输入，避免无效名称进入原生文件操作。
class EntryNameDialog extends StatefulWidget {
  const EntryNameDialog({
    required this.title,
    required this.fieldLabel,
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
        validator: (value) => validateEntryName(value ?? '', context.l10n),
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.l10n.commonConfirm)),
    ],
  );
}

/// 视频缩略图：按可见项惰性加载，失败回退占位图标；不阻塞列表滚动。
///
/// [identity] 标识当前条目；列表复用导致条目变化时会重新加载，避免显示上一项的图。
/// [onCancel] 在行销毁时调用，用于放弃尚未开始的排队请求。
class EntryThumbnail extends StatefulWidget {
  const EntryThumbnail({
    required this.load,
    required this.fallback,
    this.identity,
    this.onCancel,
    super.key,
  });

  final Future<Uint8List?> Function() load;
  final Widget fallback;
  final Object? identity;
  final VoidCallback? onCancel;

  @override
  State<EntryThumbnail> createState() => _EntryThumbnailState();
}

class _EntryThumbnailState extends State<EntryThumbnail> {
  Uint8List? _bytes;
  bool _disposed = false;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EntryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      // 行被复用为另一个条目：取消旧条目的排队请求，清空旧图后请求新缩略图。
      oldWidget.onCancel?.call();
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final token = ++_requestToken;
    try {
      final bytes = await widget.load();
      // 条目已切换或组件已销毁时丢弃过期结果，避免覆盖新图。
      if (!_disposed && token == _requestToken && bytes != null && mounted) {
        setState(() => _bytes = bytes);
      }
    } catch (_) {
      // 加载失败保持占位图标，不缓存失败结果。
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestToken++;
    widget.onCancel?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    // 固定占位尺寸，切换缩略图时列表行高不抖动。
    width: 48,
    height: 48,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _bytes == null
          ? KeyedSubtree(
              key: const ValueKey('placeholder'),
              child: Center(child: widget.fallback),
            )
          : ClipRRect(
              key: const ValueKey('image'),
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                _bytes!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
    ),
  );
}

/// 视频行详情：异步解析分辨率并置于文件信息左侧。
///
/// 仅在条目为视频且已有详情文本时使用；解析失败或缺少尺寸时退化为原详情。
/// [identity] 变化（行被复用为另一视频）时重新请求，避免展示旧分辨率。
class EntryVideoDetail extends StatefulWidget {
  const EntryVideoDetail({
    required this.detail,
    required this.load,
    this.identity,
    super.key,
  });

  /// 不含分辨率的详情文本，例如“2.0 MB · 2026/09/18 12:00”。
  final String detail;

  /// 读取视频属性；返回的 width/height 缺失时忽略分辨率。
  final Future<Map<String, Object?>> Function() load;

  /// 条目身份指纹；变化时重新加载。
  final Object? identity;

  @override
  State<EntryVideoDetail> createState() => _EntryVideoDetailState();
}

class _EntryVideoDetailState extends State<EntryVideoDetail> {
  String? _resolution;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EntryVideoDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _resolution = null;
      _load();
    }
  }

  Future<void> _load() async {
    final token = ++_requestToken;
    try {
      final details = await widget.load();
      final width = details['width'] as num?;
      final height = details['height'] as num?;
      if (!mounted ||
          token != _requestToken ||
          width == null ||
          height == null) {
        return;
      }
      setState(() => _resolution = '${width.toInt()} × ${height.toInt()}');
    } catch (_) {
      // 无法读取分辨率时仅显示文件信息。
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolution = _resolution;
    return Text(
      resolution == null ? widget.detail : '$resolution · ${widget.detail}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 应用内目录选择器：仅限当前已授权根目录内的导航。
///
/// 祖先关系通过导航轨迹 [trail] 表达，不解析 documentId 字符串。
/// [validate] 实时校验当前轨迹能否作为移动目标；[blockedDocumentIds] 中的
/// 文件夹是本次移动的来源，禁止进入，避免选中自身或其后代。
class FolderPickerDialog extends StatefulWidget {
  const FolderPickerDialog({
    required this.storage,
    required this.root,
    this.selectedCount = 0,
    this.validate,
    this.blockedDocumentIds = const {},
    super.key,
  });
  final StorageGateway storage;
  final StorageEntry root;
  final int selectedCount;
  final String? Function(List<StorageEntry> trail)? validate;
  final Set<String> blockedDocumentIds;

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
        _error = userError(failure, context.l10n);
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

  String get _path => _trail.map((value) => value.name).join(' / ');

  @override
  Widget build(BuildContext context) {
    // 宽度扣除 Dialog 外边距与内容内边距，高度为标题/操作区预留空间，
    // 保证窄屏与横屏下都不溢出。
    final size = MediaQuery.sizeOf(context);
    final width = math.min(440.0, math.max(200.0, size.width - 80));
    final height = math.min(480.0, math.max(160.0, size.height - 200));
    final issue = widget.validate?.call(_trail);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      // 不显示“移动到…”标题，仅在有选中项时提示数量。
      title: widget.selectedCount > 0
          ? Text(context.l10n.homeSelectedCount(widget.selectedCount))
          : null,
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _breadcrumb(),
            const SizedBox(height: 4),
            _targetHint(issue),
            const SizedBox(height: 8),
            Expanded(child: _body()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: (_loading || issue != null)
              ? null
              : () => Navigator.pop(context, _confirm()),
          child: Text(context.l10n.folderPickerMoveHere),
        ),
      ],
    );
  }

  /// 可点击面包屑：点上级直接跳转，当前级不可点且加粗。
  Widget _breadcrumb() => SizedBox(
    height: 40,
    child: Row(
      children: [
        if (_trail.length > 1)
          IconButton(
            tooltip: context.l10n.commonPrevious,
            onPressed: _loading ? null : () => _goTo(_trail.length - 2),
            icon: const Icon(Icons.arrow_back),
          ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _trail.length,
            separatorBuilder: (_, _) =>
                const Icon(Icons.chevron_right, size: 16),
            itemBuilder: (context, index) {
              final isCurrent = index == _trail.length - 1;
              return TextButton(
                onPressed: (isCurrent || _loading) ? null : () => _goTo(index),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    _trail[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isCurrent
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  /// 目标提示：合法时显示将移动到的路径，非法时就地给出原因。
  Widget _targetHint(String? issue) {
    final theme = Theme.of(context);
    final invalid = issue != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            invalid ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: invalid
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              issue ?? context.l10n.folderPickerWillMoveTo(_path),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: invalid ? theme.colorScheme.error : theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loading ? null : _loadChildren,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_children.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.folderPickerNoSubfolders),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _children.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final folder = _children[index];
        final blocked = widget.blockedDocumentIds.contains(folder.documentId);
        final folderState = blocked
            ? FolderIconState.locked
            : FolderIconState.closed;
        return ListTile(
          enabled: !blocked,
          leading: FileCategoryIcon(
            category: FileCategory.folder,
            folderState: folderState,
            color: fileCategoryColor(
              context,
              FileCategory.folder,
              folderState: folderState,
            ),
          ),
          title: Text(
            folder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: blocked ? Text(context.l10n.folderPickerBlocked) : null,
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: (_loading || blocked) ? null : () => _open(folder),
        );
      },
    );
  }
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
    title: Text(context.l10n.batchRenameTitle),
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
                  decoration: InputDecoration(
                    labelText: context.l10n.renamePrefix,
                  ),
                  onChanged: (_) => _update(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _suffix,
                  decoration: InputDecoration(
                    labelText: context.l10n.renameSuffix,
                  ),
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
                  decoration: InputDecoration(
                    labelText: context.l10n.renameFind,
                  ),
                  onChanged: (_) => _update(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _replaceTo,
                  decoration: InputDecoration(
                    labelText: context.l10n.renameReplace,
                  ),
                  onChanged: (_) => _update(),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(context.l10n.renameNumbering),
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
                Text(context.l10n.renameStartNumber),
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
          Text(
            context.l10n.renamePreviewHeader,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Flexible(
            child: SizedBox(
              height: 220,
              child: _previews.isEmpty
                  ? Center(child: Text(context.l10n.renamePreviewEmpty))
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
                                ? AppColors.success(context)
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
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed:
            _running ||
                _previews.isEmpty ||
                _previews.any((preview) => preview.error != null)
            ? null
            : _execute,
        child: Text(context.l10n.renameExecute),
      ),
    ],
  );
}

/// 批量任务逐项结果；失败项给出原因，部分成功不冒充全部成功。
void showBatchResult(BuildContext context, BatchJob job) {
  final kindLabel = switch (job.kind) {
    BatchKind.delete => context.l10n.batchKindDelete,
    BatchKind.move => context.l10n.batchKindMove,
    BatchKind.rename => context.l10n.batchKindRename,
  };
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$kindLabel · ${job.summary(context.l10n)}'),
      content: SizedBox(
        width: 400,
        height: 320,
        child: ListView.separated(
          itemCount: job.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = job.items[index];
            final (icon, color) = switch (item.status) {
              BatchItemStatus.pending => (
                Icons.schedule,
                AppColors.neutral(context),
              ),
              BatchItemStatus.success => (
                Icons.check_circle,
                AppColors.success(context),
              ),
              BatchItemStatus.failed => (
                Icons.error_outline,
                Theme.of(context).colorScheme.error,
              ),
              BatchItemStatus.copiedSourceKept => (
                Icons.warning_amber,
                AppColors.warning(context),
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
          child: Text(context.l10n.commonClose),
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
    final l10n = context.l10n;
    final rows = <(String, String)>[
      (l10n.commonName, entry.name),
      (l10n.commonLocation, location),
      (l10n.commonType, _entryTypeLabel(entry, l10n)),
      (
        l10n.commonSize,
        entry.isDirectory ? '—' : formatBytes(entry.size, l10n),
      ),
      (
        l10n.commonModifiedTime,
        entry.modifiedAt == null
            ? l10n.commonUnknown
            : _formatTime(entry.modifiedAt!),
      ),
    ];
    return AlertDialog(
      title: Text(l10n.detailsTitle),
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                        context,
                        l10n.commonDuration,
                        durationMs == null
                            ? l10n.commonUnknown
                            : formatDuration(
                                Duration(milliseconds: durationMs.toInt()),
                              ),
                      ),
                      _detailRow(
                        context,
                        l10n.commonDimensions,
                        width == null || height == null
                            ? l10n.commonUnknown
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
          child: Text(context.l10n.commonClose),
        ),
      ],
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
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
}

String _formatTime(DateTime time) {
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${time.year}/${pad(time.month)}/${pad(time.day)} '
      '${pad(time.hour)}:${pad(time.minute)}';
}

/// 详情页类型文案：分类本地化名称；提供方返回 MIME 时附在右侧便于排查。
String _entryTypeLabel(StorageEntry entry, AppLocalizations l10n) {
  final label = fileTypeInfo(entry.fileCategory, l10n).label;
  final mime = entry.mimeType;
  return mime == null || mime.isEmpty ? label : '$label · $mime';
}

/// 悬浮菜单中的单个操作。
class FabAction {
  const FabAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
}

/// 可展开悬浮按钮：点击主按钮后在**上方**逐个显示带标签的小按钮。
///
/// 展开后点击菜单以外的任意位置（列表空白、目录行、面包屑等）自动收起，
/// 且不拦截该次点击。收起时子按钮透明且不接收点击，主按钮位置保持不变；
/// [enabled] 为 false 时主按钮与子按钮均不可点。
class ExpandableActionFab extends StatefulWidget {
  const ExpandableActionFab({
    required this.actions,
    required this.tooltip,
    this.enabled = true,
    super.key,
  });

  final List<FabAction> actions;
  final bool enabled;
  final String tooltip;

  @override
  State<ExpandableActionFab> createState() => _ExpandableActionFabState();
}

class _ExpandableActionFabState extends State<ExpandableActionFab> {
  static const _duration = Duration(milliseconds: 180);
  bool _open = false;

  void _toggle() {
    if (!widget.enabled) return;
    setState(() => _open = !_open);
  }

  void _run(FabAction action) {
    setState(() => _open = false);
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    // 展开时点击菜单以外的任意位置（列表空白、目录行、面包屑等）自动收起。
    // TapRegion 只监听外部点击而不消费事件，被点中的控件仍会正常响应。
    onTapOutside: (_) {
      if (_open) setState(() => _open = false);
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final action in widget.actions)
          _MiniAction(
            action: action,
            visible: _open,
            enabled: widget.enabled,
            duration: _duration,
            onPressed: () => _run(action),
          ),
        FloatingActionButton(
          heroTag: 'home-actions-fab',
          tooltip: widget.tooltip,
          onPressed: widget.enabled ? _toggle : null,
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: _duration,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    ),
  );
}

/// 展开项：右侧小按钮 + 左侧文字标签；收起时透明且不接收点击。
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.action,
    required this.visible,
    required this.enabled,
    required this.duration,
    required this.onPressed,
  });

  final FabAction action;
  final bool visible;
  final bool enabled;
  final Duration duration;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.3),
      duration: duration,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          // 整个展开项（含标签）都可点，便于单手操作。
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(action.label),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.small(
                  heroTag: null,
                  tooltip: action.label,
                  onPressed: enabled ? onPressed : null,
                  child: action.icon,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
