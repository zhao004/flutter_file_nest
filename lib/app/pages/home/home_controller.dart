import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/archive_models.dart';
import '../../models/storage_entry.dart';
import '../../services/archive_service.dart';
import '../../services/recording_service.dart';
import '../../services/saf_storage.dart';
import '../../services/vault_store.dart';

/// 保持当前目录导航和文件快照；所有修改完成后重新向 SAF 读取。
class HomeController extends GetxController {
  HomeController({
    required this.storage,
    required this.store,
    required this.archive,
  });
  final StorageGateway storage;
  final VaultStore store;
  final ArchiveGateway archive;
  late final recordings = RecordingService(storage, store);
  final folders = <StorageEntry>[].obs;
  final entries = <StorageEntry>[].obs;
  final pending = <RecordingJob>[].obs;
  final preferences = const VaultPreferences().obs;
  final busy = false.obs;
  final error = RxnString();
  final rootRequired = true.obs;

  StorageEntry? get current => folders.lastOrNull;
  bool get canGoBack => folders.length > 1;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  Future<void> initialize() => _run(() async {
    preferences.value = await store.loadPreferences();
    pending.assignAll(await store.pendingJobs());
    final uri = preferences.value.rootUri;
    if (uri != null) {
      folders.assignAll([await storage.validateRoot(uri)]);
      rootRequired.value = false;
      await _load();
    }
  });

  Future<void> pickRoot() => _run(() async {
    final root = await storage.pickRoot();
    if (root == null) return;
    final next = preferences.value.copyWith(rootUri: root.rootUri);
    await store.savePreferences(next);
    preferences.value = next;
    folders.assignAll([root]);
    rootRequired.value = false;
    await _load();
  });

  @override
  Future<void> refresh() => _run(() async {
    pending.assignAll(await store.pendingJobs());
    if (current == null) return;
    final StorageEntry root;
    try {
      root = await storage.validateRoot(current!.rootUri);
    } catch (_) {
      rootRequired.value = true;
      entries.clear();
      rethrow;
    }
    folders[0] = root;
    rootRequired.value = false;
    await _load();
  });

  Future<void> enter(StorageEntry folder) => _run(() async {
    final children = await storage.list(folder);
    folders.add(folder);
    entries.assignAll(
      sortEntries(
        children,
        preferences.value.sort,
        preferences.value.descending,
      ),
    );
  });

  Future<void> back() => goTo(folders.length - 2);
  Future<void> goTo(int index) => _run(() async {
    if (index < 0 || index >= folders.length) return;
    folders.removeRange(index + 1, folders.length);
    await _load();
  });

  Future<void> _load() async {
    entries.assignAll(
      sortEntries(
        await storage.list(current!),
        preferences.value.sort,
        preferences.value.descending,
      ),
    );
  }

  Future<void> setSort(EntrySort sort, bool descending) => _run(() async {
    final next = preferences.value.copyWith(sort: sort, descending: descending);
    await store.savePreferences(next);
    preferences.value = next;
    entries.assignAll(sortEntries(entries, sort, descending));
  });

  Future<void> setAudio(bool enabled) async {
    final next = preferences.value.copyWith(audioEnabled: enabled);
    await store.savePreferences(next);
    preferences.value = next;
  }

  Future<void> createFolder(String name) => _run(() async {
    final invalid = validateEntryName(name);
    if (invalid != null) {
      throw PlatformException(code: 'invalid_name', message: invalid);
    }
    final entry = await storage.createFolder(current!, name.trim());
    try {
      await store.recordCreated(entry.uri, DateTime.now());
    } catch (_) {
      /* 元数据可重建。 */
    }
    await _load();
  });

  Future<void> renameFolder(StorageEntry entry, String name) => _run(() async {
    final invalid = validateEntryName(name);
    if (invalid != null) {
      throw PlatformException(code: 'invalid_name', message: invalid);
    }
    await _protectPendingFolders(entry);
    await storage.renameFolder(current!, entry, name.trim());
    await _load();
  });

  Future<void> deleteEntry(StorageEntry entry) => _run(() async {
    await _protectPendingFolders(entry);
    try {
      await storage.delete(entry);
    } finally {
      await _load();
    }
  });

  Future<void> _protectPendingFolders(StorageEntry entry) async {
    if (!entry.isDirectory) return;
    pending.assignAll(await store.pendingJobs());
    // SAF 标识不保证包含祖先信息，恢复任务完成前保守保护整个根目录。
    if (pending.any((job) => job.rootUri == entry.rootUri)) {
      throw PlatformException(
        code: 'pending_recording',
        message: '此存储位置有待保存录像，请先保存或放弃录像，再改名或删除文件夹',
      );
    }
  }

  Future<void> openFile(StorageEntry entry) =>
      _run(() => storage.openFile(entry));

  /// 压缩单个条目到当前目录；成功或失败结果由界面提示。
  Future<ArchiveOutcome> zipEntry(StorageEntry entry) async {
    final folder = current;
    if (folder == null || folder.canCreate != true) {
      return const ArchiveOutcome.failure(
        ArchiveKind.zip,
        'read_only',
        '当前目录不可写入',
      );
    }
    return _finishArchive(
      await archive.zip(entries: [entry], targetFolder: folder),
    );
  }

  /// 解压 ZIP 到当前目录下的新文件夹；不覆盖已有项目。
  Future<ArchiveOutcome> extractEntry(StorageEntry entry) async {
    final folder = current;
    if (folder == null || folder.canCreate != true) {
      return const ArchiveOutcome.failure(
        ArchiveKind.extract,
        'read_only',
        '当前目录不可写入',
      );
    }
    return _finishArchive(
      await archive.extract(archive: entry, targetFolder: folder),
    );
  }

  /// 通过系统 Sharesheet 分享条目；文件夹先压缩为临时缓存 ZIP。
  Future<ShareOutcome> shareEntry(StorageEntry entry) => archive.share([entry]);

  Future<void> cancelArchive() => archive.cancelActive();

  /// 归档成功且产生了新条目时刷新列表；失败写入错误横幅，取消不报错。
  Future<ArchiveOutcome> _finishArchive(ArchiveOutcome outcome) async {
    if (outcome.ok) {
      if (outcome.target != null) await _load();
    } else if (!outcome.cancelled) {
      error.value = outcome.message ?? '归档任务失败';
    }
    return outcome;
  }

  Future<void> retryRecording(RecordingJob job) => _run(() async {
    await recordings.commit(job);
    pending.assignAll(await store.pendingJobs());
    if (current != null && !rootRequired.value) await _load();
  }, operationRoot: job.rootUri);

  Future<void> discardRecording(RecordingJob job) => _run(() async {
    await recordings.discard(job);
    pending.assignAll(await store.pendingJobs());
  });

  Future<void> _run(
    Future<void> Function() action, {
    String? operationRoot,
  }) async {
    if (busy.value) return;
    busy.value = true;
    error.value = null;
    try {
      await action();
    } catch (failure) {
      error.value = userError(failure);
      if (failure is PlatformException &&
          ['permission_denied', 'invalid_root'].contains(failure.code) &&
          (operationRoot == null || operationRoot == current?.rootUri)) {
        rootRequired.value = true;
        entries.clear();
      }
    } finally {
      busy.value = false;
    }
  }
}
