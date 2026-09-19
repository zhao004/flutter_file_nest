import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/database/database.dart';
import 'package:filenest/app/models/storage_entry.dart';
import 'package:filenest/app/preview/preview_defaults.dart';
import 'package:filenest/app/services/vault_store.dart';
import 'package:filenest/app/theme/app_theme.dart';
import 'package:filenest/app/theme/theme_defaults.dart';
import 'package:filenest/app/theme/theme_store.dart';

Future<Set<String>> _tables(AppDatabase db) async => {
  for (final row
      in await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
          .get())
    row.read<String>('name'),
};

Future<Set<String>> _columns(AppDatabase db, String table) async => {
  for (final row in await db.customSelect('PRAGMA table_info($table)').get())
    row.read<String>('name'),
};

void main() {
  test('Drift 保存设置，重读结果保持一致', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftVaultStore(db);
    expect((await store.loadPreferences()).sort, EntrySort.modified);
    await store.savePreferences(
      const VaultPreferences(
        rootUri: 'content://root',
        sort: EntrySort.name,
        descending: false,
      ),
    );
    final stored = await store.loadPreferences();
    expect(stored.rootUri, 'content://root');
    expect(stored.sort, EntrySort.name);
    expect(stored.descending, false);
  });

  test('schema v1 的模板表迁移到 v7，仅创建现有业务表', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('CREATE TABLE todos (id INTEGER PRIMARY KEY, title TEXT)');
        raw.execute('PRAGMA user_version = 1');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);
    final tables = await _tables(db);
    expect(tables, containsAll(['app_settings', 'entry_metadata']));
    expect(tables, isNot(contains('todos')));
    expect(tables, isNot(contains('camera_presets')));
    expect(tables, isNot(contains('pending_recordings')));
    await db.saveSettings(
      AppSettingsCompanion(updatedAt: Value(DateTime.now())),
    );
  });

  test('schema v5 迁移到 v7 移除相机相关表与设置列，保留既有偏好', () async {
    // 以全新建库的结果作为 entry_metadata 的权威建表语句，避免手写 SQL 漂移。
    final template = AppDatabase.forTesting(NativeDatabase.memory());
    final metadataSql =
        (await template
                .customSelect(
                  "SELECT sql FROM sqlite_master "
                  "WHERE type='table' AND name='entry_metadata'",
                )
                .get())
            .map((row) => row.read<String>('sql'))
            .single;
    await template.close();

    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(metadataSql);
        // v5 的 app_settings 含录音与相机后端字段。
        raw.execute(
          'CREATE TABLE app_settings ('
          'id INTEGER NOT NULL DEFAULT 1, root_uri TEXT, '
          'audio_enabled INTEGER NOT NULL DEFAULT 1, '
          "sort_field TEXT NOT NULL DEFAULT 'modified', "
          'sort_descending INTEGER NOT NULL DEFAULT 1, '
          'pro_camera_enabled INTEGER NOT NULL DEFAULT 0, '
          'system_camera_recording INTEGER NOT NULL DEFAULT 1, '
          'updated_at INTEGER NOT NULL, PRIMARY KEY (id))',
        );
        raw.execute(
          "INSERT INTO app_settings VALUES "
          "(1, 'content://root', 0, 'name', 0, 1, 1, 0)",
        );
        raw.execute(
          'CREATE TABLE camera_presets (id TEXT NOT NULL PRIMARY KEY, '
          'name TEXT NOT NULL, config_version INTEGER NOT NULL, '
          'config_json TEXT NOT NULL, created_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL)',
        );
        raw.execute(
          'CREATE TABLE pending_recordings (operation_id TEXT NOT NULL PRIMARY KEY, '
          'source_path TEXT NOT NULL, root_uri TEXT NOT NULL, '
          'parent_document_id TEXT NOT NULL, file_name TEXT NOT NULL, '
          'created_at INTEGER NOT NULL, temporary_path TEXT)',
        );
        raw.execute('PRAGMA user_version = 5');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);
    final store = DriftVaultStore(db);

    final preferences = await store.loadPreferences();
    expect(preferences.rootUri, 'content://root');
    expect(preferences.sort, EntrySort.name);
    expect(preferences.descending, false);

    final tables = await _tables(db);
    expect(tables, isNot(contains('camera_presets')));
    expect(tables, isNot(contains('pending_recordings')));

    final columns = await _columns(db, 'app_settings');
    expect(
      columns,
      containsAll([
        'id',
        'root_uri',
        'sort_field',
        'sort_descending',
        'updated_at',
      ]),
    );
    expect(columns, isNot(contains('audio_enabled')));
    expect(columns, isNot(contains('pro_camera_enabled')));
    expect(columns, isNot(contains('system_camera_recording')));

    await db.saveSettings(
      AppSettingsCompanion(updatedAt: Value(DateTime.now())),
    );
  });

  test('Drift 保存主题偏好，且与库偏好互不覆盖', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final vault = DriftVaultStore(db);
    final theme = DriftThemeStore(db);

    await vault.savePreferences(
      const VaultPreferences(
        rootUri: 'content://root',
        sort: EntrySort.name,
        descending: false,
      ),
    );
    await theme.save(
      const ThemePreferences(scheme: FlexScheme.blueM3, mode: ThemeMode.dark),
    );

    final loadedTheme = await theme.load();
    expect(loadedTheme.scheme, FlexScheme.blueM3);
    expect(loadedTheme.mode, ThemeMode.dark);

    // 保存主题不应覆盖库偏好。
    final preferences = await vault.loadPreferences();
    expect(preferences.rootUri, 'content://root');
    expect(preferences.sort, EntrySort.name);
    expect(preferences.descending, false);

    // 反向保存库偏好也不应覆盖主题。
    await vault.savePreferences(
      const VaultPreferences(rootUri: 'content://root2'),
    );
    final reloadedTheme = await theme.load();
    expect(reloadedTheme.scheme, FlexScheme.blueM3);
    expect(reloadedTheme.mode, ThemeMode.dark);
  });

  test('schema v6 迁移到 v7 新增主题列并保留既有偏好', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE app_settings ('
          'id INTEGER NOT NULL DEFAULT 1, root_uri TEXT, '
          "sort_field TEXT NOT NULL DEFAULT 'modified', "
          'sort_descending INTEGER NOT NULL DEFAULT 1, '
          'updated_at INTEGER NOT NULL, PRIMARY KEY (id))',
        );
        raw.execute(
          "INSERT INTO app_settings VALUES "
          "(1, 'content://root', 'name', 0, 0)",
        );
        raw.execute('PRAGMA user_version = 6');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    final preferences = await DriftVaultStore(db).loadPreferences();
    expect(preferences.rootUri, 'content://root');
    expect(preferences.sort, EntrySort.name);
    expect(preferences.descending, false);

    // 新增列使用默认值，未破坏既有行。
    final theme = await DriftThemeStore(db).load();
    expect(theme.scheme, kDefaultFlexScheme);
    expect(theme.mode, kDefaultThemeMode);

    final columns = await _columns(db, 'app_settings');
    expect(columns, containsAll(['theme_scheme', 'theme_mode']));
  });

  test('Drift 保存文本预览偏好、编辑器偏好与媒体续播位置', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftVaultStore(db);

    await store.savePreferences(
      const VaultPreferences(
        rootUri: 'content://root',
        textFontSize: 18,
        textWrap: false,
        markdownMode: 'source',
        showLineNumbers: false,
        editorTabWidth: 2,
        editorAutoIndent: false,
      ),
    );
    final loaded = await store.loadPreferences();
    expect(loaded.textFontSize, 18);
    expect(loaded.textWrap, false);
    expect(loaded.markdownMode, 'source');
    expect(loaded.showLineNumbers, false);
    expect(loaded.editorTabWidth, 2);
    expect(loaded.editorAutoIndent, false);

    expect(await store.playbackPosition('content://a'), null);
    await store.savePlaybackPosition(
      'content://a',
      const Duration(seconds: 42),
      duration: const Duration(minutes: 3),
    );
    expect(
      await store.playbackPosition('content://a'),
      const Duration(seconds: 42),
    );

    // 保存续播位置不覆盖库偏好。
    expect((await store.loadPreferences()).rootUri, 'content://root');
  });

  test('schema v7 迁移到 v8 新增续播表与预览偏好列', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE app_settings ('
          'id INTEGER NOT NULL DEFAULT 1, root_uri TEXT, '
          "sort_field TEXT NOT NULL DEFAULT 'modified', "
          'sort_descending INTEGER NOT NULL DEFAULT 1, '
          "theme_scheme TEXT NOT NULL DEFAULT '$kDefaultThemeSchemeName', "
          "theme_mode TEXT NOT NULL DEFAULT '$kDefaultThemeModeName', "
          'updated_at INTEGER NOT NULL, PRIMARY KEY (id))',
        );
        raw.execute(
          "INSERT INTO app_settings VALUES "
          "(1, 'content://root', 'name', 0, "
          "'$kDefaultThemeSchemeName', '$kDefaultThemeModeName', 0)",
        );
        raw.execute('PRAGMA user_version = 7');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);
    final store = DriftVaultStore(db);

    final preferences = await store.loadPreferences();
    expect(preferences.rootUri, 'content://root');
    expect(preferences.sort, EntrySort.name);
    expect(preferences.descending, false);
    // 新增列使用默认值。
    expect(preferences.textFontSize, kDefaultTextFontSize);
    expect(preferences.textWrap, kDefaultTextWrap);
    expect(preferences.markdownMode, kDefaultMarkdownMode);

    expect(await _tables(db), contains('playback_progress'));
    expect(
      await _columns(db, 'app_settings'),
      containsAll(['text_font_size', 'text_wrap', 'markdown_mode']),
    );

    await store.savePlaybackPosition('content://a', const Duration(seconds: 7));
    expect(
      await store.playbackPosition('content://a'),
      const Duration(seconds: 7),
    );
  });

  test('schema v8 迁移到 v9 新增编辑器偏好列', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE app_settings ('
          'id INTEGER NOT NULL DEFAULT 1, root_uri TEXT, '
          "sort_field TEXT NOT NULL DEFAULT 'modified', "
          'sort_descending INTEGER NOT NULL DEFAULT 1, '
          "theme_scheme TEXT NOT NULL DEFAULT '$kDefaultThemeSchemeName', "
          "theme_mode TEXT NOT NULL DEFAULT '$kDefaultThemeModeName', "
          'text_font_size REAL NOT NULL DEFAULT $kDefaultTextFontSize, '
          'text_wrap INTEGER NOT NULL DEFAULT ${kDefaultTextWrap ? 1 : 0}, '
          "markdown_mode TEXT NOT NULL DEFAULT '$kDefaultMarkdownMode', "
          'updated_at INTEGER NOT NULL, PRIMARY KEY (id))',
        );
        raw.execute(
          "INSERT INTO app_settings VALUES "
          "(1, 'content://root', 'name', 0, "
          "'$kDefaultThemeSchemeName', '$kDefaultThemeModeName', "
          "$kDefaultTextFontSize, 1, '$kDefaultMarkdownMode', 0)",
        );
        raw.execute('PRAGMA user_version = 8');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);
    final store = DriftVaultStore(db);

    final preferences = await store.loadPreferences();
    expect(preferences.rootUri, 'content://root');
    // 新增列使用默认值，未破坏既有行。
    expect(preferences.showLineNumbers, kDefaultShowLineNumbers);
    expect(preferences.editorTabWidth, kDefaultEditorTabWidth);
    expect(preferences.editorAutoIndent, kDefaultEditorAutoIndent);

    expect(
      await _columns(db, 'app_settings'),
      containsAll([
        'show_line_numbers',
        'editor_tab_width',
        'editor_auto_indent',
      ]),
    );
  });
}
