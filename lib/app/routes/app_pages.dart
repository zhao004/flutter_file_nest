import 'package:get/get.dart';

import '../models/media_editor_args.dart';
import '../models/storage_entry.dart';
import '../pages/home/home_binding.dart';
import '../pages/home/home_view.dart';
import '../pages/preview/file_preview_page.dart';
import '../pages/preview/image_editor_view.dart';
import '../pages/preview/text_editor_view.dart';
import '../pages/preview/video_editor_view.dart';
import '../pages/settings/editor_settings_view.dart';
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
    GetPage(
      name: Routes.textEditor,
      page: () => TextEditorView(entry: Get.arguments as StorageEntry),
    ),
    GetPage(
      name: Routes.imageEditor,
      page: () {
        final args = Get.arguments as MediaEditorArgs;
        return ImageEditorView(
          entry: args.entry,
          parent: args.parent,
          onSaved: args.onSaved,
        );
      },
    ),
    GetPage(
      name: Routes.videoEditor,
      page: () {
        final args = Get.arguments as MediaEditorArgs;
        return VideoEditorView(
          entry: args.entry,
          parent: args.parent,
          onSaved: args.onSaved,
        );
      },
    ),
    GetPage(name: Routes.settings, page: () => const SettingsView()),
    GetPage(name: Routes.themePicker, page: () => const ThemePickerView()),
    GetPage(
      name: Routes.editorSettings,
      page: () => const EditorSettingsView(),
    ),
  ];
}
