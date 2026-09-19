import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/app_settings.dart';
import 'tables/entry_metadata.dart';
import 'tables/playback_progress.dart';
import '../i18n/locale_defaults.dart';
import '../preview/preview_defaults.dart';
import '../theme/theme_defaults.dart';

part 'database.g.dart';

@DriftDatabase(tables: [AppSettings, EntryMetadata, PlaybackProgress])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

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
      if (from < 8) {
        // v8 新增媒体续播表与文本预览偏好列，默认值由常量统一维护。
        await migrator.createTable(playbackProgress);
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN text_font_size REAL NOT NULL '
          'DEFAULT $kDefaultTextFontSize',
        );
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN text_wrap INTEGER NOT NULL '
          'DEFAULT ${kDefaultTextWrap ? 1 : 0}',
        );
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN markdown_mode TEXT NOT NULL '
          "DEFAULT '$kDefaultMarkdownMode'",
        );
      }
      if (from < 9) {
        // v9 新增编辑器偏好列，默认值由常量统一维护。
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN show_line_numbers INTEGER '
          'NOT NULL DEFAULT ${kDefaultShowLineNumbers ? 1 : 0}',
        );
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN editor_tab_width INTEGER '
          'NOT NULL DEFAULT $kDefaultEditorTabWidth',
        );
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN editor_auto_indent INTEGER '
          'NOT NULL DEFAULT ${kDefaultEditorAutoIndent ? 1 : 0}',
        );
      }
      if (from < 10) {
        // v10 新增语言偏好列，默认跟随系统。
        await customStatement(
          'ALTER TABLE app_settings ADD COLUMN locale TEXT NOT NULL '
          "DEFAULT '$kDefaultLocaleName'",
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

  /// 读取媒体续播位置；无记录返回 null。
  Future<Duration?> loadPlaybackPosition(String uri) async {
    final row = await (select(
      playbackProgress,
    )..where((table) => table.uri.equals(uri))).getSingleOrNull();
    if (row == null) return null;
    return Duration(milliseconds: row.positionMs);
  }

  /// 写入或覆盖媒体续播位置；[duration] 未知时传 null。
  Future<void> savePlaybackPosition(
    String uri,
    Duration position, {
    Duration? duration,
  }) => into(playbackProgress).insertOnConflictUpdate(
    PlaybackProgressCompanion.insert(
      uri: uri,
      positionMs: Value(position.inMilliseconds),
      durationMs: Value(duration?.inMilliseconds ?? 0),
      updatedAt: DateTime.now().toUtc(),
    ),
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/app_database.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
