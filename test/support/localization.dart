import 'package:filenest/app/localization.dart';
import 'package:filenest/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 测试用简体中文文案；用于直接调用本地化函数的断言。
final AppLocalizations zhL10n = lookupAppLocalizations(const Locale('zh'));

/// 以应用本地化配置包裹 [home]；测试默认使用简体中文，保证中文断言稳定。
///
/// 需要路由的用例请使用 `MaterialApp.router` 自行配置，并传入相同的
/// [appLocalizationsDelegates] 与 `locale: const Locale('zh')`。
Widget localizedApp(
  Widget home, {
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.system,
}) => MaterialApp(
  locale: const Locale('zh'),
  theme: theme,
  darkTheme: darkTheme,
  themeMode: themeMode,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: appSupportedLocales,
  home: home,
);
