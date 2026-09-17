import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/archive_models.dart';
import '../models/storage_entry.dart';

/// 归档与分享的平台契约；测试通过替代实现覆盖任务失败与取消状态。
abstract interface class ArchiveGateway {
  /// 当前前台任务；null 表示空闲。同一时间只允许一个归档任务。
  Rxn<ArchiveTaskState> get active;

  /// 压缩条目到目标文件夹；输出不会包含压缩包自身。
  Future<ArchiveOutcome> zip({
    required List<StorageEntry> entries,
    required StorageEntry targetFolder,
    String? fileName,
  });

  /// 解压压缩包到目标文件夹下的新文件夹；不覆盖已有项目。
  Future<ArchiveOutcome> extract({
    required StorageEntry archive,
    required StorageEntry targetFolder,
    String? folderName,
  });

  /// 通过系统 Sharesheet 分享条目；文件夹会先压缩为临时缓存 ZIP。
  Future<ShareOutcome> share(List<StorageEntry> entries);

  /// 取消当前任务；没有任务或已进入终态时无效果。
  Future<void> cancelActive();
}

/// 归档平台通道封装。
///
/// - MethodChannel 传递操作 ID、条目标识与结果；大文件数据不经通道。
/// - EventChannel 回报进度；同一时间仅一个任务，避免抢占用户注意力。
/// - 分享缓存按原生侧生命周期策略延迟清理，启动时顺带执行一次。
class ArchiveService implements ArchiveGateway {
  ArchiveService() {
    // 应用级服务，订阅随进程存活；进度事件只更新当前任务。
    _events.receiveBroadcastStream().listen(_onEvent);
    unawaited(_cleanup());
  }

  static const _channel = MethodChannel('lens_vault/archive');
  static const _events = EventChannel('lens_vault/archive_events');

  @override
  final active = Rxn<ArchiveTaskState>();

  int _counter = 0;

