part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const home = _Paths.home;
  static const video = '/video';
  static const settings = '/settings';
  static const themePicker = '/settings/theme';
  static const imagePreview = '/preview/image';
  static const pdfPreview = '/preview/pdf';
}

abstract class _Paths {
  _Paths._();
  static const home = '/home';
}
