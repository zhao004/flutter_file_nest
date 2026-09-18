import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_lens_vault/app/models/batch_models.dart';
import 'package:flutter_lens_vault/app/models/incoming_share.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/services/incoming_share_service.dart';
import 'package:flutter_lens_vault/app/services/saf_storage.dart';
import 'package:flutter_lens_vault/app/services/thumbnail_service.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';
import 'package:flutter_lens_vault/app/theme/theme_store.dart';

/// 可手动推送事件的外部分享来源。
class FakeIncomingShares implements IncomingShareGateway {
  final _controller = StreamController<List<IncomingShare>>.broadcast();

  @override
  Stream<List<IncomingShare>> get shares => _controller.stream;

  void emit(List<IncomingShare> shares) => _controller.add(shares);

  Future<void> close() => _controller.close();
}

const root = StorageEntry(
  rootUri: 'content://test/tree/root',
  documentId: 'root',
  uri: 'content://test/tree/root/document/root',
  name: '测试目录',
  isDirectory: true,
  canCreate: true,
);

StorageEntry entry(
  String name, {
  bool directory = false,
  int? size,
  DateTime? modified,
  String? mime,
  bool? canWrite,
}) => StorageEntry(
  rootUri: root.rootUri,
  documentId: name,
  uri: '${root.uri}/$name',
  name: name,
  isDirectory: directory,
  canCreate: directory,
  canDelete: true,
  canRename: true,
  canWrite: canWrite ?? !directory,
  size: size,
  modifiedAt: modified,
  mimeType: mime,
);

/// 测试用 MIME 推断；仅覆盖常见扩展名，其余返回 null 由分类按扩展名判定。
String? _mimeFromName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return null;
  return switch (name.substring(dot + 1).toLowerCase()) {
    'txt' => 'text/plain',
    'md' => 'text/markdown',
    'json' => 'application/json',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    _ => null,
  };
}

class MemoryStore implements VaultStore {
  VaultPreferences value = const VaultPreferences();
  final created = <String, DateTime>{};
  final playback = <String, Duration>{};
  @override
  Future<VaultPreferences> loadPreferences() async => value;
  @override
  Future<void> savePreferences(VaultPreferences value) async {
    this.value = value;
  }

  @override
  Future<void> recordCreated(String uri, DateTime time) async {
    created[uri] = time;
  }

  @override
  Future<Map<String, DateTime>> createdTimes(Iterable<String> uris) async => {
    for (final uri in uris.toSet())
      if (created[uri] != null) uri: created[uri]!,
  };

  @override
  Future<Duration?> playbackPosition(String uri) async => playback[uri];

  @override
  Future<void> savePlaybackPosition(
    String uri,
    Duration position, {
    Duration? duration,
  }) async {
    playback[uri] = position;
  }
}

/// 内存主题存储；可注入初值、统计保存次数并模拟保存失败。
class MemoryThemeStore implements ThemeStore {
  ThemePreferences value = const ThemePreferences();
  int saves = 0;
  bool failSaves = false;

  @override
  Future<ThemePreferences> load() async => value;

  @override
  Future<void> save(ThemePreferences value) async {
    if (failSaves) throw StateError('save failed');
    this.value = value;
    saves++;
  }
}

/// 可注入的缩略图网关；记录加载与取消次数，便于断言重载与销毁行为。
class FakeThumbnails implements ThumbnailGateway {
  final loads = <String>[];
  final cancels = <String>[];
  int clears = 0;

  /// 默认返回 null（占位图标），避免测试中解码无效图片。
  Uint8List? result;

  @override
  Future<Uint8List?> load(
    StorageEntry entry, {
    int maxDimension = thumbnailDimension,
  }) async {
    loads.add(entry.uri);
    return result;
  }

  @override
  void cancel(StorageEntry entry, {int maxDimension = thumbnailDimension}) {
    cancels.add(entry.uri);
  }

  @override
  void clearPending() {
    clears++;
  }
}

