import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_theme.dart';
import 'theme_store.dart';

/// 持有应用主题状态并负责持久化；切换后重建 [GetMaterialApp]。
///
/// 状态先写内存再落盘，落盘失败时回退到上一个值，避免界面与持久化不一致。
class ThemeController extends GetxController {
  ThemeController(this._store);

  final ThemeStore _store;

  /// 当前配色方案。
  final scheme = kDefaultFlexScheme.obs;

  /// 当前外观模式。
  final mode = kDefaultThemeMode.obs;

  ThemeData get lightTheme => buildLightTheme(scheme.value);

  ThemeData get darkTheme => buildDarkTheme(scheme.value);

  /// 读取持久化主题；失败时保留默认值，不阻断启动。
  Future<void> initialize() async {
    try {
      final stored = await _store.load();
      scheme.value = stored.scheme;
      mode.value = stored.mode;
    } catch (failure) {
      debugPrint('读取主题设置失败：$failure');
    }
  }

  /// 切换配色并持久化；失败时回退。
  Future<void> setScheme(FlexScheme value) async {
    if (value == scheme.value) return;
    final previous = scheme.value;
    scheme.value = value;
    try {
      await _store.save(ThemePreferences(scheme: value, mode: mode.value));
    } catch (failure) {
      scheme.value = previous;
      debugPrint('保存主题设置失败：$failure');
    }
  }

  /// 切换外观模式并持久化；失败时回退。
  Future<void> setMode(ThemeMode value) async {
    if (value == mode.value) return;
    final previous = mode.value;
    mode.value = value;
    try {
      await _store.save(ThemePreferences(scheme: scheme.value, mode: value));
    } catch (failure) {
      mode.value = previous;
      debugPrint('保存主题设置失败：$failure');
    }
  }
}
