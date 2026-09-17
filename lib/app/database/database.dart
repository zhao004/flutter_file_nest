import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/app_settings.dart';
import 'tables/camera_presets.dart';
import 'tables/entry_metadata.dart';
import 'tables/pending_recordings.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [AppSettings, EntryMetadata, PendingRecordings, CameraPresetRecords],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await customStatement('DROP TABLE IF EXISTS todos');
        await migrator.createAll();
      } else if (from < 3) {
        await migrator.createTable(cameraPresetRecords);
      }
    },
  );

  Future<AppSetting?> loadSettings() => (select(
    appSettings,
  )..where((table) => table.id.equals(1))).getSingleOrNull();

  Future<void> saveSettings(AppSettingsCompanion settings) async {
    await into(appSettings).insertOnConflictUpdate(settings);
  }

  Future<void> saveCreatedEntry(String uri, DateTime createdAt) async {
    await into(entryMetadata).insertOnConflictUpdate(
      EntryMetadataCompanion.insert(uri: uri, createdAt: createdAt),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/app_database.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
