import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../database/database.dart';
import '../i18n/locale_controller.dart';
import '../models/update_models.dart';
import '../pages/home/home_controller.dart';
import '../pages/preview/preview_settings_controller.dart';
import '../pages/settings/update_controller.dart';
import '../services/archive_service.dart';
import '../services/incoming_share_service.dart';
import '../services/saf_storage.dart';
import '../services/thumbnail_service.dart';
import '../services/update_api.dart';
import '../services/update_installer.dart';
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
  // 更新检查：启动静默检查与设置页手动触发，安装包在应用内下载后交给系统安装器。
  final updateController = UpdateController(
    api: GitHubUpdateApi(),
    installer: const UpdateInstallerService(),
    build: await _appBuildInfo(),
  );
  getIt.registerSingleton<UpdateController>(updateController);
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

/// 读取应用版本信息用于更新检查；失败时返回空版本，不阻断启动。
Future<AppBuildInfo> _appBuildInfo() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppBuildInfo(
      version: info.version,
      buildNumber: int.tryParse(info.buildNumber),
    );
  } catch (failure) {
    debugPrint('读取应用版本失败：$failure');
    return const AppBuildInfo(version: '');
  }
}