  String _nextId() =>
      'archive-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  void _onEvent(Object? event) {
    if (event is! Map<Object?, Object?>) return;
    final operationId = event['operationId'] as String?;
    if (operationId == null) return;
    final current = active.value;
    if (current == null || current.operationId != operationId) return;
    active.value = ArchiveTaskState.fromEvent(operationId, current.kind, event);
  }

  Future<void> _cleanup() async {
    try {
      await _channel.invokeMethod<int>('cleanupShareCache');
    } catch (_) {
      /* 清理失败不影响新任务。 */
    }
  }

  @override
  Future<ArchiveOutcome> zip({
    required List<StorageEntry> entries,
    required StorageEntry targetFolder,
    String? fileName,
  }) async {
    if (entries.isEmpty) {
      return const ArchiveOutcome.failure(
        ArchiveKind.zip,
        'invalid_argument',
        '没有可压缩的条目',
      );
    }
    final name = fileName ?? defaultZipFileName(entries.first.name);
    return _runZip(name: name, entries: entries, targetFolder: targetFolder);
  }

  Future<ArchiveOutcome> _runZip({
    required String name,
    required List<StorageEntry> entries,
    required StorageEntry targetFolder,
  }) async {
    if (active.value != null) {
      return const ArchiveOutcome.failure(
        ArchiveKind.zip,
        'busy',
        '已有归档任务在进行，请等待完成或取消',
      );
    }
    final operationId = _nextId();
    active.value = ArchiveTaskState(
      operationId: operationId,
      kind: ArchiveKind.zip,
      stage: ArchiveStage.scanning,
      canCancel: true,
    );
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('zip', {
        'operationId': operationId,
        'rootUri': targetFolder.rootUri,
        'targetDocumentId': targetFolder.documentId,
        'fileName': name,
        'entries': [for (final entry in entries) _entryArgument(entry)],
      });
      if (result == null) {
        return const ArchiveOutcome.failure(
          ArchiveKind.zip,
          'invalid_response',
          '归档响应为空',
        );
      }
      if (result['cancelled'] == true) {
        return ArchiveOutcome.cancelled(ArchiveKind.zip, operationId);
      }
      final target = _targetEntry(result);
      return ArchiveOutcome(
        kind: ArchiveKind.zip,
        operationId: operationId,
        target: target,
        items: (result['items'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException catch (error) {
      return ArchiveOutcome.failure(
        ArchiveKind.zip,
        error.code,
        error.message ?? '压缩失败，请重试',
      );
    } finally {
      if (active.value?.operationId == operationId) active.value = null;
    }
  }

  @override
  Future<ArchiveOutcome> extract({
    required StorageEntry archive,
    required StorageEntry targetFolder,
    String? folderName,
  }) async {
    if (active.value != null) {
      return const ArchiveOutcome.failure(
        ArchiveKind.extract,
        'busy',
        '已有归档任务在进行，请等待完成或取消',
      );
    }
    final operationId = _nextId();
    active.value = ArchiveTaskState(
      operationId: operationId,
      kind: ArchiveKind.extract,
      stage: ArchiveStage.scanning,
      canCancel: true,
    );
    try {
      final result = await _channel
          .invokeMapMethod<Object?, Object?>('extract', {
            'operationId': operationId,
            'rootUri': archive.rootUri,
            'archiveDocumentId': archive.documentId,
            'targetParentDocumentId': targetFolder.documentId,
            'folderName': folderName ?? defaultExtractFolderName(archive.name),
          });
      if (result == null) {
        return const ArchiveOutcome.failure(
          ArchiveKind.extract,
          'invalid_response',
          '解压响应为空',
        );
      }
      if (result['cancelled'] == true) {
        return ArchiveOutcome.cancelled(ArchiveKind.extract, operationId);
      }
      return ArchiveOutcome(
        kind: ArchiveKind.extract,
        operationId: operationId,
        target: _targetEntry(result),
        extracted: (result['extracted'] as num?)?.toInt() ?? 0,
        skipped: (result['skipped'] as num?)?.toInt() ?? 0,
        failed: (result['failed'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException catch (error) {
      return ArchiveOutcome.failure(
        ArchiveKind.extract,
        error.code,
        error.message ?? '解压失败，请检查压缩包是否完整',
      );
    } finally {
      if (active.value?.operationId == operationId) active.value = null;
    }
  }

  @override
  Future<ShareOutcome> share(List<StorageEntry> entries) async {
    if (entries.isEmpty) {
      return const ShareOutcome.failure('invalid_argument', '没有可分享的内容');
    }
    if (active.value != null) {
      return const ShareOutcome.failure('busy', '已有归档任务在进行，请稍后再分享');
    }
    final documentUris = <String>[
      for (final entry in entries)
        if (!entry.isDirectory) entry.uri,
    ];
    final mimeTypes = <String>[
      for (final entry in entries)
        if (!entry.isDirectory) entry.mimeType ?? 'application/octet-stream',
    ];
    final cachePaths = <String>[];
    for (final entry in entries) {
      if (!entry.isDirectory) continue;
      final prepared = await _prepareFolderZip(entry);
      if (prepared.cancelled) return const ShareOutcome.cancelled();
      if (!prepared.ok) {
        return ShareOutcome.failure(prepared.code, prepared.message);
      }
      final path = prepared.path;
      if (path == null) {
        return const ShareOutcome.failure('invalid_response', '分享缓存准备失败');
      }
      cachePaths.add(path);
      mimeTypes.add('application/zip');
    }
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('share', {
        'documentUris': documentUris,
        'cachePaths': cachePaths,
        'mimeTypes': mimeTypes,
        'title': '分享 ${entries.first.name}',
      });
      if (result == null) {
        return const ShareOutcome.failure('invalid_response', '分享响应为空');
      }
      if (result['result'] == 'no_app') return const ShareOutcome.noApp();
      return const ShareOutcome.shared();
    } on PlatformException catch (error) {
      return ShareOutcome.failure(error.code, error.message ?? '分享失败，请重试');
    }
  }

  /// 文件夹先写入应用私有分享缓存，再经 FileProvider 受限分享。
  Future<_PreparedZip> _prepareFolderZip(StorageEntry folder) async {
    final operationId = _nextId();
    active.value = ArchiveTaskState(
      operationId: operationId,
      kind: ArchiveKind.share,
      stage: ArchiveStage.scanning,
      canCancel: true,
    );
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'cacheZip',
        {
          'operationId': operationId,
          'rootUri': folder.rootUri,
          'fileName': defaultZipFileName(folder.name),
          'entries': [_entryArgument(folder)],
        },
      );
      if (result == null) {
        return const _PreparedZip.failure('invalid_response', '分享缓存准备失败');
      }
      if (result['cancelled'] == true) return const _PreparedZip.cancelled();
      return _PreparedZip.done(result['path'] as String?);
    } on PlatformException catch (error) {
      return _PreparedZip.failure(error.code, error.message ?? '分享缓存准备失败');
    } finally {
      if (active.value?.operationId == operationId) active.value = null;
    }
  }

  @override
  Future<void> cancelActive() async {
    final current = active.value;
    if (current == null || current.terminal) return;
    try {
      await _channel.invokeMethod<bool>('cancel', {
        'operationId': current.operationId,
      });
    } catch (_) {
      /* 取消失败时任务继续执行，终态由结果决定。 */
    }
  }

  Map<String, Object> _entryArgument(StorageEntry entry) => {
    'documentId': entry.documentId,
    'name': entry.name,
    'isDirectory': entry.isDirectory,
  };

  StorageEntry? _targetEntry(Map<Object?, Object?> result) {
    final target = result['target'];
    if (target is! Map<Object?, Object?>) return null;
    return StorageEntry.fromMap(target);
  }
}

/// 分享缓存 ZIP 的准备结果。
class _PreparedZip {
  const _PreparedZip.done(this.path)
    : cancelled = false,
      code = null,
      message = null;

  const _PreparedZip.cancelled()
    : path = null,
      cancelled = true,
      code = null,
      message = null;

  const _PreparedZip.failure(this.code, this.message)
    : path = null,
      cancelled = false;

  final String? path;
  final bool cancelled;
  final String? code;
  final String? message;

  bool get ok => !cancelled && code == null;
}
