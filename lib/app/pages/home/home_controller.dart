import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/archive_models.dart';
import '../../models/batch_models.dart';
import '../../models/incoming_share.dart';
import '../../models/storage_entry.dart';
import '../../services/archive_service.dart';
import '../../services/incoming_share_service.dart';
import '../../services/saf_storage.dart';
import '../../services/thumbnail_service.dart';
import '../../services/vault_store.dart';

/// 保持当前目录导航和文件快照；所有修改完成后重新向 SAF 读取。
///
/// 批量操作仅作用于当前目录快照中的条目：选择集合不会跨目录累积，
/// 因此父子项不会同时被选中；刷新后自动剔除已消失的选中项。
class HomeController extends GetxController {
  HomeController({
    required this.storage,
    required this.store,
    required this.archive,
    this.thumbnails = const NoThumbnails(),
    this.incoming,
  });
  final StorageGateway storage;
  final VaultStore store;
  final ArchiveGateway archive;
  final ThumbnailGateway thumbnails;
  final IncomingShareGateway? incoming;
  final folders = <StorageEntry>[].obs;
  final entries = <StorageEntry>[].obs;

  /// 来自其他应用、等待选择目标文件夹保存的文件。
  final incomingShares = <IncomingShare>[].obs;
  StreamSubscription<List<IncomingShare>>? _incomingSub;
  final preferences = const VaultPreferences().obs;
  final busy = false.obs;
  final error = RxnString();
  final rootRequired = true.obs;

  /// 创建时间元数据（可重建缓存）；键为条目 URI，仅包含本应用登记过的文件。
  final _createdTimes = <String, DateTime>{};

  // ---- 批量选择（P3B-01）----
  final selectionMode = false.obs;

  /// 已选中条目的 URI；仅限当前目录，刷新后剔除已不存在的选中项。
  final selected = RxSet<String>();

  /// 进行中或刚结束的批量任务；用于进度展示与逐项结果对话框。
  final batchJob = Rxn<BatchJob>();

  // ---- 搜索（P3B-05）----
  /// null 表示未进入搜索；非空时列表展示搜索结果。
  final searchQuery = RxnString();
  final searchResults = <StorageEntry>[].obs;
  final searchRecursive = false.obs;
  final searching = false.obs;
  final searchIncomplete = false.obs;
  final _searchLocations = <String, String>{};
  int _searchToken = 0;
  static const int _searchFlushSize = 20;

  StorageEntry? get current => folders.lastOrNull;
  bool get canGoBack => folders.length > 1;
  int get selectedCount => selected.length;

  /// 本应用登记的创建时间；外部文件无依据时保持未知。
  DateTime? createdAtOf(StorageEntry entry) => _createdTimes[entry.uri];

  /// 搜索结果的位置标注；用于结果列表展示“位置：xxx”。
  String? searchLocationOf(StorageEntry entry) => _searchLocations[entry.uri];

  @override
  void onInit() {
    super.onInit();
    startIncoming();
    initialize();
  }

  /// 订阅外部打开/分享事件；重复调用无副作用，测试也可直接调用。
  void startIncoming() {
    // 事件通道仅在真实运行时可用；缺失时静默忽略。
    _incomingSub ??= incoming?.shares.listen(
      incomingShares.addAll,
      onError: (_) {},
    );
  }

  @override
  void onClose() {
    _incomingSub?.cancel();
    super.onClose();
  }

  /// 放弃当前待保存的外部分享文件。
  void clearIncoming() => incomingShares.clear();

  Future<void> initialize() => _run(() async {
    preferences.value = await store.loadPreferences();
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
    // 目录已切换，丢弃上一目录尚未开始的缩略图请求。
    thumbnails.clearPending();
    folders.add(folder);
    _loadCreatedTimes(
      children,
      await store.createdTimes(children.map((value) => value.uri)),
    );
    entries.assignAll(
      sortEntries(
        children,
        preferences.value.sort,
        preferences.value.descending,
        createdAt: _createdTimes,
      ),
    );
    // 导航进入子目录后，旧目录的选择与搜索上下文失效。
    exitSelection();
    if (searchQuery.value != null) exitSearch();
  });

