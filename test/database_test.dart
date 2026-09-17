import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/database/database.dart';
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
      containsAll(['app_settings', 'entry_metadata', 'pending_recordings']),
    );
    expect(tables, isNot(contains('todos')));
    await db.saveSettings(
      AppSettingsCompanion(updatedAt: Value(DateTime.now())),
    );
  });
}
