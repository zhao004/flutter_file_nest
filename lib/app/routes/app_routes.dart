part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const home = _Paths.home;
  static const preview = '/preview';
  static const settings = '/settings';
  static const themePicker = '/settings/theme';
}

abstract class _Paths {
  _Paths._();
  static const home = '/home';
}