  Future<void> back() => goTo(folders.length - 2);
  Future<void> goTo(int index) => _run(() async {
    if (index < 0 || index >= folders.length) return;
    if (searchQuery.value != null) {
      _searchToken++;
      searchQuery.value = null;
      searchResults.clear();
      searching.value = false;
      searchIncomplete.value = false;
    }
    folders.removeRange(index + 1, folders.length);
    await _load(resetThumbnails: true);
  });

  /// 读取当前目录快照；[resetThumbnails] 为真时丢弃上一目录的缩略图排队请求。
  Future<void> _load({bool resetThumbnails = false}) async {
    if (current == null) return;
    final children = await storage.list(current!);
    if (resetThumbnails) thumbnails.clearPending();
    _loadCreatedTimes(
      children,
      await store.createdTimes(children.map((value) => value.uri)),
    );
    entries.assignAll(
      sortEntries(
        children,
        preferences.value.sort,
        preferences.value.descending,
        createdAt: _createdTimes,
      ),
    );
    // 刷新后剔除已不存在的选中项（P3B-01）。
    final existing = children.map((value) => value.uri).toSet();
    selected.retainAll(existing);
    if (selectionMode.value && selected.isEmpty) _exitSelectionOnly();
  }

  void _loadCreatedTimes(
    List<StorageEntry> children,
    Map<String, DateTime> loaded,
  ) {
    _createdTimes.removeWhere(
      (uri, _) => !children.any((value) => value.uri == uri),
    );
    _createdTimes.addAll(loaded);
  }

  Future<void> setSort(EntrySort sort, bool descending) => _run(() async {
    final next = preferences.value.copyWith(sort: sort, descending: descending);
    await store.savePreferences(next);
    preferences.value = next;
    // 创建时间依赖登记元数据，统一从存储刷新一次；其余排序在当前快照上重排。
    if (sort == EntrySort.created) {
      await _load();
    } else {
      entries.assignAll(
        sortEntries(entries, sort, descending, createdAt: _createdTimes),
      );
    }
  });

  Future<void> createFolder(String name) => _run(() async {
    final invalid = validateEntryName(name);
    if (invalid != null) {
      throw PlatformException(code: 'invalid_name', message: invalid);
    }
    final entry = await storage.createFolder(current!, name.trim());
    try {
      await store.recordCreated(entry.uri, DateTime.now());
      _createdTimes[entry.uri] = DateTime.now();
    } catch (_) {
      /* 元数据可重建。 */
    }
    await _load();
  });

  /// 在当前目录新建空文件；扩展名由用户输入决定，用于后续类型识别。
  Future<void> createFile(String name) => _run(() async {
    final invalid = validateEntryName(name);
    if (invalid != null) {
      throw PlatformException(code: 'invalid_name', message: invalid);
    }
    final entry = await storage.createFile(current!, name.trim());
    try {
      final now = DateTime.now();
      await store.recordCreated(entry.uri, now);
      _createdTimes[entry.uri] = now;
    } catch (_) {
      /* 元数据可重建。 */
    }
    await _load();
  });

  /// 重命名文件或文件夹（P3B-04 单文件入口）。
  Future<void> renameEntry(StorageEntry entry, String name) => _run(() async {
    final invalid = validateEntryName(name);
    if (invalid != null) {
      throw PlatformException(code: 'invalid_name', message: invalid);
    }
    final renamed = await storage.renameEntry(current!, entry, name.trim());
    await _migrateCreatedAt(entry.uri, renamed.uri);
    await _load();
  });

  Future<void> deleteEntry(StorageEntry entry) => _run(() async {
    try {
      await storage.delete(entry);
    } finally {
      await _load();
    }
  });

