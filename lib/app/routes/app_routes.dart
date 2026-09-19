part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const home = _Paths.home;
  static const preview = '/preview';
  static const textEditor = '/preview/edit';
  static const imageEditor = '/preview/edit-image';
  static const videoEditor = '/preview/edit-video';
  static const settings = '/settings';
  static const themePicker = '/settings/theme';
  static const editorSettings = '/settings/editor';
}

abstract class _Paths {
  _Paths._();
  static const home = '/home';
}
