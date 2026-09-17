/// 归档任务的状态与结果模型；字段与 Kotlin 侧事件协议对应。
library;

import 'storage_entry.dart';

/// 归档任务阶段。
enum ArchiveStage {
  /// 清单扫描/准备阶段。
  scanning,

  /// 处理阶段（压缩或写盘）。
  processing,

  /// 正常完成。
  completed,

  /// 用户取消。
  cancelled,

  /// 失败终态。
  failed,
}

/// 归档任务类型，决定界面文案。
enum ArchiveKind { zip, extract, share }

/// 归档任务的实时状态；由 EventChannel 进度事件更新。
class ArchiveTaskState {
  const ArchiveTaskState({
    required this.operationId,
    required this.kind,
    required this.stage,
    this.processedItems = 0,
    this.totalItems,
    this.processedBytes = 0,
    this.totalBytes,
    this.canCancel = false,
    this.message,
  });

  /// 从平台事件构造；未知阶段按处理中处理，缺省字段使用保守默认值。
  factory ArchiveTaskState.fromEvent(
    String operationId,
    ArchiveKind kind,
    Map<Object?, Object?> event,
  ) {
    final stage = switch (event['stage']) {
      'scanning' => ArchiveStage.scanning,
      'processing' => ArchiveStage.processing,
      'completed' => ArchiveStage.completed,
      'cancelled' => ArchiveStage.cancelled,
      'failed' => ArchiveStage.failed,
      _ => ArchiveStage.processing,
    };
    return ArchiveTaskState(
      operationId: operationId,
      kind: kind,
      stage: stage,
      processedItems: (event['processedItems'] as num?)?.toInt() ?? 0,
      totalItems: (event['totalItems'] as num?)?.toInt(),
      processedBytes: (event['processedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (event['totalBytes'] as num?)?.toInt(),
      canCancel: event['canCancel'] == true,
      message: event['message'] as String?,
    );
  }

  final String operationId;
  final ArchiveKind kind;
  final ArchiveStage stage;
  final int processedItems;
  final int? totalItems;
  final int processedBytes;
  final int? totalBytes;
  final bool canCancel;
  final String? message;

  bool get terminal =>
      stage == ArchiveStage.completed ||
      stage == ArchiveStage.cancelled ||
      stage == ArchiveStage.failed;

  /// 已确定进度时返回 0..1，未知总量时返回 null（界面使用不定进度）。
  double? get fraction {
    final total = totalItems;
    if (total == null || total <= 0) return null;
    return (processedItems / total).clamp(0.0, 1.0);
  }

  /// 阶段文案；包含已处理项数时给出可观察的进度。
  String get label => switch (stage) {
    ArchiveStage.scanning => switch (kind) {
      ArchiveKind.zip => '正在准备压缩…',
      ArchiveKind.extract => '正在检查压缩包…',
      ArchiveKind.share => '正在准备分享…',
    },
    ArchiveStage.processing => switch (kind) {
      ArchiveKind.zip => '正在压缩：已处理 $processedItems 项',
      ArchiveKind.extract => '正在解压：已完成 $processedItems 项',
      ArchiveKind.share => '正在准备分享：已处理 $processedItems 项',
    },
    ArchiveStage.completed => '已完成',
    ArchiveStage.cancelled => '已取消',
    ArchiveStage.failed => message ?? '任务失败',
  };
}

/// 压缩/解压任务结果。
class ArchiveOutcome {
  const ArchiveOutcome({
    required this.kind,
    this.operationId,
    this.cancelled = false,
    this.code,
    this.message,
    this.target,
    this.items = 0,
    this.extracted = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  const ArchiveOutcome.cancelled(this.kind, this.operationId)
    : cancelled = true,
      code = null,
      message = null,
      target = null,
      items = 0,
      extracted = 0,
      skipped = 0,
      failed = 0;

  const ArchiveOutcome.failure(this.kind, this.code, this.message)
    : cancelled = false,
      operationId = null,
      target = null,
      items = 0,
      extracted = 0,
      skipped = 0,
      failed = 0;

  final ArchiveKind kind;
  final String? operationId;
  final bool cancelled;
  final String? code;
  final String? message;
  final StorageEntry? target;
  final int items;
  final int extracted;
  final int skipped;
  final int failed;

  bool get ok => !cancelled && code == null;

  /// 界面提示文案；部分成功（存在跳过项）必须显式说明。
  String get summary {
    if (cancelled) {
      return kind == ArchiveKind.extract ? '解压已取消' : '压缩已取消';
    }
    if (code != null) return message ?? '归档任务失败';
    return switch (kind) {
      ArchiveKind.zip => '已生成压缩包：${target?.name ?? '压缩包'}（$items 项）',
      ArchiveKind.extract =>
        skipped > 0
            ? '已解压 $extracted 项，跳过 $skipped 项'
            : '已解压 $extracted 项到 ${target?.name ?? '新文件夹'}',
      ArchiveKind.share => '分享内容已准备',
    };
  }
}

/// 系统分享结果。
class ShareOutcome {
  const ShareOutcome({this.cancelled = false, this.code, this.message});

  const ShareOutcome.shared() : cancelled = false, code = null, message = null;

  const ShareOutcome.noApp()
    : cancelled = false,
      code = 'no_app',
      message = null;

  const ShareOutcome.cancelled()
    : cancelled = true,
      code = null,
      message = null;

  const ShareOutcome.failure(this.code, this.message) : cancelled = false;

  final bool cancelled;
  final String? code;
  final String? message;

  bool get ok => !cancelled && code == null;

  String get summary {
    if (cancelled) return '分享已取消';
    return switch (code) {
      'no_app' => '未找到可接收分享的应用',
      null => '已打开系统分享',
      _ => message ?? '分享失败，请重试',
    };
  }
}

/// 压缩包默认名称：去掉原扩展名后追加 .zip（与原生规则一致）。
String defaultZipFileName(String sourceName) {
  final dot = sourceName.lastIndexOf('.');
  final base = dot > 0 ? sourceName.substring(0, dot) : sourceName;
  return '$base.zip';
}

/// 解压目标文件夹默认名称：去掉 .zip 扩展名（与原生规则一致）。
String defaultExtractFolderName(String archiveName) {
  final base = archiveName.toLowerCase().endsWith('.zip')
      ? archiveName.substring(0, archiveName.length - 4)
      : archiveName;
  final trimmed = base.trim();
  return trimmed.isEmpty ? '解压结果' : trimmed;
}

/// 是否为可尝试解压的 ZIP 文件。
bool looksLikeZip(StorageEntry entry) =>
    !entry.isDirectory &&
    (entry.mimeType == 'application/zip' ||
        entry.mimeType == 'application/x-zip-compressed' ||
        entry.name.toLowerCase().endsWith('.zip'));
