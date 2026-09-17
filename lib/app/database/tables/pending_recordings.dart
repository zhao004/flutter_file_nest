import 'package:drift/drift.dart';

/// 录制完成但尚未确认落盘的任务；不依赖可被系统清除的缓存文件。
class PendingRecordings extends Table {
  TextColumn get operationId => text()();
  TextColumn get sourcePath => text()();
  TextColumn get temporaryPath => text().nullable()();
  TextColumn get rootUri => text()();
  TextColumn get parentDocumentId => text()();
  TextColumn get fileName => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}
