import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/database/database.dart';
import 'app/services/archive_service.dart';
import 'app/services/incoming_share_service.dart';
import 'app/services/saf_storage.dart';
import 'app/services/thumbnail_service.dart';
import 'app/services/vault_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SafStorage();
  Get.put<StorageGateway>(storage, permanent: true);
  Get.put<ThumbnailGateway>(ThumbnailService(storage), permanent: true);
  Get.put<VaultStore>(DriftVaultStore(AppDatabase()), permanent: true);
  Get.put<ArchiveGateway>(ArchiveService(), permanent: true);
  Get.put<IncomingShareGateway>(const IncomingShareService(), permanent: true);
  runApp(const LensVaultApp());
}

/// Android 文件与录制应用入口；功能控制器通过各页 Binding 管理生命周期。
class LensVaultApp extends StatelessWidget {
  const LensVaultApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'Lens Vault',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff16766c)),
      scaffoldBackgroundColor: const Color(0xfff6f7f8),
      appBarTheme: const AppBarTheme(centerTitle: false),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
    initialRoute: AppPages.initial,
    getPages: AppPages.routes,
  );
}