  /// 目录改名或移动会改变文档 ID；创建时间元数据跟随迁移。
  ///
  /// 缓存缺失时回查登记存储，保证外部来源之外的登记时间不丢失。
  Future<void> _migrateCreatedAt(String oldUri, String newUri) async {
    var time = _createdTimes.remove(oldUri);
    time ??= (await store.createdTimes([oldUri]))[oldUri];
    if (time == null) return;
    try {
      await store.recordCreated(newUri, time);
      _createdTimes[newUri] = time;
    } catch (_) {
      /* 元数据可重建。 */
    }
  }

  Future<void> openFile(StorageEntry entry) =>
      _run(() => storage.openFile(entry));

  // ---- 内容导入（相册 / PDF / 拍照）----

  /// 从系统选择器批量导入内容到当前目录；取消时不刷新。
  ///
  /// 导入内容不是本应用创建的，登记创建时间会倒推不实信息，保持未知。
  /// 部分文件失败时仍刷新已成功导入的条目，再上报错误。
  Future<void> importFromPicker(List<String> mimeTypes) => _run(() async {
    final folder = current;
    if (folder == null || folder.canCreate != true) {
      throw PlatformException(code: 'read_only', message: '当前目录不可写入');
    }
    try {
      final imported = await storage.pickImport(mimeTypes, folder);
      if (imported.isNotEmpty) await _load();
    } catch (_) {
      await _load();
      rethrow;
    }
  });

  /// 将外部分享的文件保存到 [folder]；成功返回 true。
  ///
  /// 确认保存后即消费待保存列表；部分失败仍刷新已成功条目并上报错误，
  /// 避免重复保存同一批文件。
  Future<bool> importIncoming(StorageEntry folder) async {
    final sources = [for (final share in incomingShares) share.uri];
    if (sources.isEmpty) return false;
    incomingShares.clear();
    var saved = false;
    await _run(() async {
      try {
        final imported = await storage.importDocuments(sources, folder);
        if (imported.isNotEmpty) await _load();
        saved = true;
      } catch (_) {
        await _load();
        rethrow;
      }
    });
    return saved;
  }

  /// 系统相机拍摄照片并复制到当前目录；本应用创建的内容登记创建时间。
  Future<void> capturePhoto() => _run(() async {
    final folder = current;
    if (folder == null || folder.canCreate != true) {
      throw PlatformException(code: 'read_only', message: '当前目录不可写入');
    }
    final photo = await storage.takePhoto(folder);
    if (photo == null) return;
    try {
      final now = DateTime.now();
      await store.recordCreated(photo.uri, now);
      _createdTimes[photo.uri] = now;
    } catch (_) {
      /* 元数据可重建。 */
    }
    await _load();
  });

  /// 系统相机录制视频并复制到当前目录；偏好与保存链路和拍照一致。
  ///
  /// 应用创建的视频登记创建时间；取消或录制失败不产生任何变更。
  Future<void> captureVideo() => _run(() async {
    final folder = current;
    if (folder == null || folder.canCreate != true) {
      throw PlatformException(code: 'read_only', message: '当前目录不可写入');
    }
    final video = await storage.takeVideo(folder);
    if (video == null) return;
    try {
      final now = DateTime.now();
      await store.recordCreated(video.uri, now);
      _createdTimes[video.uri] = now;
    } catch (_) {
      /* 元数据可重建。 */
    }
    await _load();
  });

  // ---- 批量选择（P3B-01）----

  /// 从工具栏进入选择模式，初始不选中任何条目；搜索中不允许进入。
  void startSelection() {
    if (searchQuery.value != null) return;
    selectionMode.value = true;
  }

  void toggleSelect(StorageEntry entry) {
    if (!selected.remove(entry.uri)) selected.add(entry.uri);
  }

  /// 全选当前目录条目；再次调用取消全选。
  void toggleSelectAll() {
    if (selected.length == entries.length) {
      selected.clear();
    } else {
      selected
        ..clear()
        ..addAll(entries.map((value) => value.uri));
    }
  }

