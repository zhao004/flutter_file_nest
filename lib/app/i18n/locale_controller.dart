import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../localization.dart';
import '../services/vault_store.dart';
import 'app_l10n.dart';
import 'locale_defaults.dart';

/// 持有语言偏好并负责持久化；切换后重建应用根 Widget 以更新界面文案。
///
/// 状态先写内存再落盘，落盘失败时回退到上一个值，避免界面与持久化不一致。
class LocaleController {
  LocaleController(this._store);

  final VaultStore _store;

  /// 当前语言偏好名称：system / zh / en。
  final localeName = signal(kDefaultLocaleName);

  /// 传给 MaterialApp 的语言；null 表示跟随系统。
  late final locale = computed<Locale?>(() => localeForName(localeName.value));

  /// 读取持久化语言；失败时保留默认值，并同步非控件文案入口。
  Future<void> initialize() async {
    try {
      localeName.value = (await _store.loadPreferences()).locale;
    } catch (failure) {
      debugPrint('读取语言设置失败：$failure');
    }
    syncCurrent();
  }

  /// 切换语言并持久化；失败时回退。
  Future<void> setLocaleName(String value) async {
    if (value == localeName.value) return;
    final previous = localeName.value;
    localeName.value = value;
    syncCurrent();
    try {
      final current = await _store.loadPreferences();
      await _store.savePreferences(current.copyWith(locale: value));
    } catch (failure) {
      localeName.value = previous;
      syncCurrent();
      debugPrint('保存语言设置失败：$failure');
    }
  }

  /// 解析当前偏好为实际语言并刷新非控件文案；系统语言变化时由根 Widget 调用。
  void syncCurrent() => AppL10n.update(resolveLocale(localeName.value));
}

/// 语言偏好名称解析为实际生效的 [Locale]；system 时按系统语言匹配支持列表。
Locale resolveLocale(String name) => switch (name) {
  kLocaleChineseName => const Locale(kLocaleChineseName),
  kLocaleEnglishName => const Locale(kLocaleEnglishName),
  _ => _systemLocale(),
};

Locale _systemLocale() {
  final preferred = PlatformDispatcher.instance.locales;
  if (preferred.isEmpty) {
    return const Locale(kLocaleChineseName);
  }
  return basicLocaleListResolution(preferred, appSupportedLocales);
}
