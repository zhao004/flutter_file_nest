import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

import '../l10n/generated/app_localizations.dart';

/// 应用支持的地区。
///
/// material_ui 只识别语言代码 `zh`，不识别 `zh_CN`，因此这里使用无地区变体，
/// 否则其本地化委托会判定不支持并再次抛错。
const List<Locale> appSupportedLocales = [Locale('zh'), Locale('en')];

/// 应用本地化委托。
///
/// 应用自身基于 legacy `flutter/material.dart`，而图片/视频编辑器基于
/// `material_ui`，两者的 `MaterialLocalizations` 类型不同，必须同时注册两组
/// 委托；只保留其中一组会让另一侧抛 `No MaterialLocalizations found`。
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  ...material_ui.GlobalMaterialLocalizations.delegates,
];

/// 控件文案入口；随语言切换自动重建。
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
