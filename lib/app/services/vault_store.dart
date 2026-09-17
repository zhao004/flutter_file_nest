import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/camera_presets.dart';
import '../models/storage_entry.dart';

class VaultPreferences {
  const VaultPreferences({
    this.rootUri,
    this.audioEnabled = true,
    this.sort = EntrySort.modified,
    this.descending = true,
  });
  final String? rootUri;
  final bool audioEnabled;
  final EntrySort sort;
  final bool descending;

  VaultPreferences copyWith({
    String? rootUri,
    bool? audioEnabled,
    EntrySort? sort,
    bool? descending,
  }) => VaultPreferences(
    rootUri: rootUri ?? this.rootUri,
    audioEnabled: audioEnabled ?? this.audioEnabled,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
  );
}

/// 可重试的落盘任务；sourcePath 仅指向应用私有的 recordings 目录。
class RecordingJob {
  const RecordingJob({
    required this.id,
    required this.sourcePath,
    required this.rootUri,
    required this.parentId,
    required this.fileName,
    required this.createdAt,
    this.temporaryPath,
  });
  final String id;
  final String sourcePath;
  final String rootUri;
  final String parentId;
  final String fileName;
  final DateTime createdAt;
  final String? temporaryPath;

  RecordingJob withTemporaryPath(String path) => RecordingJob(
    id: id,
    sourcePath: sourcePath,
    rootUri: rootUri,
    parentId: parentId,
    fileName: fileName,
    createdAt: createdAt,
    temporaryPath: path,
  );
}

abstract interface class VaultStore {
  Future<VaultPreferences> loadPreferences();
  Future<void> savePreferences(VaultPreferences value);
  Future<List<RecordingJob>> pendingJobs();
  Future<void> addJob(RecordingJob job);
  Future<void> removeJob(String id);
  Future<void> recordCreated(String uri, DateTime time);

  /// 用户预设，按最近更新排序；内置预设不在此列。
  Future<List<CameraPreset>> userPresets();

  /// 新增或覆盖用户预设；同名不合并，由 id 决定覆盖目标。
  Future<void> savePreset(CameraPreset preset);

  Future<void> deletePreset(String id);
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
      audioEnabled: row.audioEnabled,
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
      audioEnabled: Value(value.audioEnabled),
      sortField: Value(value.sort.name),
      sortDescending: Value(value.descending),
      updatedAt: Value(DateTime.now().toUtc()),
    ),
  );

  @override
  Future<List<RecordingJob>> pendingJobs() async =>
      (await database.select(database.pendingRecordings).get())
          .map(
            (row) => RecordingJob(
              id: row.operationId,
              sourcePath: row.sourcePath,
              rootUri: row.rootUri,
              parentId: row.parentDocumentId,
              fileName: row.fileName,
              createdAt: row.createdAt,
              temporaryPath: row.temporaryPath,
            ),
          )
          .toList();

  @override
  Future<void> addJob(RecordingJob job) async {
    await database
        .into(database.pendingRecordings)
        .insertOnConflictUpdate(
          PendingRecordingsCompanion.insert(
            operationId: job.id,
            sourcePath: job.sourcePath,
            rootUri: job.rootUri,
            parentDocumentId: job.parentId,
            fileName: job.fileName,
            createdAt: job.createdAt.toUtc(),
            temporaryPath: Value(job.temporaryPath),
          ),
        );
  }

  @override
  Future<void> removeJob(String id) async {
    await (database.delete(
      database.pendingRecordings,
    )..where((row) => row.operationId.equals(id))).go();
  }

  @override
  Future<void> recordCreated(String uri, DateTime time) =>
      database.saveCreatedEntry(uri, time.toUtc());

  @override
  Future<List<CameraPreset>> userPresets() async {
    final rows = await (database.select(
      database.cameraPresetRecords,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get();
    return rows.map(_presetFromRow).toList();
  }

  CameraPreset _presetFromRow(CameraPresetRecord row) {
    final decoded = PresetConfig.decode(row.configJson);
    return CameraPreset(
      id: row.id,
      name: row.name,
      configVersion: row.configVersion,
      config: decoded.config,
      issue: decoded.ok ? null : decoded.message,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> savePreset(CameraPreset preset) async {
    final config = preset.config;
    if (config == null) {
      throw StateError('不能保存配置损坏的预设');
    }
    await database
        .into(database.cameraPresetRecords)
        .insertOnConflictUpdate(
          CameraPresetRecordsCompanion.insert(
            id: preset.id,
            name: preset.name,
            configVersion: presetConfigVersion,
            configJson: config.encode(),
            createdAt: preset.createdAt.toUtc(),
            updatedAt: preset.updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> deletePreset(String id) async {
    await (database.delete(
      database.cameraPresetRecords,
    )..where((row) => row.id.equals(id))).go();
  }
}
