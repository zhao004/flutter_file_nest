import 'package:flutter/services.dart';

import '../models/storage_entry.dart';
import 'vault_store.dart';

/// 封装平台协议，测试通过替代此接口覆盖权限与文件失败状态。
abstract interface class StorageGateway {
  Future<StorageEntry?> pickRoot();
  Future<StorageEntry> validateRoot(String rootUri);
  Future<List<StorageEntry>> list(StorageEntry folder);
  Future<StorageEntry> createFolder(StorageEntry parent, String name);
  Future<StorageEntry> renameFolder(
    StorageEntry parent,
    StorageEntry entry,
    String name,
  );
  Future<DeletionImpact> deletionImpact(StorageEntry entry);
  Future<void> delete(StorageEntry entry);
  Future<StorageEntry> saveRecording(RecordingJob job);
  Future<void> forgetRecording(String id);
  Future<void> openFile(StorageEntry entry);
  Future<void> openAppSettings();
}

class DeletionImpact {
  const DeletionImpact(this.files, this.folders);
  final int files;
  final int folders;
}

class SafStorage implements StorageGateway {
  static const channel = MethodChannel('lens_vault/saf_storage');

  Map<String, Object> _entry(StorageEntry entry) => {
    'rootUri': entry.rootUri,
    'documentId': entry.documentId,
  };
  Map<String, Object> _parent(StorageEntry entry) => {
    'rootUri': entry.rootUri,
    'parentDocumentId': entry.documentId,
  };

  Future<StorageEntry> _document(
    String method,
    Map<String, Object> args,
  ) async {
    final value = await channel.invokeMapMethod<Object?, Object?>(method, args);
    if (value == null) {
      throw PlatformException(code: 'invalid_response', message: '存储响应为空');
    }
    return StorageEntry.fromMap(value);
  }

  @override
  Future<StorageEntry?> pickRoot() async {
    final value = await channel.invokeMapMethod<Object?, Object?>('pickRoot');
    return value == null ? null : StorageEntry.fromMap(value);
  }

  @override
  Future<StorageEntry> validateRoot(String rootUri) =>
      _document('validateRoot', {'rootUri': rootUri});

  @override
  Future<List<StorageEntry>> list(StorageEntry folder) async {
    final result = await channel.invokeListMethod<Object?>(
      'listChildren',
      _parent(folder),
    );
    return (result ?? [])
        .map((value) => StorageEntry.fromMap(value as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<StorageEntry> createFolder(StorageEntry parent, String name) =>
      _document('createFolder', {..._parent(parent), 'name': name});

  @override
  Future<StorageEntry> renameFolder(
    StorageEntry parent,
    StorageEntry entry,
    String name,
  ) => _document('renameFolder', {
    ..._entry(entry),
    'parentDocumentId': parent.documentId,
    'name': name,
  });

  @override
  Future<DeletionImpact> deletionImpact(StorageEntry entry) async {
    final result = await channel.invokeMapMethod<String, Object?>(
      'getDeletionImpact',
      _entry(entry),
    );
    return DeletionImpact(
      (result!['fileCount'] as num).toInt(),
      (result['folderCount'] as num).toInt(),
    );
  }

  @override
  Future<void> delete(StorageEntry entry) =>
      channel.invokeMethod<void>('deleteEntry', _entry(entry));

  @override
  Future<StorageEntry> saveRecording(RecordingJob job) =>
      _document('saveRecording', {
        'rootUri': job.rootUri,
        'parentDocumentId': job.parentId,
        'sourcePath': job.sourcePath,
        'fileName': job.fileName,
        'operationId': job.id,
      });

  @override
  Future<void> forgetRecording(String id) =>
      channel.invokeMethod<void>('forgetRecording', {'operationId': id});

  @override
  Future<void> openFile(StorageEntry entry) =>
      channel.invokeMethod<void>('openFile', _entry(entry));

  @override
  Future<void> openAppSettings() =>
      channel.invokeMethod<void>('openAppSettings');
}

String userError(Object error) {
  if (error is PlatformException) return error.message ?? '文件操作失败';
  return '操作未完成，请重试';
}
