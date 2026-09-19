import 'package:flutter_localizations/flutter_localizations.dart' as legacy;
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// 应用支持的地区。
///
/// material_ui 只识别语言代码 `zh`，不识别 `zh_CN`，因此这里使用无地区变体，
/// 否则其本地化委托会判定不支持并再次抛错。
const List<Locale> appSupportedLocales = [Locale('zh'), Locale('en')];

/// 应用本地化委托。
///
/// 应用与图片/视频编辑器统一使用 material_ui 的委托（覆盖 Material、Cupertino
/// 与 Widgets 三类文案）；media_kit_video、flutter_markdown_plus 等未迁移依赖
/// 仍按 legacy 类型查找本地化，故保留 legacy 委托兜底，待其迁移后再移除。
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
  legacy.GlobalMaterialLocalizations.delegate,
  legacy.GlobalCupertinoLocalizations.delegate,
];

/// 控件文案入口；随语言切换自动重建。
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