  /// 退出选择模式；保留最近一次批量任务结果供查看。
  void exitSelection() {
    selectionMode.value = false;
    selected.clear();
    batchJob.value = null;
  }

  void _exitSelectionOnly() {
    selectionMode.value = false;
    selected.clear();
  }

  /// 当前选中且仍存在于列表中的条目；顺序与列表一致。
  List<StorageEntry> selectedEntries() => [
    for (final entry in entries)
      if (selected.contains(entry.uri)) entry,
  ];

  /// 批量删除前的影响汇总；调用方负责展示确认对话框。
  Future<DeletionImpact> selectedImpact() async {
    var files = 0;
    var folders = 0;
    for (final entry in selectedEntries()) {
      final impact = await storage.deletionImpact(entry);
      files += impact.files;
      folders += impact.folders;
    }
    return DeletionImpact(files, folders);
  }

  // ---- 批量删除（P3B-02）----

  Future<BatchJob?> deleteSelected() => _batchRun(() async {
    final targets = selectedEntries();
    if (targets.isEmpty) return null;
    final job = BatchJob(BatchKind.delete, [
      for (final target in targets)
        BatchItemResult.pending(target.uri, target.name),
    ]);
    batchJob.value = job;
    for (final item in job.items) {
      final entry = targets.firstWhere((value) => value.uri == item.uri);
      try {
        await storage.delete(entry);
        item.status = BatchItemStatus.success;
      } catch (failure) {
        item
          ..status = BatchItemStatus.failed
          ..message = userError(failure);
      }
      batchJob.refresh();
    }
    // 失败项保留选中状态以便重试；成功项随刷新消失。
    selected.removeAll([
      for (final item in job.items)
        if (item.status == BatchItemStatus.success) item.uri,
    ]);
    await _load();
    return job;
  });

  // ---- 批量移动（P3B-03）----

  /// 校验目标目录是否可用：返回 null 表示可移动，否则返回原因。
  ///
  /// 目标由应用内目录选择器给出（从根逐级导航），trail 为根到目标路径；
  /// 祖先关系仅通过导航轨迹判断，不解析 documentId 字符串。
  String? moveTargetIssue(List<StorageEntry> trail) {
    if (current == null) return '当前目录不可用';
    if (trail.isEmpty) return '目标位置无效';
    final target = trail.last;
    if (target.documentId == current!.documentId) return '目标位置与来源相同';
    final selectedFolders = selectedEntries().where(
      (entry) => entry.isDirectory,
    );
    for (final folder in selectedFolders) {
      if (trail.any((item) => item.documentId == folder.documentId)) {
        return '目标位于所选文件夹 ${folder.name} 内部';
      }
    }
    return null;
  }

  Future<BatchJob?> moveSelected(List<StorageEntry> trail) =>
      _batchRun(() async {
        final targets = selectedEntries();
        if (targets.isEmpty) return null;
        final issue = moveTargetIssue(trail);
        if (issue != null) {
          throw PlatformException(code: 'move_invalid_target', message: issue);
        }
        final targetFolder = trail.last;
        final job = BatchJob(BatchKind.move, [
          for (final target in targets)
            BatchItemResult.pending(target.uri, target.name),
        ]);
        batchJob.value = job;
        for (final item in job.items) {
          final entry = targets.firstWhere((value) => value.uri == item.uri);
          try {
            final result = await storage.move(current!, entry, targetFolder);
            if (result.sourceDeleted) {
              item.status = BatchItemStatus.success;
              // 目标提交成功且源已删除才迁移创建时间元数据。
              await _migrateCreatedAt(entry.uri, result.entry.uri);
            } else {
              item
                ..status = BatchItemStatus.copiedSourceKept
                ..message = '复制完成，源未删除';
              // 源仍在原位置：为其副本登记创建时间，但不迁移旧键。
              final time = _createdTimes[entry.uri];
              if (time != null) {
                try {
                  await store.recordCreated(result.entry.uri, time);
                  _createdTimes[result.entry.uri] = time;
                } catch (_) {
                  /* 元数据可重建。 */
                }
              }
            }
          } catch (failure) {
            item
              ..status = BatchItemStatus.failed
              ..message = userError(failure);
          }
          batchJob.refresh();
        }
        await _load();
        return job;
      });

