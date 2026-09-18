import 'package:drift/drift.dart';

class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get rootUri => text().nullable()();

  TextColumn get sortField => text().withDefault(const Constant('modified'))();

  BoolColumn get sortDescending =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
