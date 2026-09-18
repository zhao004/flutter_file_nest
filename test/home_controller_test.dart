import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/models/archive_models.dart';
import 'package:flutter_lens_vault/app/models/batch_models.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/pages/home/home_controller.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';
import 'support/fakes.dart';
import 'support/archive_fakes.dart';

void main() {
  test('取消选目录不改变现有设置', () async {
    final storage = FakeStorage()..selected = null;
    final store = MemoryStore();
    final controller = HomeController(
      storage: storage,
      store: store,
      archive: FakeArchive(),
    );
    await controller.initialize();
    await controller.pickRoot();
    expect(controller.rootRequired.value, true);
    expect(store.value.rootUri, isNull);
  });
  test('恢复授权目录，外部新增文件可刷新，权限撤销后阻止写入', () async {
    final storage = FakeStorage();
    final store = MemoryStore()
      ..value = VaultPreferences(rootUri: root.rootUri);
    final controller = HomeController(
      storage: storage,
      store: store,
      archive: FakeArchive(),
    );
    await controller.initialize();
    expect(controller.rootRequired.value, false);
    storage.contents['root']!.add(entry('外部视频.mp4'));
    await controller.refresh();
    expect(controller.entries.single.name, '外部视频.mp4');
    storage.permissionDenied = true;
    await controller.refresh();
    expect(controller.rootRequired.value, true);
    expect(controller.entries, isEmpty);
  });
  test('创建和返回父目录后从真实存储刷新', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('现场');
    await controller.enter(controller.entries.single);
    expect(controller.canGoBack, true);
    await controller.back();
    expect(controller.entries.single.name, '现场');
    await controller.createFolder('../错误');
    expect(storage.creates, 1);
    expect(controller.error.value, isNotNull);
  });

  test('有待保存录像时保护同一根目录的文件夹，处理后允许改名', () async {
    final storage = FakeStorage();
    final store = MemoryStore();
    final controller = HomeController(
      storage: storage,
      store: store,
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('现场');
    final folder = controller.entries.single;
    await store.addJob(
      RecordingJob(
        id: 'pending',
        sourcePath: 'private.mp4',
        rootUri: root.rootUri,
        parentId: folder.documentId,
        fileName: 'video.mp4',
        createdAt: DateTime.now(),
      ),
    );
    await controller.renameEntry(folder, '改名');
    expect(controller.entries.single.name, '现场');
    expect(controller.error.value, contains('待保存录像'));
    await controller.deleteEntry(folder);
    expect(storage.deletes, 0);
    await store.removeJob('pending');
    await controller.renameEntry(folder, '改名');
    expect(controller.entries.single.name, '改名');
  });

  test('旧根目录恢复失败不会使当前根目录失效', () async {
    final storage = FakeStorage()..deniedSaveRoot = 'content://old';
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('当前文件夹');
    await controller.retryRecording(
      RecordingJob(
        id: 'old',
        sourcePath: 'private.mp4',
        rootUri: 'content://old',
        parentId: 'old',
        fileName: 'video.mp4',
        createdAt: DateTime.now(),
      ),
    );
    expect(controller.error.value, contains('旧目录'));
    expect(controller.rootRequired.value, false);
    expect(controller.entries.single.name, '当前文件夹');
  });

  test('压缩条目委托归档网关并在成功后刷新列表', () async {
    final storage = FakeStorage();
    final archive = FakeArchive();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: archive,
    );
    await controller.pickRoot();
    storage.contents['root']!.add(entry('视频.mp4', mime: 'video/mp4'));
    await controller.refresh();
    final outcome = await controller.zipEntry(controller.entries.single);
    expect(archive.zipCalls, ['视频.mp4']);
    expect(outcome.ok, true);
    expect(outcome.summary, contains('压缩结果.zip'));
    expect(controller.error.value, isNull);
  });

  test('压缩失败写入错误横幅且不刷新列表', () async {
    final storage = FakeStorage();
    final archive = FakeArchive()
      ..zipResult = const ArchiveOutcome.failure(
        ArchiveKind.zip,
        'io_error',
        '文件读写失败，请检查存储空间和设备连接',
      );
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: archive,
    );
    await controller.pickRoot();
    storage.contents['root']!.add(entry('视频.mp4'));
    await controller.refresh();
    final outcome = await controller.zipEntry(controller.entries.single);
    expect(outcome.ok, false);
    expect(controller.error.value, contains('文件读写失败'));
  });

  test('解压委托归档网关并返回逐项结果', () async {
    final storage = FakeStorage();
    final archive = FakeArchive()
      ..extractResult = ArchiveOutcome(
        kind: ArchiveKind.extract,
        target: entry('素材', directory: true),
        extracted: 3,
        skipped: 1,
      );
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: archive,
    );
    await controller.pickRoot();
    storage.contents['root']!.add(entry('素材.zip', mime: 'application/zip'));
    await controller.refresh();
    final outcome = await controller.extractEntry(controller.entries.single);
    expect(archive.extractCalls, ['素材.zip']);
    expect(outcome.summary, contains('跳过 1 项'));
  });

  test('分享与取消转发到归档网关', () async {
    final storage = FakeStorage();
    final archive = FakeArchive()..shareResult = const ShareOutcome.noApp();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: archive,
    );
    await controller.pickRoot();
    storage.contents['root']!.add(entry('视频.mp4'));
    await controller.refresh();
    final outcome = await controller.shareEntry(controller.entries.single);
    expect(archive.shareCalls, ['视频.mp4']);
    expect(outcome.summary, contains('未找到'));
    await controller.cancelArchive();
    expect(archive.cancels, 1);
  });

  test('长按进入选择模式，全选与退出数量正确', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    storage.contents['root']!
      ..add(entry('a.mp4'))
      ..add(entry('b.mp4'));
    await controller.refresh();
    expect(controller.selectionMode.value, false);
    controller.beginSelection(controller.entries.first);
    expect(controller.selectionMode.value, true);
    expect(controller.selectedCount, 1);
    controller.toggleSelect(controller.entries.last);
    expect(controller.selectedCount, 2);
    controller.toggleSelect(controller.entries.last);
    expect(controller.selectedCount, 1);
    controller.toggleSelectAll();
    expect(controller.selectedCount, 2);
    controller.toggleSelectAll();
    expect(controller.selectedCount, 0);
    controller.exitSelection();
    expect(controller.selectionMode.value, false);
  });

  test('刷新后剔除已不存在的选中项', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    storage.contents['root']!
      ..add(entry('a.mp4'))
      ..add(entry('b.mp4'));
    await controller.refresh();
    controller.beginSelection(controller.entries.first);
    storage.contents['root']!.removeWhere((value) => value.name == 'a.mp4');
    await controller.refresh();
    expect(controller.selectedCount, 0);
  });

  test('批量删除逐项执行，失败项保留选中以便重试', () async {
    final storage = FakeStorage()..failDeleteNames.add('b.mp4');
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    storage.contents['root']!
      ..add(entry('a.mp4'))
      ..add(entry('b.mp4'));
    await controller.refresh();
    controller.beginSelection(controller.entries.first);
    controller.toggleSelectAll();
    final job = await controller.deleteSelected();
    expect(job, isNotNull);
    expect(job!.successCount, 1);
    expect(job.failedCount, 1);
    expect(job.items.first.status, BatchItemStatus.success);
    expect(job.items.last.status, BatchItemStatus.failed);
    expect(controller.selectedCount, 1);
    expect(controller.selectionMode.value, true);
    storage.failDeleteNames.clear();
    final retried = await controller.deleteSelected();
    expect(retried!.successCount, 1);
    expect(storage.deletes, 2);
    expect(controller.selectionMode.value, false);
  });

  test('批量删除在待保存录像期间保护文件夹', () async {
    final storage = FakeStorage();
    final store = MemoryStore();
    final controller = HomeController(
      storage: storage,
      store: store,
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('现场');
    storage.contents['root']!.add(entry('b.mp4'));
    await controller.refresh();
    await store.addJob(
      RecordingJob(
        id: 'pending',
        sourcePath: 'private.mp4',
        rootUri: root.rootUri,
        parentId: 'root',
        fileName: 'video.mp4',
        createdAt: DateTime.now(),
      ),
    );
    controller.toggleSelectAll();
    final job = await controller.deleteSelected();
    expect(job, isNull);
    expect(controller.error.value, contains('待保存录像'));
    expect(storage.deletes, 0);
  });

  test('批量移动：目标校验拒绝移入自身或后代', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('来源');
    await controller.createFolder('目标');
    storage.contents['root']!.add(entry('视频.mp4'));
    await controller.refresh();
    final source = controller.entries.firstWhere((e) => e.name == '来源');
    controller.toggleSelect(source);
    final rootTrail = [controller.folders.first];
    expect(controller.moveTargetIssue(rootTrail), '目标位置与来源相同');
    expect(controller.moveTargetIssue([...rootTrail, source]), contains('内部'));
    final target = controller.entries.firstWhere((e) => e.name == '目标');
    expect(controller.moveTargetIssue([...rootTrail, target]), isNull);
  });

  test('批量移动成功后旧位置消失，目标目录完整可读', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('目标');
    storage.contents['root']!.add(entry('视频.mp4', size: 10));
    await controller.refresh();
    controller.toggleSelect(
      controller.entries.firstWhere((e) => !e.isDirectory),
    );
    await controller.moveSelected([
      controller.folders.first,
      controller.entries.firstWhere((e) => e.isDirectory),
    ]);
    expect(storage.moves, ['视频.mp4']);
    expect(controller.entries.map((e) => e.name), ['目标']);
    await controller.enter(controller.entries.single);
    expect(controller.entries.single.name, '视频.mp4');
  });

  test('移动回退复制完成但源未删除时逐项报告', () async {
    final storage = FakeStorage()..failSourceDelete = true;
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('目标');
    storage.contents['root']!.add(entry('视频.mp4'));
    await controller.refresh();
    controller.toggleSelect(
      controller.entries.firstWhere((e) => !e.isDirectory),
    );
    final job = await controller.moveSelected([
      controller.folders.first,
      controller.entries.firstWhere((e) => e.isDirectory),
    ]);
    expect(job!.keptSourceCount, 1);
    expect(job.items.single.message, contains('源未删除'));
    // 源未删除时原条目仍保留，不产生静默丢失。
    expect(
      storage.contents['root']!.any((value) => value.name == '视频.mp4'),
      true,
    );
  });

  test('批量重命名预览保留扩展名并执行改名', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    storage.contents['root']!
      ..add(entry('IMG_001.jpg'))
      ..add(entry('IMG_002.jpg'))
      ..add(entry('b.txt'));
    await controller.refresh();
    controller.toggleSelectAll();
    final previews = controller.previewRenameSelected(
      const BatchRenamePlan(numbering: true, prefix: 'A_', startNumber: 0),
    );
    expect(previews[0].name, 'A_000.jpg');
    expect(previews[1].name, 'A_001.jpg');
    expect(previews[2].name, 'A_002.txt');
    expect(previews.every((preview) => preview.error == null), true);
    final job = await controller.renameSelected(previews);
    expect(job!.successCount, 3);
    expect(storage.renames, contains('IMG_001.jpg→A_000.jpg'));
  });

  test('重命名互换成预览错误且不会执行', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    storage.contents['root']!
      ..add(entry('a.txt'))
      ..add(entry('b.txt'));
    await controller.refresh();
    controller.toggleSelectAll();
    final previews = controller.previewRenameSelected(
      const BatchRenamePlan(replaceFrom: 'a', replaceTo: 'b'),
    );
    expect(previews[0].error, isNotNull);
    final job = await controller.renameSelected(previews);
    expect(job, isNull);
    expect(storage.renames, isEmpty);
  });

  test('多选压缩传递全部选中条目', () async {
    final storage = FakeStorage();
    final archive = FakeArchive();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: archive,
    );
    await controller.pickRoot();
    storage.contents['root']!
      ..add(entry('a.mp4'))
      ..add(entry('b.mp4'));
    await controller.refresh();
    controller.toggleSelectAll();
    final outcome = await controller.zipSelected();
    expect(archive.zipCalls.single, 'a.mp4,b.mp4');
    expect(outcome.ok, true);
  });

  test('文件名搜索：当前目录过滤优先，递归标注位置，失败目录计入未完成', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('素材');
    storage.contents.putIfAbsent('素材', () => []).add(entry('现场2.mp4'));
    storage.contents['root']!.add(entry('现场1.mp4'));
    await controller.refresh();
    controller.beginSearch('现场');
    expect(controller.searchResults.single.name, '现场1.mp4');
    expect(
      controller.searchLocationOf(controller.searchResults.single),
      '测试目录',
    );
    await controller.searchAll('现场');
    expect(controller.searching.value, false);
    expect(controller.searchResults.length, 2);
    final nested = controller.searchResults.firstWhere(
      (value) => value.name == '现场2.mp4',
    );
    expect(controller.searchLocationOf(nested), '测试目录/素材');
    expect(controller.searchIncomplete.value, false);
  });

  test('递归搜索失败的目录标记为未完成，不阻塞其他结果', () async {
    final storage = FakeStorage()..failingFolders.add('素材');
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('素材');
    storage.contents['root']!.add(entry('现场1.mp4'));
    await controller.refresh();
    await controller.searchAll('现场');
    expect(controller.searchIncomplete.value, true);
    expect(controller.searchResults.single.name, '现场1.mp4');
  });

  test('创建时间排序：未登记的条目排在末尾，不冒充修改时间', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.createFolder('早创建');
    await controller.createFolder('晚创建');
    storage.contents['root']!.add(entry('未登记.mp4'));
    await controller.refresh();
    await controller.setSort(EntrySort.created, false);
    final names = controller.entries.map((value) => value.name).toList();
    expect(names, ['早创建', '晚创建', '未登记.mp4']);
  });

  test('文件改名后创建时间元数据跟随新标识', () async {
    final storage = FakeStorage();
    final store = MemoryStore();
    final controller = HomeController(
      storage: storage,
      store: store,
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    storage.contents['root']!.add(entry('旧名.mp4', mime: 'video/mp4'));
    await controller.refresh();
    final file = controller.entries.single;
    await store.recordCreated(file.uri, DateTime(2026));
    await controller.renameEntry(file, '新名.mp4');
    expect(store.created.keys.any((uri) => uri.contains('新名')), true);
  });

  test('从相册选择导入图片到当前目录并刷新', () async {
    final storage = FakeStorage()
      ..pickImportResult = entry('照片.jpg', mime: 'image/jpeg');
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.importFromPicker(const ['image/*', 'video/*']);
    expect(storage.imports.single, 'image/*,video/*');
    expect(controller.entries.single.name, '照片.jpg');
    expect(controller.error.value, isNull);
  });

  test('取消导入不产生变更', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.importFromPicker(const ['application/pdf']);
    expect(controller.entries, isEmpty);
    expect(controller.error.value, isNull);
  });

  test('选择 PDF 使用明确的 MIME 过滤', () async {
    final storage = FakeStorage()
      ..pickImportResult = entry('合同.pdf', mime: 'application/pdf');
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.importFromPicker(const ['application/pdf']);
    expect(storage.imports.single, 'application/pdf');
    expect(controller.entries.single.isPdf, true);
  });

  test('拍照导入当前目录并登记创建时间', () async {
    final storage = FakeStorage()
      ..takePhotoResult = entry('IMG_001.jpg', mime: 'image/jpeg');
    final store = MemoryStore();
    final controller = HomeController(
      storage: storage,
      store: store,
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.capturePhoto();
    expect(storage.photoCaptures, 1);
    expect(controller.entries.single.name, 'IMG_001.jpg');
    // 拍照是本应用创建的内容，登记创建时间用于排序。
    expect(store.created.keys.any((uri) => uri.contains('IMG_001')), true);
    // 导入的外部内容不登记创建时间，避免倒推不实信息。
    final importedStore = MemoryStore();
    final importedStorage = FakeStorage()
      ..pickImportResult = entry('照片.jpg', mime: 'image/jpeg');
    final importedController = HomeController(
      storage: importedStorage,
      store: importedStore,
      archive: FakeArchive(),
    );
    await importedController.pickRoot();
    await importedController.importFromPicker(const ['image/*']);
    expect(importedStore.created, isEmpty);
  });

  test('压缩使用自定义名称传递归档网关', () async {
    final storage = FakeStorage();
    final archive = FakeArchive();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: archive,
    );
    await controller.pickRoot();
    storage.contents['root']!.add(entry('素材'));
    await controller.refresh();
    final outcome = await controller.zipEntry(
      controller.entries.single,
      fileName: '现场资料.zip',
    );
    expect(archive.zipNames.single, '现场资料.zip');
    expect(outcome.ok, true);
  });

  test('多选压缩同样支持自定义名称', () async {
    final storage = FakeStorage();
    final archive = FakeArchive();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: archive,
    );
    await controller.pickRoot();
    storage.contents['root']!
      ..add(entry('a.mp4'))
      ..add(entry('b.mp4'));
    await controller.refresh();
    controller.toggleSelectAll();
    final outcome = await controller.zipSelected(fileName: '素材包.zip');
    // 对话框补齐后的完整名称原样传递给归档网关。
    expect(archive.zipNames.single, '素材包.zip');
    expect(archive.zipCalls.single, 'a.mp4,b.mp4');
    expect(outcome.ok, true);
  });

  test('图片与 PDF 类型识别', () {
    expect(entry('照片.jpg', mime: 'image/jpeg').isImage, true);
    expect(entry('照片.heic').isImage, true);
    expect(entry('文档.pdf', mime: 'application/pdf').isPdf, true);
    expect(entry('文档', mime: 'application/pdf').isPdf, true);
    expect(entry('视频.mp4').isImage, false);
    expect(entry('文本.txt').isPdf, false);
  });

  test('系统相机录制导入当前目录并登记创建时间', () async {
    final storage = FakeStorage()
      ..takeVideoResult = entry('VID_001.mp4', mime: 'video/mp4');
    final store = MemoryStore();
    final controller = HomeController(
      storage: storage,
      store: store,
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.captureVideo();
    expect(storage.videoCaptures, 1);
    expect(controller.entries.single.name, 'VID_001.mp4');
    expect(store.created.keys.any((uri) => uri.contains('VID_001')), true);
    expect(store.value.systemCameraRecording, true, reason: '系统相机录制默认开启');
  });

  test('取消系统相机录制不产生变更', () async {
    final storage = FakeStorage();
    final controller = HomeController(
      storage: storage,
      store: MemoryStore(),
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.captureVideo();
    expect(storage.videoCaptures, 1);
    expect(controller.entries, isEmpty);
    expect(controller.error.value, isNull);
  });

  test('录制方式偏好持久化并可切换回应用内相机', () async {
    final store = MemoryStore();
    final controller = HomeController(
      storage: FakeStorage(),
      store: store,
      archive: FakeArchive(),
    );
    await controller.pickRoot();
    await controller.setSystemCameraRecording(false);
    expect(store.value.systemCameraRecording, false);
    await controller.setSystemCameraRecording(true);
    expect(store.value.systemCameraRecording, true);
  });
}
