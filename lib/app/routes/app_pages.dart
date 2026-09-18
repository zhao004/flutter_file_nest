import 'package:get/get.dart';

import '../models/storage_entry.dart';
import '../pages/home/home_binding.dart';
import '../pages/home/home_view.dart';
import '../pages/preview/file_preview_page.dart';
import '../pages/settings/settings_view.dart';
import '../pages/settings/theme_picker_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = [
    GetPage(
      name: _Paths.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.preview,
      page: () => FilePreviewPage(entry: Get.arguments as StorageEntry),
    ),
    GetPage(name: Routes.settings, page: () => const SettingsView()),
    GetPage(name: Routes.themePicker, page: () => const ThemePickerView()),
  ];
}
