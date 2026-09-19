import 'package:filenest/app/di/injector.dart';
import 'package:filenest/app/localization.dart';
import 'package:filenest/app/models/media_editor_args.dart';
import 'package:filenest/app/models/update_models.dart';
import 'package:filenest/app/pages/home/home_controller.dart';
import 'package:filenest/app/pages/preview/image_editor_view.dart';
import 'package:filenest/app/pages/settings/update_controller.dart';
import 'package:filenest/app/routes/app_router.dart';
import 'package:filenest/app/routes/app_routes.dart';
import 'package:filenest/app/services/saf_storage.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/archive_fakes.dart';
import 'support/fakes.dart';

void main() {
  late FakeStorage storage;

  setUp(() {
    storage = FakeStorage()
      ..cacheExportFailure = PlatformException(
        code: 'export_failed',
        message: '导出失败',
      );
    getIt.registerSingleton<StorageGateway>(storage);
    getIt.registerSingleton<HomeController>(
      HomeController(
        storage: storage,
        store: MemoryStore(),
        archive: FakeArchive(),
      ),
    );
    // 首页启动静默检查更新；默认已是最新，不弹窗、不干扰用例。
    getIt.registerSingleton<UpdateController>(
      UpdateController(
        api: FakeUpdateApi(),
        installer: FakeUpdateInstaller(),
        build: const AppBuildInfo(version: '1.0.0'),
      ),
    );
  });

  tearDown(() => getIt.reset());

  /// 回归：编辑路由必须能携带 [MediaEditorArgs] 以 `extra` 进入且无异常；
  /// 图片编辑器不应被分发成其他类型（如视频）。
  testWidgets('图片编辑路由经 extra 携带参数可正常进入', (tester) async {
    final router = createAppRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('zh'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        routerConfig: router,
      ),
    );
    expect(find.text('FileNest'), findsOneWidget);

    router.push(
      Routes.imageEditor,
      extra: MediaEditorArgs(entry: entry('photo.jpg'), parent: root),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ImageEditorView), findsOneWidget);
    expect(find.text('编辑视频'), findsNothing);
  });
}
