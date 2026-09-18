import 'package:drift/drift.dart';

import '../../preview/preview_defaults.dart';
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

  /// 文本/代码预览字号（逻辑像素）。
  RealColumn get textFontSize =>
      real().withDefault(const Constant(kDefaultTextFontSize))();

  /// 文本预览是否自动换行；关闭时改为横向滚动。
  BoolColumn get textWrap =>
      boolean().withDefault(const Constant(kDefaultTextWrap))();

  /// Markdown 展示模式；read（阅读）或 source（源码）。
  TextColumn get markdownMode =>
      text().withDefault(const Constant(kDefaultMarkdownMode))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
