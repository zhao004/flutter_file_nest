import 'dart:async';

import 'package:get_it/get_it.dart';

import '../database/database.dart';
import '../i18n/locale_controller.dart';
import '../pages/home/home_controller.dart';
import '../pages/preview/preview_settings_controller.dart';
import '../services/archive_service.dart';
import '../services/incoming_share_service.dart';
import '../services/saf_storage.dart';
import '../services/thumbnail_service.dart';
import '../services/vault_store.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_store.dart';

/// 应用级服务定位器；视图与路由通过它读取已注册的依赖。
///
/// 测试中可直接注册替代实现，并在 tearDown 调用 `getIt.reset()` 隔离用例。
final GetIt getIt = GetIt.instance;

/// 注册应用级依赖；必须在 `runApp` 前调用。
///
/// 主题在首帧前完成读取，避免启动时先亮后暗的闪烁；预览显示偏好与库偏好
/// 共用同一存储，加载失败时保留默认值，不阻断启动。
Future<void> configureDependencies() async {
  final storage = SafStorage();
  getIt.registerSingleton<StorageGateway>(storage);
  getIt.registerSingleton<ThumbnailGateway>(ThumbnailService(storage));
  // 主题与库偏好共用同一数据库连接。
  final database = AppDatabase();
  getIt.registerSingleton<VaultStore>(DriftVaultStore(database));

  final previewSettings = PreviewSettingsController(getIt<VaultStore>());
  getIt.registerSingleton<PreviewSettingsController>(previewSettings);
  unawaited(previewSettings.load());

  final themeController = ThemeController(DriftThemeStore(database));
  getIt.registerSingleton<ThemeController>(themeController);
  await themeController.initialize();

  // 语言偏好读取必须在首帧前完成，避免界面先中文后英文的闪烁。
  final localeController = LocaleController(getIt<VaultStore>());
  getIt.registerSingleton<LocaleController>(localeController);
  await localeController.initialize();

  getIt.registerSingleton<ArchiveGateway>(ArchiveService());
  getIt.registerSingleton<IncomingShareGateway>(const IncomingShareService());
  // 首页控制器持有目录导航与列表状态，首次进入首页路由时创建。
  getIt.registerLazySingleton<HomeController>(
    () => HomeController(
      storage: getIt<StorageGateway>(),
      store: getIt<VaultStore>(),
      archive: getIt<ArchiveGateway>(),
      thumbnails: getIt<ThumbnailGateway>(),
      incoming: getIt<IncomingShareGateway>(),
    ),
  );
}
