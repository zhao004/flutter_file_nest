import 'package:drift/drift.dart';

class EntryMetadata extends Table {
  TextColumn get uri => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {uri};
}
