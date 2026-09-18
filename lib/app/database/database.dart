import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/app_settings.dart';
import 'tables/entry_metadata.dart';
import '../theme/theme_defaults.dart';

part 'database.g.dart';

@DriftDatabase(tables: [AppSettings, EntryMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await customStatement('DROP TABLE IF EXISTS todos');
        await migrator.createAll();
        return;
      }
      if (from < 6) {
        // v6 移除应用内相机：删除拍摄预设与待保存录像。
        await customStatement('DROP TABLE IF EXISTS camera_presets');
        await customStatement('DROP TABLE IF EXISTS pending_recordings');
        // SQLite 不能直接删除旧列；按官方建议重建设置表并迁移保留字段，
        // 移除已废弃的录音与相机后端字段。
        await customStatement(
          'CREATE TABLE app_settings_new ('
          'id INTEGER NOT NULL DEFAULT 1, '
          'root_uri TEXT, '
          "sort_field TEXT NOT NULL DEFAULT 'modified', "
          'sort_descending INTEGER NOT NULL DEFAULT 1, '
          'updated_at INTEGER NOT NULL, '
          'PRIMARY KEY (id))',
        );
        await customStatement(
          'INSERT INTO app_settings_new '
          '(id, root_uri, sort_field, sort_descending, updated_at) '
          'SELECT id, root_uri, sort_field, sort_descending, updated_at '
          'FROM app_settings',
        );
        await customStatement('DROP TABLE app_settings');
        await customStatement(
          'ALTER TABLE app_settings_new RENAME TO app_settings',
        );
      }
      if (from < 7) {
        // v7 新增主题配色与外观模式，默认值由常量统一维护。
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN theme_scheme TEXT NOT NULL '
          "DEFAULT '$kDefaultThemeSchemeName'",
        );
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN theme_mode TEXT NOT NULL '
          "DEFAULT '$kDefaultThemeModeName'",
        );
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
