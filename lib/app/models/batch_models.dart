/// 批量文件操作模型：逐项结果、批量任务与批量重命名计划。
///
/// 批量操作遵循逐项报告原则：部分成功不冒充全部成功；失败项保留标识
/// 供重试，且重试仅处理未完成部分。
library;

import 'storage_entry.dart';

/// 批量任务类型。
enum BatchKind { delete, move, rename }

/// 单个条目在批量任务中的状态。
enum BatchItemStatus {
  /// 尚未执行。
  pending,

  /// 已完成。
  success,

  /// 执行失败，可重试。
  failed,

  /// 复制完成但源未删除（移动回退路径中源删除失败）。
  copiedSourceKept,
}

/// 批量任务中单个条目的结果；状态为失败时携带用户可读原因。
class BatchItemResult {
  BatchItemResult.pending(this.uri, this.name)
    : status = BatchItemStatus.pending,
      message = null;

  final String uri;
  final String name;
  BatchItemStatus status;

  /// 失败或补充说明；成功项为 null。
  String? message;

  bool get done => status != BatchItemStatus.pending;
}

/// 一次批量任务的聚合状态；执行过程中逐项更新并刷新界面。
class BatchJob {
  BatchJob(this.kind, this.items);
  final BatchKind kind;
  final List<BatchItemResult> items;

  int get total => items.length;
  int get doneCount => items.where((item) => item.done).length;
  int get successCount =>
      items.where((item) => item.status == BatchItemStatus.success).length;
  int get failedCount =>
      items.where((item) => item.status == BatchItemStatus.failed).length;
  int get keptSourceCount => items
      .where((item) => item.status == BatchItemStatus.copiedSourceKept)
      .length;

  /// 汇总文案；仅在所有条目到达终态后展示完整结果。
  String summary() {
    if (doneCount < total) return '$doneCount/$total';
    final parts = <String>['成功 $successCount'];
    if (failedCount > 0) parts.add('失败 $failedCount');
    if (keptSourceCount > 0) parts.add('源未删除 $keptSourceCount');
    return parts.join(' · ');
  }
}

/// 批量重命名计划；四类规则可叠加，预览通过 [previewNames] 生成。
class BatchRenamePlan {
  const BatchRenamePlan({
    this.prefix = '',
    this.suffix = '',
    this.replaceFrom = '',
    this.replaceTo = '',
    this.numbering = false,
    this.startNumber = 1,
    this.numberingWidth = 3,
  });

  /// 追加在名称前/后的文本。
  final String prefix;
  final String suffix;

  /// 文本替换；不区分大小写，替换原始名称中的全部出现。
  final String replaceFrom;
  final String replaceTo;

  /// 启用序号：丢弃原始主名，改为 前缀+序号+后缀。
  final bool numbering;
  final int startNumber;

  /// 序号补零宽度。
  final int numberingWidth;

  bool get empty =>
      prefix.isEmpty && suffix.isEmpty && replaceFrom.isEmpty && !numbering;

  /// 生成单个条目的新主名；文件默认保留扩展名，目录不拆分扩展名。
  String baseName(String name, {required bool isDirectory}) {
    var base = name;
    String extension = '';
    if (!isDirectory) {
      final dot = name.lastIndexOf('.');
      if (dot > 0) {
        extension = name.substring(dot);
        base = name.substring(0, dot);
      }
    }
    if (replaceFrom.isNotEmpty) {
      base = base.replaceAll(
        RegExp(RegExp.escape(replaceFrom), caseSensitive: false),
        replaceTo,
      );
    }
    return '$prefix$base$suffix$extension';
  }
}

/// 单个条目的重命名预览；error 非空表示该条目不可执行。
class RenamePreview {
  const RenamePreview(this.entry, this.name, this.error);
  final StorageEntry entry;
  final String name;

  /// 校验失败原因；null 表示可执行。
  final String? error;
}

/// 生成批量重命名预览并逐项校验；存在错误项时由界面禁止执行。
List<RenamePreview> previewRename(
  List<StorageEntry> entries,
  BatchRenamePlan plan,
) {
  final previews = <RenamePreview>[];
  final planned = <String, String>{};
  final existing = {for (final item in entries) item.name.toLowerCase()};
  for (final (index, item) in entries.indexed) {
    final name = plan.numbering
        ? _numberedName(plan, index, item)
        : plan.baseName(item.name, isDirectory: item.isDirectory);
    String? error = validateEntryName(name);
    final key = name.toLowerCase();
    if (error == null && planned.containsKey(key)) {
      error = '与 ${planned[key]} 重名';
    }
    if (error == null &&
        key != item.name.toLowerCase() &&
        existing.contains(key)) {
      error = '当前目录已存在同名项目';
    }
    planned[key] = item.name;
    previews.add(RenamePreview(item, name, error));
  }
  return previews;
}

String _numberedName(BatchRenamePlan plan, int index, StorageEntry item) {
  final extension = item.isDirectory ? '' : _extension(item.name);
  final number = (plan.startNumber + index).toString().padLeft(
    plan.numberingWidth,
    '0',
  );
  return '${plan.prefix}$number${plan.suffix}$extension';
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(dot) : '';
}

/// 移动单个条目的结果；回退复制路径中源删除失败时 [sourceDeleted] 为 false。
class MoveResult {
  const MoveResult(this.entry, {this.sourceDeleted = true});
  final StorageEntry entry;
  final bool sourceDeleted;
}
