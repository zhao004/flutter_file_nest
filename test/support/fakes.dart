import 'package:flutter/services.dart';
import 'package:flutter_lens_vault/app/models/batch_models.dart';
import 'package:flutter_lens_vault/app/models/camera_presets.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/services/saf_storage.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';

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
}) => StorageEntry(
  rootUri: root.rootUri,
  documentId: name,
  uri: '${root.uri}/$name',
  name: name,
  isDirectory: directory,
  canCreate: directory,
  canDelete: true,
  canRename: true,
  size: size,
  modifiedAt: modified,
  mimeType: mime,
);

class MemoryStore implements VaultStore {
  VaultPreferences value = const VaultPreferences();
  final jobs = <RecordingJob>[];
  final presets = <CameraPreset>[];
  final created = <String, DateTime>{};
  @override
  Future<VaultPreferences> loadPreferences() async => value;
  @override
  Future<void> savePreferences(VaultPreferences value) async {
    this.value = value;
  }

  @override
  Future<List<RecordingJob>> pendingJobs() async => List.of(jobs);
  @override
  Future<void> addJob(RecordingJob job) async {
    jobs.removeWhere((value) => value.id == job.id);
    jobs.add(job);
  }

  @override
  Future<void> removeJob(String id) async {
    jobs.removeWhere((job) => job.id == id);
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
  Future<List<CameraPreset>> userPresets() async {
    final sorted = List.of(presets)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  @override
  Future<void> savePreset(CameraPreset preset) async {
    presets.removeWhere((value) => value.id == preset.id);
    presets.add(preset);
  }

  @override
  Future<void> deletePreset(String id) async {
    presets.removeWhere((value) => value.id == id);
  }
}

class FakeStorage implements StorageGateway {
  final contents = <String, List<StorageEntry>>{'root': []};
  StorageEntry? selected = root;
  bool permissionDenied = false;
  bool failSave = false;
  bool failSourceDelete = false;
  Uint8List? thumbnailResult = Uint8List.fromList([9, 9, 9]);
  final failingFolders = <String>{};
  final failDeleteNames = <String>{};
  String? deniedSaveRoot;
  StorageEntry? pickImportResult;
  StorageEntry? takePhotoResult;
  StorageEntry? takeVideoResult;
  final imports = <String>[];
  int photoCaptures = 0;
  int videoCaptures = 0;
  int saves = 0;
  int deletes = 0;
  int creates = 0;
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
    );
    contents.putIfAbsent(targetFolder.documentId, () => []).add(moved);
    return MoveResult(moved, sourceDeleted: !failSourceDelete);
  }

  @override
  Future<Uint8List?> thumbnail(
    StorageEntry target, {
    int maxDimension = 256,
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
  Future<StorageEntry> saveRecording(RecordingJob job) async {
    saves++;
    if (deniedSaveRoot == job.rootUri) {
      throw PlatformException(code: 'permission_denied', message: '旧目录授权已失效');
    }
    if (failSave) {
      throw PlatformException(code: 'write_failed', message: '保存失败，视频已保留');
    }
    return entry(job.fileName, mime: 'video/mp4');
  }

  @override
  Future<void> forgetRecording(String id) async {}
  @override
  Future<void> openFile(StorageEntry entry) async {}
  @override
  Future<void> openAppSettings() async {}

  @override
  Future<StorageEntry?> pickImport(
    List<String> mimeTypes,
    StorageEntry targetFolder,
  ) async {
    imports.add(mimeTypes.join(','));
    final result = pickImportResult;
    if (result != null) {
      contents.putIfAbsent(targetFolder.documentId, () => []).add(result);
    }
    return result;
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
  Future<Map<String, Object?>> pdfInfo(StorageEntry entry) async => const {
    'pageCount': 3,
  };

  @override
  Future<Uint8List?> pdfPage(StorageEntry entry, {required int page}) async =>
      Uint8List.fromList(const [4, 5, 6]);
}
