import 'package:drift/drift.dart';

/// 用户拍摄预设；内置预设在代码中维护，不写入本表，避免升级覆盖用户配置。
///
/// 类名使用 Records 后缀以避免与业务模型 CameraPreset 冲突；
/// SQL 表名仍为 camera_presets。
class CameraPresetRecords extends Table {
  @override
  String get tableName => 'camera_presets';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get configVersion => integer()();
  TextColumn get configJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
