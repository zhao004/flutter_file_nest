import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/storage_entry.dart';

class VaultPreferences {
  const VaultPreferences({
    this.rootUri,
    this.sort = EntrySort.modified,
    this.descending = true,
  });
  final String? rootUri;
  final EntrySort sort;
  final bool descending;

  VaultPreferences copyWith({
    String? rootUri,
    EntrySort? sort,
    bool? descending,
  }) => VaultPreferences(
    rootUri: rootUri ?? this.rootUri,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
  );
}

abstract interface class VaultStore {
  Future<VaultPreferences> loadPreferences();
  Future<void> savePreferences(VaultPreferences value);
  Future<void> recordCreated(String uri, DateTime time);

  /// 查询本应用登记的创建时间；返回值仅包含已登记的 URI。
  /// 用于创建时间排序与详情展示，外部文件无依据时保持未知。
  Future<Map<String, DateTime>> createdTimes(Iterable<String> uris);
}

class DriftVaultStore implements VaultStore {
  DriftVaultStore(this.database);
  final AppDatabase database;

  @override
  Future<VaultPreferences> loadPreferences() async {
    final row = await database.loadSettings();
    if (row == null) return const VaultPreferences();
    return VaultPreferences(
      rootUri: row.rootUri,
      sort:
          EntrySort.values
              .where((value) => value.name == row.sortField)
              .firstOrNull ??
          EntrySort.modified,
      descending: row.sortDescending,
    );
  }

  @override
  Future<void> savePreferences(VaultPreferences value) => database.saveSettings(
    AppSettingsCompanion(
      id: const Value(1),
      rootUri: Value(value.rootUri),
      sortField: Value(value.sort.name),
      sortDescending: Value(value.descending),
      updatedAt: Value(DateTime.now().toUtc()),
    ),
  );

  @override
  Future<void> recordCreated(String uri, DateTime time) =>
      database.saveCreatedEntry(uri, time.toUtc());

  @override
  Future<Map<String, DateTime>> createdTimes(Iterable<String> uris) async {
    final keys = uris.toSet().toList();
    if (keys.isEmpty) return const {};
    final rows = await (database.select(
      database.entryMetadata,
    )..where((table) => table.uri.isIn(keys))).get();
    return {for (final row in rows) row.uri: row.createdAt.toLocal()};
  }
}
