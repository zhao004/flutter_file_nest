import 'package:drift/drift.dart';

class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get rootUri => text().nullable()();

  BoolColumn get audioEnabled => boolean().withDefault(const Constant(true))();

  TextColumn get sortField => text().withDefault(const Constant('modified'))();

  BoolColumn get sortDescending =>
      boolean().withDefault(const Constant(true))();

  /// 是否启用专业原生相机后端（实验特性）；默认关闭，待真机验收后调整。
  BoolColumn get proCameraEnabled =>
      boolean().withDefault(const Constant(false))();

  /// 录制时是否直接调用系统相机；关闭则使用应用内相机（支持专业参数）。
  BoolColumn get systemCameraRecording =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
