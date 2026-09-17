import 'package:flutter/services.dart';
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
  canRename: directory,
  size: size,
  modifiedAt: modified,
  mimeType: mime,
);

class MemoryStore implements VaultStore {
  VaultPreferences value = const VaultPreferences();
  final jobs = <RecordingJob>[];
  final presets = <CameraPreset>[];
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
  Future<void> recordCreated(String uri, DateTime time) async {}

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
  String? deniedSaveRoot;
  int saves = 0;
  int deletes = 0;
  int creates = 0;
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
  Future<List<StorageEntry>> list(StorageEntry folder) async =>
      List.of(contents[folder.documentId] ?? []);
  @override
  Future<StorageEntry> createFolder(StorageEntry parent, String name) async {
    creates++;
    final created = entry(name, directory: true);
    contents.putIfAbsent(parent.documentId, () => []).add(created);
    return created;
  }

  @override
  Future<StorageEntry> renameFolder(
    StorageEntry parent,
    StorageEntry target,
    String name,
  ) async {
    final renamed = entry(name, directory: true);
    contents[parent.documentId]!.removeWhere(
      (value) => value.uri == target.uri,
    );
    contents[parent.documentId]!.add(renamed);
    return renamed;
  }

  @override
  Future<DeletionImpact> deletionImpact(StorageEntry entry) async =>
      const DeletionImpact(1, 2);
  @override
  Future<void> delete(StorageEntry entry) async {
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
}