  // ---- 批量重命名（P3B-04）----

  /// 生成批量重命名预览并逐项校验；界面禁止在有错误项时执行。
  List<RenamePreview> previewRenameSelected(BatchRenamePlan plan) =>
      previewRename(selectedEntries(), plan);

  Future<BatchJob?> renameSelected(List<RenamePreview> previews) =>
      _batchRun(() async {
        if (previews.isEmpty) return null;
        if (previews.any((preview) => preview.error != null)) {
          throw PlatformException(
            code: 'invalid_name',
            message: '存在无效名称，已取消批量重命名',
          );
        }
        final job = BatchJob(BatchKind.rename, [
          for (final preview in previews)
            BatchItemResult.pending(preview.entry.uri, preview.entry.name),
        ]);
        batchJob.value = job;
        for (final (index, item) in job.items.indexed) {
          final preview = previews[index];
          try {
            final renamed = await storage.renameEntry(
              current!,
              preview.entry,
              preview.name,
            );
            await _migrateCreatedAt(preview.entry.uri, renamed.uri);
            item.status = BatchItemStatus.success;
          } catch (failure) {
            item
              ..status = BatchItemStatus.failed
              ..message = userError(failure);
          }
          batchJob.refresh();
        }
        await _load();
        return job;
      });

  // ---- 批量压缩与分享（P3A-01 / P3A-03）----

  /// 压缩选中的多个条目到当前目录；[fileName] 为用户自定义名称。
  Future<ArchiveOutcome> zipSelected({String? fileName}) async {
    final folder = current;
    final targets = selectedEntries();
    if (folder == null || folder.canCreate != true) {
      return const ArchiveOutcome.failure(
        ArchiveKind.zip,
        'read_only',
        '当前目录不可写入',
      );
    }
    if (targets.isEmpty) {
      return const ArchiveOutcome.failure(
        ArchiveKind.zip,
        'invalid_argument',
        '没有可压缩的条目',
      );
    }
    return _finishArchive(
      await archive.zip(
        entries: targets,
        targetFolder: folder,
        fileName: fileName,
      ),
    );
  }

  /// 分享选中的条目；文件夹先压缩为临时缓存 ZIP。
  Future<ShareOutcome> shareSelected() => archive.share(selectedEntries());

