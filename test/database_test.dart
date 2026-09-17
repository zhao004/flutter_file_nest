import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/database/database.dart';
import 'package:flutter_lens_vault/app/models/camera_capture_settings.dart';
import 'package:flutter_lens_vault/app/models/camera_presets.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/services/vault_store.dart';

void main() {
  test('Drift 保存设置和待保存录像，重读结果保持一致', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftVaultStore(db);
    expect((await store.loadPreferences()).audioEnabled, true);
    await store.savePreferences(
      const VaultPreferences(
        rootUri: 'content://root',
        audioEnabled: false,
        sort: EntrySort.name,
        descending: false,
      ),
    );
    final stored = await store.loadPreferences();
    expect(stored.rootUri, 'content://root');
    expect(stored.audioEnabled, false);
    expect(stored.sort, EntrySort.name);
    await store.addJob(
      RecordingJob(
        id: '1',
        sourcePath: '/private/recordings/1.mp4',
        temporaryPath: '/cache/original.mp4',
        rootUri: 'content://root',
        parentId: 'folder',
        fileName: 'video.mp4',
        createdAt: DateTime.utc(2026),
      ),
    );
    expect((await store.pendingJobs()).single.parentId, 'folder');
    expect(
      (await store.pendingJobs()).single.temporaryPath,
      '/cache/original.mp4',
    );
    await store.removeJob('1');
    expect(await store.pendingJobs(), isEmpty);
  });

  test('schema v1 的模板表迁移到 v2', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('CREATE TABLE todos (id INTEGER PRIMARY KEY, title TEXT)');
        raw.execute('PRAGMA user_version = 1');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final tables = rows.map((row) => row.read<String>('name')).toList();
    expect(
      tables,
      containsAll([
        'app_settings',
        'entry_metadata',
        'pending_recordings',
        'camera_presets',
      ]),
    );
    expect(tables, isNot(contains('todos')));
    await db.saveSettings(
      AppSettingsCompanion(updatedAt: Value(DateTime.now())),
    );
  });

  test('schema v2 迁移到 v3 保留设置与待保存录像并新增预设表', () async {
    // 先取全新建库时三个 v2 表的准确建表语句，避免手写 SQL 与生成代码漂移。
    final template = AppDatabase.forTesting(NativeDatabase.memory());
    final schemaRows = await template
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type='table' "
          "AND name IN ('app_settings','entry_metadata','pending_recordings')",
        )
        .get();
    final statements = schemaRows
        .map((row) => row.read<String>('sql'))
        .toList();
    await template.close();
    expect(statements, hasLength(3));

    final executor = NativeDatabase.memory(
      setup: (raw) {
        for (final statement in statements) {
          raw.execute(statement);
        }
        raw.execute(
          "INSERT INTO app_settings "
          '(id, root_uri, audio_enabled, sort_field, sort_descending, updated_at) '
          "VALUES (1, 'content://root', 0, 'name', 0, 0)",
        );
        raw.execute(
          'INSERT INTO pending_recordings '
          '(operation_id, source_path, root_uri, parent_document_id, file_name, created_at) '
          "VALUES ('1', '/private/1.mp4', 'content://root', 'folder', 'video.mp4', 0)",
        );
        raw.execute('PRAGMA user_version = 2');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);
    final store = DriftVaultStore(db);
    final preferences = await store.loadPreferences();
    expect(preferences.rootUri, 'content://root');
    expect(preferences.audioEnabled, false);
    expect(preferences.sort, EntrySort.name);
    expect((await store.pendingJobs()).single.fileName, 'video.mp4');
    const preset = PresetConfig(quality: CaptureQuality.p720);
    await store.savePreset(
      CameraPreset(
        id: 'user:1',
        name: '迁移后预设',
        configVersion: presetConfigVersion,
        config: preset,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    final presets = await store.userPresets();
    expect(presets.single.name, '迁移后预设');
    expect(presets.single.config, preset);
  });

  test('用户预设增删改与损坏配置的读取', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftVaultStore(db);
    final now = DateTime.utc(2026, 9, 17);
    await store.savePreset(
      CameraPreset(
        id: 'user:1',
        name: '预设一',
        configVersion: presetConfigVersion,
        config: const PresetConfig(zoomRatio: 2),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await store.savePreset(
      CameraPreset(
        id: 'user:2',
        name: '预设二',
        configVersion: presetConfigVersion,
        config: const PresetConfig(),
        createdAt: now,
        updatedAt: now.add(const Duration(days: 1)),
      ),
    );
    // 最近更新在前。
    expect((await store.userPresets()).first.name, '预设二');
    // 覆盖同一 id 保留配置更新。
    await store.savePreset(
      CameraPreset(
        id: 'user:1',
        name: '预设一',
        configVersion: presetConfigVersion,
        config: const PresetConfig(zoomRatio: 3),
        createdAt: now,
        updatedAt: now.add(const Duration(days: 2)),
      ),
    );
    final updated = (await store.userPresets()).first;
    expect(updated.name, '预设一');
    expect(updated.config?.zoomRatio, 3);
    // 损坏 JSON 不抛出，标记为不可用。
    await db
        .into(db.cameraPresetRecords)
        .insert(
          CameraPresetRecordsCompanion.insert(
            id: 'user:bad',
            name: '损坏',
            configVersion: presetConfigVersion,
            configJson: 'broken',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final all = await store.userPresets();
    final broken = all.singleWhere((preset) => preset.id == 'user:bad');
    expect(broken.usable, false);
    expect(broken.issue, isNot(null));
    await store.deletePreset('user:1');
    expect(
      (await store.userPresets()).map((preset) => preset.id),
      isNot(contains('user:1')),
    );
  });
}
