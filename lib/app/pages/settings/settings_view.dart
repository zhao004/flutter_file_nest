import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../di/injector.dart';
import '../../i18n/locale_controller.dart';
import '../../i18n/locale_defaults.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../localization.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../home/home_controller.dart';
import '../preview/preview_settings_controller.dart';

/// 管理活动根目录、外观、语言与编辑器入口；文件导入与录制均交由系统应用完成。
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  HomeController get controller => getIt<HomeController>();

  @override
  Widget build(BuildContext context) {
    final theme = getIt<ThemeController>();
    final editor = getIt<PreviewSettingsController>();
    final locale = getIt<LocaleController>();
    return SignalBuilder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.settingsTitle)),
        body: ListView(
          children: [
            if (controller.busy.value) const LinearProgressIndicator(),
            if (controller.error.value != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  controller.error.value!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(context.l10n.settingsStorageFolder),
              subtitle: Text(
                controller.folders.value.firstOrNull?.name ??
                    context.l10n.settingsNotSelected,
              ),
              trailing: const Icon(Icons.chevron_right),
              enabled: !controller.busy.value,
              onTap: controller.pickRoot,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(context.l10n.settingsColorScheme),
              subtitle: Text(theme.scheme.value.data.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push<void>(Routes.themePicker),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(context.l10n.settingsAppearance),
              subtitle: Text(themeModeLabel(theme.mode.value, context.l10n)),
              onTap: () => _pickMode(context, theme),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(context.l10n.settingsLanguage),
              subtitle: Text(
                localeLabel(context.l10n, locale.localeName.value),
              ),
              onTap: () => _pickLanguage(context, locale),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(context.l10n.settingsEditor),
              subtitle: Text(
                context.l10n.settingsFontSizeValue(
                  editor.fontSize.value.round(),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push<void>(Routes.editorSettings),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择跟随系统/浅色/深色；取消不改变当前模式。
  Future<void> _pickMode(BuildContext context, ThemeController theme) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.settingsAppearance),
        children: [
          for (final mode in ThemeMode.values)
            ListTile(
              title: Text(themeModeLabel(mode, dialogContext.l10n)),
              trailing: mode == theme.mode.value
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(dialogContext, mode),
            ),
        ],
      ),
    );
    if (selected != null) await theme.setMode(selected);
  }

  /// 选择跟随系统/简体中文/English；取消不改变当前语言。
  Future<void> _pickLanguage(
    BuildContext context,
    LocaleController locale,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.settingsLanguage),
        children: [
          for (final name in kSelectableLocaleNames)
            ListTile(
              title: Text(localeLabel(dialogContext.l10n, name)),
              trailing: name == locale.localeName.value
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(dialogContext, name),
            ),
        ],
      ),
    );
    if (selected != null) await locale.setLocaleName(selected);
  }
}

/// 语言偏好名称的展示文案；语言名称始终以自身语言展示。
String localeLabel(AppLocalizations l10n, String name) => switch (name) {
  kLocaleChineseName => l10n.languageChinese,
  kLocaleEnglishName => l10n.languageEnglish,
  _ => l10n.languageSystem,
};
