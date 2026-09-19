import 'package:filenest/app/i18n/app_l10n.dart';
import 'package:filenest/app/i18n/locale_controller.dart';
import 'package:filenest/app/i18n/locale_defaults.dart';
import 'package:filenest/app/localization.dart';
import 'package:filenest/app/services/vault_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// 保存失败的内存存储；用于覆盖语言切换的回退路径。
class _FailingStore extends MemoryStore {
  @override
  Future<void> savePreferences(VaultPreferences value) async {
    throw StateError('save failed');
  }
}

void main() {
  tearDown(() => AppL10n.update(const Locale('zh')));

  test('读取持久化语言并按偏好解析', () async {
    final store = MemoryStore()
      ..value = const VaultPreferences(locale: kLocaleEnglishName);
    final controller = LocaleController(store);
    await controller.initialize();

    expect(controller.localeName.value, kLocaleEnglishName);
    expect(controller.locale.value, const Locale(kLocaleEnglishName));
    expect(AppL10n.current.settingsLanguage, 'Language');
  });

  test('system 偏好解析为受支持的语言', () async {
    final controller = LocaleController(MemoryStore());
    await controller.initialize();

    expect(controller.localeName.value, kLocaleSystemName);
    expect(controller.locale.value, isNull);
    expect(
      appSupportedLocales.contains(resolveLocale(kLocaleSystemName)),
      true,
    );
  });

  test('切换语言会持久化并同步文案入口', () async {
    final store = MemoryStore();
    final controller = LocaleController(store);
    await controller.initialize();

    await controller.setLocaleName(kLocaleEnglishName);

    expect(store.value.locale, kLocaleEnglishName);
    expect(controller.locale.value, const Locale(kLocaleEnglishName));
    expect(AppL10n.current.settingsLanguage, 'Language');
  });

  test('持久化失败时回退到上一个值', () async {
    final controller = LocaleController(_FailingStore());
    await controller.initialize();

    await controller.setLocaleName(kLocaleEnglishName);

    expect(controller.localeName.value, kLocaleSystemName);
    expect(controller.locale.value, isNull);
  });
}
