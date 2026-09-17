import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/pages/home/home_controller.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';
import 'support/fakes.dart';

void main() {
  test('取消选目录不改变现有设置', () async {
    final storage = FakeStorage()..selected = null;
    final store = MemoryStore();
    final controller = HomeController(storage: storage, store: store);
    await controller.initialize();
    await controller.pickRoot();
    expect(controller.rootRequired.value, true);
    expect(store.value.rootUri, isNull);
  });
  test('恢复授权目录，外部新增文件可刷新，权限撤销后阻止写入', () async {
    final storage = FakeStorage();
    final store = MemoryStore()
      ..value = VaultPreferences(rootUri: root.rootUri);
    final controller = HomeController(storage: storage, store: store);
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
    final controller = HomeController(storage: storage, store: MemoryStore());
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
    final controller = HomeController(storage: storage, store: store);
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
    await controller.renameFolder(folder, '改名');
    expect(controller.entries.single.name, '现场');
    expect(controller.error.value, contains('待保存录像'));
    await controller.deleteEntry(folder);
    expect(storage.deletes, 0);
    await store.removeJob('pending');
    await controller.renameFolder(folder, '改名');
    expect(controller.entries.single.name, '改名');
  });

  test('旧根目录恢复失败不会使当前根目录失效', () async {
    final storage = FakeStorage()..deniedSaveRoot = 'content://old';
    final controller = HomeController(storage: storage, store: MemoryStore());
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
}