class FakeStorage implements StorageGateway {
  final contents = <String, List<StorageEntry>>{'root': []};
  StorageEntry? selected = root;
  bool permissionDenied = false;
  bool failSourceDelete = false;
  Uint8List? thumbnailResult = Uint8List.fromList([9, 9, 9]);

  /// 受限读取默认返回一段 UTF-8 文本，便于文本类预览测试。
  Uint8List readDocumentLimitedResult = Uint8List.fromList(
    utf8.encode('hello\nworld'),
  );
  bool readDocumentTruncated = false;
  final failingFolders = <String>{};
  final failDeleteNames = <String>{};
  List<StorageEntry> pickImportResults = [];
  List<StorageEntry> importResults = [];
  final importDocumentCalls = <String>[];
  StorageEntry? takePhotoResult;
  StorageEntry? takeVideoResult;
  final imports = <String>[];

  /// 非空时模拟导入失败：先写入已成功项，再抛出，用于覆盖部分失败路径。
  PlatformException? pickImportFailure;

  /// 非空时模拟外部分享保存失败。
  PlatformException? importDocumentsFailure;
  int photoCaptures = 0;
  int videoCaptures = 0;
  int deletes = 0;
  int creates = 0;
  int fileCreates = 0;
  int writes = 0;
  final writtenBytes = <String, Uint8List>{};
  final moves = <String>[];
  final renames = <String>[];
  int thumbnailLoads = 0;
  @override
  Future<StorageEntry?> pickRoot() async => selected;
  @override
  Future<StorageEntry> validateRoot(String uri) async {
    if (permissionDenied) {
      throw PlatformException(code: 'permission_denied', message: '目录访问权限已失效');
    }
    return root;
  }

  @override
  Future<List<StorageEntry>> list(StorageEntry folder) async {
    if (failingFolders.contains(folder.documentId)) {
      throw PlatformException(code: 'unavailable', message: '无法读取存储位置');
    }
    return List.of(contents[folder.documentId] ?? []);
  }

  @override
  Future<StorageEntry> createFolder(StorageEntry parent, String name) async {
    creates++;
    final created = entry(name, directory: true);
    contents.putIfAbsent(parent.documentId, () => []).add(created);
    return created;
  }

  @override
  Future<StorageEntry> createFile(StorageEntry parent, String name) async {
    fileCreates++;
    final created = entry(name, mime: _mimeFromName(name));
    contents.putIfAbsent(parent.documentId, () => []).add(created);
    return created;
  }

  @override
  Future<StorageEntry> renameEntry(
    StorageEntry parent,
    StorageEntry target,
    String name,
  ) async {
    renames.add('${target.name}→$name');
    final list = contents[parent.documentId]!;
    final index = list.indexWhere((value) => value.uri == target.uri);
    final renamed = entry(
      name,
      directory: target.isDirectory,
      size: target.size,
      modified: target.modifiedAt,
      mime: target.mimeType,
    );
    if (index >= 0) list[index] = renamed;
    return renamed;
  }

  @override
  Future<MoveResult> move(
    StorageEntry parent,
    StorageEntry source,
    StorageEntry targetFolder,
  ) async {
    moves.add(source.name);
    // 回退复制路径中源删除失败时，源保留在原位置。
    if (!failSourceDelete) {
      contents[parent.documentId]!.removeWhere(
        (value) => value.uri == source.uri,
      );
    }
    final moved = StorageEntry(
      rootUri: source.rootUri,
      documentId: source.documentId,
      uri: source.uri,
      name: source.name,
      isDirectory: source.isDirectory,
      mimeType: source.mimeType,
      size: source.size,
      modifiedAt: source.modifiedAt,
      canCreate: source.canCreate,
      canRename: source.canRename,
      canDelete: source.canDelete,
      canWrite: source.canWrite,
    );
    contents.putIfAbsent(targetFolder.documentId, () => []).add(moved);
    return MoveResult(moved, sourceDeleted: !failSourceDelete);
  }

