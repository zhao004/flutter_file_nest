import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:get/get.dart';
import 'package:flutter_lens_vault/app/models/archive_models.dart';
import 'package:flutter_lens_vault/app/models/incoming_share.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/pages/home/home_controller.dart';
import 'package:flutter_lens_vault/app/pages/home/home_view.dart';
import 'package:flutter_lens_vault/app/pages/home/home_widgets.dart';
import 'package:flutter_lens_vault/app/pages/preview/image_preview_view.dart';
import 'package:flutter_lens_vault/app/pages/preview/pdf_preview_view.dart';
import 'package:flutter_lens_vault/app/pages/video/video_view.dart';
import 'package:flutter_lens_vault/app/services/saf_storage.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';
import 'package:flutter_lens_vault/app/theme/app_theme.dart';
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
    // 操作入口为可展开悬浮按钮；点击展开后的小按钮。
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建文件夹'));
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

  testWidgets('新建文件并校验非法名称', (tester) async {
    final storage = FakeStorage();
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    // 操作入口为可展开悬浮按钮；点击展开后的小按钮。
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建文件'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '../不合法');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('名称不能含路径或控制字符'), findsOneWidget);
    expect(storage.fileCreates, 0);
    await tester.enterText(find.byType(TextFormField), '笔记.txt');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('笔记.txt'), findsOneWidget);
    expect(storage.fileCreates, 1);
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
      expect(find.byTooltip('更多操作'), findsOneWidget);
    });
  }

  testWidgets('长按菜单移除压缩与分享，仅保留解压等单项操作', (tester) async {
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
    expect(find.text('压缩为 ZIP'), findsNothing);
    expect(find.text('分享'), findsNothing);
    expect(find.text('解压到新文件夹'), findsOneWidget);
    await tester.tap(find.text('解压到新文件夹'));
    await tester.pumpAndSettle();
    expect(archive.extractCalls, ['素材.zip']);
  });

  testWidgets('多选模式压缩弹出命名对话框并执行', (tester) async {
    final storage = FakeStorage();
    final archive = FakeArchive();
    storage.contents['root']!.add(entry('素材.mp4', mime: 'video/mp4'));
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: archive,
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('素材.mp4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('压缩为 ZIP'));
    await tester.pumpAndSettle();
    // 压缩前弹出名称对话框；确认后执行。
    await tester.tap(find.text('开始压缩'));
    await tester.pumpAndSettle();
    expect(archive.zipCalls, ['素材.mp4']);
    expect(archive.zipNames, hasLength(1));
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

  testWidgets('悬浮菜单选择多个任意文件并刷新列表', (tester) async {
    final storage = FakeStorage()
      ..pickImportResults = [
        entry('资料.pdf', mime: 'application/pdf'),
        entry('照片.jpg', mime: 'image/jpeg'),
      ];
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('新建文件夹'), findsOneWidget);
    expect(find.text('选择文件'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('录制'), findsOneWidget);
    // 选择文件不限定 MIME，且支持一次选择多个文件。
    await tester.tap(find.byTooltip('选择文件'));
    await tester.pumpAndSettle();
    expect(storage.imports.single, '*/*');
    expect(find.text('资料.pdf'), findsOneWidget);
    expect(find.text('照片.jpg'), findsOneWidget);
  });

  testWidgets('悬浮菜单拍照与录制调用系统相机', (tester) async {
    final storage = FakeStorage()
      ..takePhotoResult = entry('IMG_001.jpg', mime: 'image/jpeg')
      ..takeVideoResult = entry('VID_001.mp4', mime: 'video/mp4');
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('拍照'));
    await tester.pumpAndSettle();
    expect(storage.photoCaptures, 1);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('录制'));
    await tester.pumpAndSettle();
    expect(storage.videoCaptures, 1);
  });

  testWidgets('搜索独立成按钮，更多菜单含排序与设置，排序弹窗含字段与方向', (tester) async {
    final storage = FakeStorage();
    final store = MemoryStore()
      ..value = VaultPreferences(rootUri: root.rootUri);
    Get.put(
      HomeController(storage: storage, store: store, archive: FakeArchive()),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    // 搜索为独立图标按钮；设置仅存在于“更多”菜单。
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    // 点击搜索进入搜索栏，关闭后恢复应用栏。
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    // 搜索栏内的关闭按钮退出搜索，恢复普通应用栏。
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    // 更多菜单不再包含搜索项。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('排序方式'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('搜索文件'), findsNothing);
    // 升序/降序已并入弹窗，不再作为独立菜单项。
    expect(find.text('改为升序'), findsNothing);
    // 取消不改变现有排序字段与方向。
    await tester.tap(find.text('排序方式'));
    await tester.pumpAndSettle();
    expect(find.text('按名称'), findsOneWidget);
    expect(find.text('按修改时间'), findsOneWidget);
    expect(find.text('按创建时间'), findsOneWidget);
    expect(find.text('按文件大小'), findsOneWidget);
    expect(find.text('升序'), findsOneWidget);
    expect(find.text('降序'), findsOneWidget);
    await tester.tap(find.text('按文件大小'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('升序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.value.sort, EntrySort.modified);
    expect(store.value.descending, true);
    // 确认后同时应用排序字段与方向。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('排序方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按名称'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('升序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(store.value.sort, EntrySort.name);
    expect(store.value.descending, false);
  });

  testWidgets('多选行显示大小、时间、缩略图与左侧选择按钮', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = FakeStorage();
    storage.contents['root']!.add(
      entry('很长的文件名' * 8 + '.mp4', size: 2048, modified: DateTime(2026, 9, 18)),
    );
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('多选'), findsOneWidget);
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    // 窄屏下列表不溢出。
    expect(tester.takeException(), isNull);
    // 文件信息与浏览行一致：分辨率在大小左侧，含时间与缩略图。
    expect(find.textContaining('640 × 480 · 2.0 KB'), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsOneWidget);
    expect(find.textContaining('2026-09-18 00:00'), findsOneWidget);
    expect(find.byType(EntryThumbnail), findsOneWidget);
    // 缩略图左侧是选择按钮，点击切换选中并更新底部计数。
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.textContaining('已选 1 项'), findsOneWidget);
    // 再次点击取消选择。
    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pumpAndSettle();
    expect(find.textContaining('已选 0 项'), findsOneWidget);
    // 退出多选恢复浏览状态。
    await tester.tap(find.byTooltip('退出多选'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('多选'), findsOneWidget);
    expect(find.textContaining('已选'), findsNothing);
  });

  testWidgets('条目变化后重新加载缩略图，行销毁时取消排队请求', (tester) async {
    final storage = FakeStorage();
    final thumbs = FakeThumbnails();
    storage.contents['root']!.add(entry('a.mp4', mime: 'video/mp4'));
    final controller = HomeController(
      storage: storage,
      store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
      archive: FakeArchive(),
      thumbnails: thumbs,
    );
    Get.put(controller);
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    expect(thumbs.loads, hasLength(1));

    // 同一位置替换为另一视频：应按条目标识重新加载，而不是沿用旧状态。
    storage.contents['root']!
      ..clear()
      ..add(entry('b.mp4', mime: 'video/mp4'));
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(thumbs.loads.length, greaterThanOrEqualTo(2));

    // 列表清空后行被销毁，取消回调应触发。
    storage.contents['root']!.clear();
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(thumbs.cancels, isNotEmpty);
  });

  testWidgets('移动目标选择器实时校验并确认移动', (tester) async {
    final storage = FakeStorage();
    storage.contents['root']!
      ..add(entry('甲', directory: true))
      ..add(entry('乙', directory: true))
      ..add(entry('文件.mp4', mime: 'video/mp4'));
    storage.contents['甲'] = [entry('内部', directory: true)];
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文件.mp4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移动到…'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    // 弹窗顶部不再显示“移动到…”标题，仅保留选中数量。
    expect(
      find.descendant(of: dialog, matching: find.text('移动到…')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('已选 1 项')),
      findsOneWidget,
    );
    // 当前目录（根）不能作为目标：确认禁用并就地显示原因。
    expect(find.textContaining('目标位置与来源相同'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '移动到此文件夹'))
          .onPressed,
      isNull,
    );
    // 进入合法子目录后提示与确认按钮恢复可用，确认后执行移动。
    await tester.tap(find.descendant(of: dialog, matching: find.text('乙')));
    await tester.pumpAndSettle();
    expect(find.textContaining('将移动到：'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '移动到此文件夹'));
    await tester.pumpAndSettle();
    expect(storage.moves, ['文件.mp4']);
  });

  testWidgets('移动目标选择器屏蔽所选文件夹且取消不移动', (tester) async {
    // 横屏窄高场景下弹窗不溢出。
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = FakeStorage();
    storage.contents['root']!
      ..add(entry('甲', directory: true))
      ..add(entry('文件.mp4', mime: 'video/mp4'));
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('甲'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移动到…'));
    await tester.pumpAndSettle();

    // 横屏窄高下布局无溢出。
    expect(tester.takeException(), isNull);
    final dialog = find.byType(AlertDialog);
    // 所选文件夹不可作为目标，行置灰且不可进入。
    final blockedTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.descendant(of: dialog, matching: find.text('甲')),
        matching: find.byType(ListTile),
      ),
    );
    expect(blockedTile.enabled, false);
    // 取消不产生移动。
    await tester.tap(find.descendant(of: dialog, matching: find.text('取消')));
    await tester.pumpAndSettle();
    expect(storage.moves, isEmpty);
  });

  testWidgets('收到外部文件保存到当前打开的文件夹', (tester) async {
    final storage = FakeStorage()
      ..importResults = [entry('分享.pdf', mime: 'application/pdf')];
    storage.contents['root']!.add(entry('子目录', directory: true));
    final incoming = FakeIncomingShares();
    addTearDown(incoming.close);
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore()..value = VaultPreferences(rootUri: root.rootUri),
        archive: FakeArchive(),
        incoming: incoming,
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    // 先进入子目录，分享应保存到该目录而非根目录。
    await tester.tap(find.text('子目录'));
    await tester.pumpAndSettle();
    incoming.emit([const IncomingShare(uri: 'content://wx/9', name: '分享.pdf')]);
    await tester.pumpAndSettle();
    // 不再弹出文件夹选择器，直接保存到当前目录。
    expect(find.text('保存到此文件夹'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(storage.importDocumentCalls, ['content://wx/9']);
    expect(find.text('分享.pdf'), findsOneWidget);
    expect(find.textContaining('已保存 1 个文件到「子目录」'), findsOneWidget);
  });

  testWidgets('未授权时先弹一次授权再直接保存', (tester) async {
    final storage = FakeStorage()
      ..importResults = [entry('分享.pdf', mime: 'application/pdf')];
    final incoming = FakeIncomingShares();
    addTearDown(incoming.close);
    // 无持久化根目录：首次收到分享应先弹出授权提示。
    Get.put(
      HomeController(
        storage: storage,
        store: MemoryStore(),
        archive: FakeArchive(),
        incoming: incoming,
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
    incoming.emit([const IncomingShare(uri: 'content://wx/7', name: '分享.pdf')]);
    await tester.pumpAndSettle();
    expect(find.text('请先选择存储文件夹'), findsOneWidget);
    // 授权后直接保存，不再二次选择。
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('选择文件夹'),
      ),
    );
    await tester.pumpAndSettle();
    expect(storage.importDocumentCalls, ['content://wx/7']);
    expect(find.text('分享.pdf'), findsOneWidget);
    expect(find.text('保存到此文件夹'), findsNothing);
  });

  testWidgets('视频预览页初始化失败时展示错误态与外部打开入口', (tester) async {
    // 测试环境没有 media_kit 原生库（libmpv），初始化失败应回落到错误态。
    await tester.pumpWidget(
      GetMaterialApp(
        home: VideoView(entry: entry('视频.mp4', mime: 'video/mp4')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('无法播放此视频'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('用其他应用打开'), findsOneWidget);
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

  testWidgets('图片预览页顶部按钮在黑色背景上保持白色图标', (tester) async {
    Get.put<StorageGateway>(FakeStorage(), permanent: true);
    // 浅色主题的 AppBar 图标色为深色；沉浸式黑底仍需白色图标。
    await tester.pumpWidget(
      GetMaterialApp(
        theme: buildLightTheme(FlexScheme.blue),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ImagePreviewView(
                      entry: entry('照片.png', mime: 'image/png'),
                    ),
                  ),
                ),
                child: const Text('打开图片'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开图片'));
    await tester.pumpAndSettle();

    final actionIcon = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.open_in_new),
    );
    expect(IconTheme.of(tester.element(actionIcon)).color, Colors.white);
    expect(
      IconTheme.of(tester.element(find.byType(BackButton))).color,
      Colors.white,
    );
  });

  testWidgets('PDF 预览页顶部按钮在黑色背景上保持白色图标', (tester) async {
    Get.put<StorageGateway>(FakeStorage(), permanent: true);
    // 浅色主题的 AppBar 图标色为深色；沉浸式黑底仍需白色图标。
    await tester.pumpWidget(
      GetMaterialApp(
        theme: buildLightTheme(FlexScheme.blue),
        home: PdfPreviewView(entry: entry('合同.pdf', mime: 'application/pdf')),
      ),
    );
    await tester.pumpAndSettle();

    final actionIcon = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.open_in_new),
    );
    expect(IconTheme.of(tester.element(actionIcon)).color, Colors.white);
  });
}
