/// 应用路由路径常量；供路由表与页面导航共用。
abstract class Routes {
  Routes._();
  static const home = '/home';
  static const preview = '/preview';
  static const textEditor = '/preview/edit';
  static const imageEditor = '/preview/edit-image';
  static const videoEditor = '/preview/edit-video';
  static const settings = '/settings';
  static const themePicker = '/settings/theme';
  static const editorSettings = '/settings/editor';
}
