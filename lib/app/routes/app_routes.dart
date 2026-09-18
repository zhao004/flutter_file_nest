part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const home = _Paths.home;
  static const camera = '/camera';
  static const video = '/video';
  static const presets = '/presets';
  static const settings = '/settings';
  static const imagePreview = '/preview/image';
  static const pdfPreview = '/preview/pdf';
}

abstract class _Paths {
  _Paths._();
  static const home = '/home';
}
