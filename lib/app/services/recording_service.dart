import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

import '../models/storage_entry.dart';
import 'saf_storage.dart';
import 'vault_store.dart';

/// 在开始录制前登记任务，停止后先转存到私有持久目录，再提交到 SAF。
class RecordingService {
  RecordingService(
    this.storage,
    this.store, {
    Future<Directory> Function()? supportDirectory,
    Future<Directory> Function()? temporaryDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final StorageGateway storage;
  final VaultStore store;
  final Future<Directory> Function() _supportDirectory;
  final Future<Directory> Function() _temporaryDirectory;

  Future<RecordingJob> prepare(StorageEntry folder) async {
    final now = DateTime.now();
    final directory = Directory(
      '${(await _supportDirectory()).path}/recordings',
    );
    await directory.create(recursive: true);
    final id = now.microsecondsSinceEpoch.toString();
    final job = RecordingJob(
      id: id,
      sourcePath: '${directory.path}/$id.mp4',
      rootUri: folder.rootUri,
      parentId: folder.documentId,
      fileName: recordingFileName(now),
      createdAt: now,
    );
    await store.addJob(job);
    return job;
  }

  Future<void> stage(RecordingJob job, XFile file) async {
    final source = File(file.path);
    if (!await source.exists() && await File(job.sourcePath).exists()) return;
    try {
      await source.rename(job.sourcePath);
    } on FileSystemException {
      final partial = File('${job.sourcePath}.partial');
      await file.saveTo(partial.path);
      if (await partial.length() != await source.length()) {
        throw const FileSystemException('Incomplete recording copy');
      }
      await partial.rename(job.sourcePath);
      // 复制完成后才删除缓存源，保存失败时始终保留至少一份视频。
      try {
        if (await source.exists()) await source.delete();
      } catch (_) {
        /* 完整暂存文件已可恢复。 */
      }
    }
  }

  Future<StorageEntry> commit(RecordingJob job) async {
    if (job.temporaryPath != null) await stage(job, XFile(job.temporaryPath!));
    final saved = await storage.saveRecording(job);
    // 元数据缓存与清理失败不能把已完成的文件复制误报为失败。
    try {
      await store.recordCreated(saved.uri, job.createdAt);
    } catch (_) {
      /* SAF 中的文件仍是权威来源。 */
    }
    await store.removeJob(job.id);
    try {
      final source = File(job.sourcePath);
      if (await source.exists()) await source.delete();
      await storage.forgetRecording(job.id);
    } catch (_) {
      /* 已保存视频不受私有残留清理失败影响。 */
    }
    return saved;
  }

  Future<RecordingJob> attachSource(RecordingJob job, XFile source) async {
    final updated = job.withTemporaryPath(source.path);
    await store.addJob(updated);
    return updated;
  }

  Future<void> discard(RecordingJob job) async {
    // 仅删除本应用自己登记的私有录制文件，绝不删除目标目录中的用户文件。
    final directory = await _supportDirectory();
    final expected = File(
      '${directory.path}/recordings/${job.id}.mp4',
    ).absolute.path;
    if (File(job.sourcePath).absolute.path != expected) {
      throw const FileSystemException('Invalid recording path');
    }
    final temporaryPath = job.temporaryPath;
    if (temporaryPath != null) {
      final temporary = File(temporaryPath);
      if (await temporary.exists()) {
        final cache = await (await _temporaryDirectory())
            .resolveSymbolicLinks();
        var parent = File(await temporary.resolveSymbolicLinks()).parent;
        while (parent.path != cache && parent.parent.path != parent.path) {
          parent = parent.parent;
        }
        if (parent.path != cache) {
          throw const FileSystemException('Invalid temporary recording path');
        }
        await temporary.delete();
      }
    }
    final file = File(expected);
    if (await file.exists()) await file.delete();
    final partial = File('$expected.partial');
    if (await partial.exists()) await partial.delete();
    await store.removeJob(job.id);
    await storage.forgetRecording(job.id);
  }
}
