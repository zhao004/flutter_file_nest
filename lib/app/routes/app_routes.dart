part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const home = _Paths.home;
  static const camera = '/camera';
  static const video = '/video';
  static const settings = '/settings';
}

abstract class _Paths {
  _Paths._();
  static const home = '/home';
}
