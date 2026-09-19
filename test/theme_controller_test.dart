import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/theme/app_theme.dart';
import 'package:filenest/app/theme/theme_controller.dart';
import 'package:filenest/app/theme/theme_store.dart';

import 'support/fakes.dart';

void main() {
  test('读取持久化主题并按配色构建浅深主题', () async {
    final store = MemoryThemeStore()
      ..value = const ThemePreferences(
        scheme: FlexScheme.blueM3,
        mode: ThemeMode.dark,
      );
    final controller = ThemeController(store);
    await controller.initialize();

    expect(controller.scheme.value, FlexScheme.blueM3);
    expect(controller.mode.value, ThemeMode.dark);
    expect(controller.lightTheme.brightness, Brightness.light);
    expect(controller.darkTheme.brightness, Brightness.dark);
  });

  test('切换配色与模式会持久化且互相保留', () async {
    final store = MemoryThemeStore();
    final controller = ThemeController(store);
    await controller.initialize();

    await controller.setScheme(FlexScheme.purpleM3);
    expect(store.value.scheme, FlexScheme.purpleM3);

    await controller.setMode(ThemeMode.light);
    expect(store.value.mode, ThemeMode.light);
    // 保存模式时保留上一次选中的配色。
    expect(store.value.scheme, FlexScheme.purpleM3);
    expect(store.saves, 2);
  });

  test('重复设置相同值不落盘', () async {
    final store = MemoryThemeStore();
    final controller = ThemeController(store);
    await controller.initialize();

    await controller.setScheme(kDefaultFlexScheme);
    await controller.setMode(kDefaultThemeMode);
    expect(store.saves, 0);
  });

  test('持久化失败时回退到上一个值', () async {
    final store = MemoryThemeStore()..failSaves = true;
    final controller = ThemeController(store);
    await controller.initialize();

    await controller.setScheme(FlexScheme.redM3);
    expect(controller.scheme.value, kDefaultFlexScheme);

    await controller.setMode(ThemeMode.dark);
    expect(controller.mode.value, kDefaultThemeMode);
  });

  test('未知持久化取值回落到默认', () {
    expect(flexSchemeFromName('not-a-scheme'), kDefaultFlexScheme);
    expect(themeModeFromName('weird'), kDefaultThemeMode);
    expect(flexSchemeFromName(null), kDefaultFlexScheme);
    expect(themeModeFromName(null), kDefaultThemeMode);
  });
}
