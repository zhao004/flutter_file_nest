import 'package:go_router/go_router.dart';

import '../models/media_editor_args.dart';
import '../models/storage_entry.dart';
import '../pages/home/home_view.dart';
import '../pages/preview/file_preview_page.dart';
import '../pages/preview/image_editor_view.dart';
import '../pages/preview/text_editor_view.dart';
import '../pages/preview/video_editor_view.dart';
import '../pages/settings/editor_settings_view.dart';
import '../pages/settings/settings_view.dart';
import '../pages/settings/theme_picker_view.dart';
import 'app_routes.dart';

/// 构建应用路由表；页面跳转经 `context.push`，对象参数经 `state.extra` 传入。
///
/// 预览与编辑器路由依赖 `extra` 承载不可序列化的条目对象：状态恢复或外部
/// 直达链接缺少参数时回退首页，避免在构建期抛类型转换异常。外部 intent
/// 传入的未知位置（如微信“用其他方式打开”的 content:// 链接）同样回退首页，
/// 不进入 go_router 默认异常页。
GoRouter createAppRouter() => GoRouter(
  initialLocation: Routes.home,
  onException: (context, state, router) => router.go(Routes.home),
  routes: [
    GoRoute(path: Routes.home, builder: (context, state) => const HomeView()),
    GoRoute(
      path: Routes.preview,
      redirect: (context, state) =>
          state.extra is StorageEntry ? null : Routes.home,
      builder: (context, state) =>
          FilePreviewPage(entry: state.extra! as StorageEntry),
    ),
    GoRoute(
      path: Routes.textEditor,
      redirect: (context, state) =>
          state.extra is StorageEntry ? null : Routes.home,
      builder: (context, state) =>
          TextEditorView(entry: state.extra! as StorageEntry),
    ),
    GoRoute(
      path: Routes.imageEditor,
      redirect: (context, state) =>
          state.extra is MediaEditorArgs ? null : Routes.home,
      builder: (context, state) {
        final args = state.extra! as MediaEditorArgs;
        return ImageEditorView(entry: args.entry, parent: args.parent);
      },
    ),
    GoRoute(
      path: Routes.videoEditor,
      redirect: (context, state) =>
          state.extra is MediaEditorArgs ? null : Routes.home,
      builder: (context, state) {
        final args = state.extra! as MediaEditorArgs;
        return VideoEditorView(entry: args.entry, parent: args.parent);
      },
    ),
    GoRoute(
      path: Routes.settings,
      builder: (context, state) => const SettingsView(),
    ),
    GoRoute(
      path: Routes.themePicker,
      builder: (context, state) => const ThemePickerView(),
    ),
    GoRoute(
      path: Routes.editorSettings,
      builder: (context, state) => const EditorSettingsView(),
    ),
  ],
);
