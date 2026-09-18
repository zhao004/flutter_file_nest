import 'package:drift/drift.dart';

import '../../theme/theme_defaults.dart';

class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get rootUri => text().nullable()();

  TextColumn get sortField => text().withDefault(const Constant('modified'))();

  BoolColumn get sortDescending =>
      boolean().withDefault(const Constant(true))();

  /// 当前配色方案名称；对应 FlexScheme 枚举的 name。
  TextColumn get themeScheme =>
      text().withDefault(const Constant(kDefaultThemeSchemeName))();

  /// 当前外观模式名称；system / light / dark。
  TextColumn get themeMode =>
      text().withDefault(const Constant(kDefaultThemeModeName))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
