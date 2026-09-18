import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

import 'app/routes/app_pages.dart';
import 'app/database/database.dart';
import 'app/pages/preview/preview_settings_controller.dart';
import 'app/services/archive_service.dart';
import 'app/services/incoming_share_service.dart';
import 'app/services/saf_storage.dart';
import 'app/services/thumbnail_service.dart';
import 'app/services/vault_store.dart';
import 'app/theme/theme_controller.dart';
import 'app/theme/theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit 使用 libmpv，需在创建 Player 前完成初始化。
  MediaKit.ensureInitialized();
  final storage = SafStorage();
  Get.put<StorageGateway>(storage, permanent: true);
  Get.put<ThumbnailGateway>(ThumbnailService(storage), permanent: true);
  // 主题与库偏好共用同一数据库连接。
  final database = AppDatabase();
  Get.put<VaultStore>(DriftVaultStore(database), permanent: true);
  // 预览显示偏好与库偏好共用同一存储，启动时注册为常驻实例。
  Get.put<PreviewSettingsController>(
    PreviewSettingsController(Get.find<VaultStore>()),
    permanent: true,
  );
  final themeController = Get.put<ThemeController>(
    ThemeController(DriftThemeStore(database)),
    permanent: true,
  );
  Get.put<ArchiveGateway>(ArchiveService(), permanent: true);
  Get.put<IncomingShareGateway>(const IncomingShareService(), permanent: true);
  // 首帧前完成主题加载，避免启动时先亮后暗的闪烁。
  await themeController.initialize();
  runApp(const LensVaultApp());
}

/// Android 文件与录制应用入口；功能控制器通过各页 Binding 管理生命周期。
class LensVaultApp extends StatelessWidget {
  const LensVaultApp({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final theme = Get.find<ThemeController>();
    return GetMaterialApp(
      title: 'LensVault',
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: theme.mode.value,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  });
}