  @override
  Future<Uint8List?> thumbnail(
    StorageEntry target, {
    int maxDimension = thumbnailDimension,
  }) async {
    thumbnailLoads++;
    return thumbnailResult;
  }

  @override
  Future<Map<String, Object?>> videoDetails(StorageEntry target) async => {
    'durationMs': 1234,
    'width': 640,
    'height': 480,
  };

  @override
  Future<DeletionImpact> deletionImpact(StorageEntry entry) async =>
      const DeletionImpact(1, 2);
  @override
  Future<void> delete(StorageEntry entry) async {
    if (failDeleteNames.contains(entry.name)) {
      throw PlatformException(
        code: 'delete_failed',
        message: '无法删除 ${entry.name}',
      );
    }
    deletes++;
    for (final items in contents.values) {
      items.removeWhere((value) => value.uri == entry.uri);
    }
  }

  @override
  Future<void> openFile(StorageEntry entry) async {}
  @override
  Future<void> openAppSettings() async {}

  @override
  Future<List<StorageEntry>> pickImport(
    List<String> mimeTypes,
    StorageEntry targetFolder,
  ) async {
    imports.add(mimeTypes.join(','));
    for (final entry in pickImportResults) {
      contents.putIfAbsent(targetFolder.documentId, () => []).add(entry);
    }
    final failure = pickImportFailure;
    if (failure != null) throw failure;
    return List.of(pickImportResults);
  }

  @override
  Future<List<StorageEntry>> importDocuments(
    List<String> sourceUris,
    StorageEntry targetFolder,
  ) async {
    importDocumentCalls.addAll(sourceUris);
    for (final entry in importResults) {
      contents.putIfAbsent(targetFolder.documentId, () => []).add(entry);
    }
    final failure = importDocumentsFailure;
    if (failure != null) throw failure;
    return List.of(importResults);
  }

  @override
  Future<StorageEntry?> takePhoto(StorageEntry targetFolder) async {
    photoCaptures++;
    final result = takePhotoResult;
    if (result != null) {
      contents.putIfAbsent(targetFolder.documentId, () => []).add(result);
    }
    return result;
  }

  @override
  Future<StorageEntry?> takeVideo(StorageEntry targetFolder) async {
    videoCaptures++;
    final result = takeVideoResult;
    if (result != null) {
      contents.putIfAbsent(targetFolder.documentId, () => []).add(result);
    }
    return result;
  }

  @override
  Future<Uint8List?> readDocument(StorageEntry entry) async =>
      Uint8List.fromList(const [1, 2, 3]);

  @override
  Future<DocumentBytes> readDocumentLimited(
    StorageEntry entry, {
    required int maxBytes,
  }) async => DocumentBytes(
    readDocumentLimitedResult,
    truncated: readDocumentTruncated,
  );

  @override
  Future<StorageEntry> writeDocument(
    StorageEntry entry,
    Uint8List bytes,
  ) async {
    writes++;
    writtenBytes[entry.uri] = bytes;
    for (final items in contents.values) {
      final index = items.indexWhere((value) => value.uri == entry.uri);
      if (index < 0) continue;
      final updated = StorageEntry(
        rootUri: entry.rootUri,
        documentId: entry.documentId,
        uri: entry.uri,
        name: entry.name,
        isDirectory: false,
        mimeType: entry.mimeType,
        size: bytes.length,
        modifiedAt: DateTime.now(),
        canCreate: entry.canCreate,
        canRename: entry.canRename,
        canDelete: entry.canDelete,
        canWrite: entry.canWrite,
      );
      items[index] = updated;
      return updated;
    }
    return entry;
  }

  @override
  Future<Map<String, Object?>> pdfInfo(StorageEntry entry) async => const {
    'pageCount': 3,
  };

  @override
  Future<Uint8List?> pdfPage(StorageEntry entry, {required int page}) async =>
      Uint8List.fromList(const [4, 5, 6]);
}
