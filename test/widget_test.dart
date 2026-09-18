import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_lens_vault/app/models/archive_models.dart';
import 'package:flutter_lens_vault/app/pages/home/home_controller.dart';
import 'package:flutter_lens_vault/app/pages/home/home_view.dart';
import 'package:flutter_lens_vault/app/pages/preview/pdf_preview_view.dart';
import 'package:flutter_lens_vault/app/services/saf_storage.dart';
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
    await tester.tap(find.text('新建'));
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
      // 操作入口为长按文件行。
      await tester.longPress(find.text('现场'));
      await tester.pumpAndSettle();
      // 操作项较多时“删除”位于折叠区，先滚动到可见。
      await tester.scrollUntilVisible(
        find.text('删除'),
        60,
        scrollable: find
            .descendant(
              of: find.byType(SafeArea),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('删除'), warnIfMissed: false);
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
    // 操作入口为长按文件行。
    await tester.longPress(find.text('素材.zip'));
    await tester.pumpAndSettle();
    expect(find.text('压缩为 ZIP'), findsOneWidget);
    expect(find.text('解压到新文件夹'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
    await tester.tap(find.text('压缩为 ZIP'));
    await tester.pumpAndSettle();
    // 压缩前弹出名称对话框；默认名称与来源一致，确认后执行。
    expect(find.text('素材.zip'), findsWidgets);
    await tester.tap(find.text('开始压缩'));
    await tester.pumpAndSettle();
    expect(archive.zipCalls, ['素材.zip']);
    expect(archive.zipNames, ['素材.zip']);
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

  testWidgets('添加菜单导入相册内容并刷新列表', (tester) async {
    final storage = FakeStorage()
      ..pickImportResult = entry('照片.jpg', mime: 'image/jpeg');
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(find.text('从相册选择图片/视频'), findsOneWidget);
    expect(find.text('选择 PDF 文件'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    await tester.tap(find.text('从相册选择图片/视频'));
    await tester.pumpAndSettle();
    expect(storage.imports.single, 'image/*,video/*');
    expect(find.text('照片.jpg'), findsOneWidget);
  });

  testWidgets('PDF 预览页按页渲染并显示页码', (tester) async {
    Get.put<StorageGateway>(FakeStorage(), permanent: true);
    await tester.pumpWidget(
      GetMaterialApp(
        home: PdfPreviewView(entry: entry('合同.pdf', mime: 'application/pdf')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 1 / 3 页'), findsOneWidget);
    // 滑到第二页后页码更新。
    await tester.fling(find.text('此页无法渲染'), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 3 页'), findsOneWidget);
  });
}
