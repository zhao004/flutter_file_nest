import 'package:drift/drift.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';

import '../database/database.dart';
import 'app_theme.dart';

/// 应用级主题偏好：配色方案与外观模式。
class ThemePreferences {
  const ThemePreferences({
    this.scheme = kDefaultFlexScheme,
    this.mode = kDefaultThemeMode,
  });

  final FlexScheme scheme;
  final ThemeMode mode;
}

/// 主题偏好读写接口；便于测试注入内存实现。
abstract interface class ThemeStore {
  Future<ThemePreferences> load();
  Future<void> save(ThemePreferences value);
}

/// 基于 Drift 单行设置表的主题偏好实现。
///
/// 与 `VaultStore` 共用 `app_settings` 同一行：保存时只写入本模型字段，
/// 未提供字段由 Drift 保持原值。
class DriftThemeStore implements ThemeStore {
  DriftThemeStore(this.database);

  final AppDatabase database;

  @override
  Future<ThemePreferences> load() async {
    final row = await database.loadSettings();
    if (row == null) return const ThemePreferences();
    return ThemePreferences(
      scheme: flexSchemeFromName(row.themeScheme),
      mode: themeModeFromName(row.themeMode),
    );
  }

  @override
  Future<void> save(ThemePreferences value) => database.saveSettings(
    AppSettingsCompanion(
      id: const Value(1),
      themeScheme: Value(value.scheme.name),
      themeMode: Value(value.mode.name),
      updatedAt: Value(DateTime.now().toUtc()),
    ),
  );
}
