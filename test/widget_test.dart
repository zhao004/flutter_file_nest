import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_lens_vault/app/models/archive_models.dart';
import 'package:flutter_lens_vault/app/pages/home/home_controller.dart';
import 'package:flutter_lens_vault/app/pages/home/home_view.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';
import 'support/fakes.dart';
import 'support/archive_fakes.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });
  tearDown(() => Get.reset());

  testWidgets('选择根目录、新建文件夹并校验非法名称', (tester) async {
    final storage = FakeStorage();
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore(),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择文件夹'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '../不合法');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('名称不能含路径或控制字符'), findsOneWidget);
    expect(storage.creates, 0);
    await tester.enterText(find.byType(TextFormField), '现场一');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('现场一'), findsOneWidget);
    expect(storage.creates, 1);
  });

  testWidgets('删除前显示影响数量，取消不会删除，确认后刷新', (tester) async {
    final storage = FakeStorage();
    storage.contents['root']!.add(entry('现场', directory: true));
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    Future<void> showDelete() async {
      await tester.tap(find.byTooltip('文件操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
    }

    await showDelete();
    expect(find.text('1 个文件，2 个子文件夹\n删除后无法恢复。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(storage.deletes, 0);
    await showDelete();
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(storage.deletes, 1);
    expect(find.text('文件夹为空'), findsOneWidget);
  });

  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('文件列表适配 $size，长名称不溢出', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = FakeStorage();
      storage.contents['root']!.add(entry('很长的文件名称' * 12));
      Get.put(
        HomeController(
          storage: storage,
          store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
          archive: FakeArchive(),
        ),
      );
      await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('录制'), findsOneWidget);
    });
  }

  testWidgets('文件操作提供压缩、解压与分享，压缩结果以提示反馈', (tester) async {
    final storage = FakeStorage();
    final archive = FakeArchive();
    storage.contents['root']!.add(entry('素材.zip', mime: 'application/zip'));
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: archive,
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('文件操作'));
    await tester.pumpAndSettle();
    expect(find.text('压缩为 ZIP'), findsOneWidget);
    expect(find.text('解压到新文件夹'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
    await tester.tap(find.text('压缩为 ZIP'));
    await tester.pumpAndSettle();
    expect(archive.zipCalls, ['素材.zip']);
    expect(find.textContaining('压缩结果.zip'), findsOneWidget);
  });

  testWidgets('归档任务显示进度与取消入口', (tester) async {
    final storage = FakeStorage();
    final archive = FakeArchive();
    storage.contents['root']!.add(entry('视频.mp4'));
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: archive,
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    archive.emit(
      const ArchiveTaskState(
        operationId: 'op-1',
        kind: ArchiveKind.zip,
        stage: ArchiveStage.processing,
        processedItems: 3,
        totalItems: 10,
        canCancel: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('正在压缩：已处理 3 项'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(archive.cancels, 1);
    expect(find.textContaining('正在取消'), findsOneWidget);
  });
}
