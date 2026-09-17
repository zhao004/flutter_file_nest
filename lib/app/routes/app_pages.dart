import 'package:get/get.dart';

import '../pages/home/home_binding.dart';
import '../pages/home/home_view.dart';
import '../pages/home/home_controller.dart';
import '../models/storage_entry.dart';
import '../pages/camera/app_camera_controller.dart';
import '../pages/camera/camera_driver.dart';
import '../pages/camera/camera_view.dart';
import '../pages/presets/presets_binding.dart';
import '../pages/presets/presets_view.dart';
import '../pages/settings/settings_view.dart';
import '../pages/video/video_view.dart';

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
      name: Routes.camera,
      page: () => const CameraView(),
      binding: BindingsBuilder(() {
        final home = Get.find<HomeController>();
        Get.put(
          AppCameraController(
            folder: Get.arguments as StorageEntry,
            driver: PluginCameraDriver(),
            recordings: home.recordings,
            audio: home.preferences.value.audioEnabled,
            saveAudio: home.setAudio,
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.video,
      page: () => VideoView(entry: Get.arguments as StorageEntry),
    ),
    GetPage(
      name: Routes.presets,
      page: () => const PresetsView(),
      binding: PresetsBinding(),
    ),
    GetPage(name: Routes.settings, page: () => const SettingsView()),
  ];
}
