import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// 默认配色方案；内置的 Blue delight（`FlexScheme.blue`）。
const FlexScheme kDefaultFlexScheme = FlexScheme.blue;

/// 默认外观模式；跟随系统。
const ThemeMode kDefaultThemeMode = ThemeMode.system;

/// 全部可选内置配色；排除 custom（需外部提供颜色，选中无视觉效果）。
List<FlexScheme> get selectableFlexSchemes => [
  for (final scheme in FlexScheme.values)
    if (scheme != FlexScheme.custom) scheme,
];

/// 组件主题统一配置：沿用原有 8dp 圆角与左对齐标题。
const FlexSubThemesData _subThemesData = FlexSubThemesData(
  defaultRadius: 8,
  dialogRadius: 8,
  appBarCenterTitle: false,
);

/// 构建指定配色的浅色主题。
ThemeData buildLightTheme(FlexScheme scheme) =>
    FlexThemeData.light(scheme: scheme, subThemesData: _subThemesData);

/// 构建指定配色的深色主题。
ThemeData buildDarkTheme(FlexScheme scheme) =>
    FlexThemeData.dark(scheme: scheme, subThemesData: _subThemesData);

/// 由持久化名称解析配色；未知值回落到 [kDefaultFlexScheme]。
FlexScheme flexSchemeFromName(String? name) => selectableFlexSchemes.firstWhere(
  (scheme) => scheme.name == name,
  orElse: () => kDefaultFlexScheme,
);

/// 由持久化名称解析外观模式；未知值回落到 [kDefaultThemeMode]。
ThemeMode themeModeFromName(String? name) => switch (name) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => kDefaultThemeMode,
};

/// 外观模式的中文名称，用于设置页展示。
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => '浅色',
  ThemeMode.dark => '深色',
  ThemeMode.system => '跟随系统',
};