  /// 压缩单个条目到当前目录；[fileName] 为空时使用默认规则命名。
  Future<ArchiveOutcome> zipEntry(
    StorageEntry entry, {
    String? fileName,
  }) async {
    final folder = current;
    if (folder == null || folder.canCreate != true) {
      return const ArchiveOutcome.failure(
        ArchiveKind.zip,
        'read_only',
        '当前目录不可写入',
      );
    }
    return _finishArchive(
      await archive.zip(
        entries: [entry],
        targetFolder: folder,
        fileName: fileName,
      ),
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

  // ---- 文件名搜索（P3B-05）----

  /// 进入搜索：先在当前目录过滤，递归为显式动作。
  void beginSearch(String query) {
    final keyword = query.trim();
    searchQuery.value = keyword;
    searchIncomplete.value = false;
    searchRecursive.value = false;
    searchResults.assignAll(_filterCurrent(keyword));
    _searchLocations.clear();
    final folder = current;
    if (folder != null) {
      for (final result in searchResults) {
        _searchLocations[result.uri] = folder.name;
      }
    }
  }

  List<StorageEntry> _filterCurrent(String keyword) {
    if (keyword.isEmpty) return List.of(entries);
    final lowered = keyword.toLowerCase();
    return [
      for (final entry in entries)
        if (entry.name.toLowerCase().contains(lowered)) entry,
    ];
  }

  /// 显式递归搜索；异步遍历、可取消、分批显示，失败目录计入未完成。
  Future<void> searchAll(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty || searching.value || current == null) return;
    final token = ++_searchToken;
    final start = current!;
    searching.value = true;
    searchRecursive.value = true;
    searchQuery.value = keyword;
    searchIncomplete.value = false;
    searchResults.clear();
    final lowered = keyword.toLowerCase();
    final queue = Queue<StorageEntry>()..add(start);
    final paths = <String, String>{start.documentId: start.name};
    final seen = <String>{start.documentId};
    _searchLocations.clear();
    var buffer = <StorageEntry>[];
    var cancelled = false;
    try {
      while (queue.isNotEmpty) {
        if (_searchToken != token) {
          cancelled = true;
          break;
        }
        final folder = queue.removeFirst();
        List<StorageEntry> children;
        try {
          children = await storage.list(folder);
        } catch (_) {
          // 递归访问失败显示部分结果和失败位置，保留取消能力。
          searchIncomplete.value = true;
          continue;
        }
        for (final child in children) {
          if (!seen.add(child.documentId)) continue;
          if (child.isDirectory) {
            // 位置标注取匹配项所在目录；文件夹自身路径仅用于下级标注。
            paths[child.documentId] =
                '${paths[folder.documentId]}/${child.name}';
          }
          if (child.name.toLowerCase().contains(lowered)) {
            buffer.add(child);
            _searchLocations[child.uri] = paths[folder.documentId]!;
          }
          if (child.isDirectory) queue.add(child);
        }
        if (buffer.length >= _searchFlushSize) {
          searchResults.addAll(buffer);
          buffer = <StorageEntry>[];
          await Future<void>.delayed(Duration.zero);
        }
      }
    } finally {
      if (!cancelled && _searchToken == token) {
        searchResults.addAll(buffer);
      }
      if (_searchToken == token) searching.value = false;
    }
  }

  /// 取消递归搜索；已显示的分批结果保留，界面立即回到非扫描状态。
  void cancelSearch() {
    _searchToken++;
    searching.value = false;
  }

  /// 退出搜索，恢复当前目录列表。
  void exitSearch() {
    _searchToken++;
    searchQuery.value = null;
    searchResults.clear();
    searching.value = false;
    searchIncomplete.value = false;
  }

  // ---- 缩略图与详情（P3B-07 / P3B-08）----

  Future<Uint8List?> thumbnailFor(StorageEntry entry) => thumbnails.load(entry);

  /// 行销毁时取消尚未开始的缩略图请求，避免离屏项占用加载通道。
  void cancelThumbnail(StorageEntry entry) => thumbnails.cancel(entry);

  /// 视频的可读属性；缺失键按未知处理，不为浏览列表逐个解码。
  Future<Map<String, Object?>> videoDetails(StorageEntry entry) async {
    if (!entry.isVideo) return const {};
    try {
      return await storage.videoDetails(entry);
    } catch (_) {
      return const {};
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy.value) return;
    busy.value = true;
    error.value = null;
    try {
      await action();
    } catch (failure) {
      error.value = userError(failure);
      if (failure is PlatformException &&
          ['permission_denied', 'invalid_root'].contains(failure.code)) {
        rootRequired.value = true;
        entries.clear();
      }
    } finally {
      busy.value = false;
    }
  }

  /// 批量任务执行器；与 [userError] 相同的错误策略，返回任务供界面展示。
  Future<T?> _batchRun<T>(Future<T?> Function() action) async {
    if (busy.value) return null;
    busy.value = true;
    error.value = null;
    try {
      return await action();
    } catch (failure) {
      error.value = userError(failure);
      return null;
    } finally {
      busy.value = false;
    }
  }
}
