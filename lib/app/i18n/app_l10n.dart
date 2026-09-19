import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// 非控件代码的当前文案入口。
///
/// 控件通过 `context.l10n` 获取文案并随语言切换自动重建；控制器、服务与
/// 模型层没有 BuildContext，统一读取由 [LocaleController] 维护的当前实例。
/// 默认简体中文，保证纯 Dart 测试在未初始化本地化管线时也有稳定文案。
class AppL10n {
  AppL10n._();

  static AppLocalizations _current = lookupAppLocalizations(const Locale('zh'));

  static AppLocalizations get current => _current;

  /// 由 [LocaleController] 在语言变化时调用。
  static void update(Locale locale) =>
      _current = lookupAppLocalizations(locale);
}
