import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/services/recording_service.dart';
import 'support/fakes.dart';

void main() {
  late Directory directory;
  late MemoryStore store;
  late FakeStorage storage;
  late RecordingService recordings;
  setUp(() async {
    final base = await Directory(
      '.cache/recording-tests',
    ).create(recursive: true);
    directory = await base.createTemp('recording-');
    store = MemoryStore();
    storage = FakeStorage();
    recordings = RecordingService(
      storage,
      store,
      supportDirectory: () async => directory,
      temporaryDirectory: () async => directory,
    );
  });
  tearDown(() => directory.delete(recursive: true));

  test('停止后的真实源路径持久化，重建服务仍能暂存和提交', () async {
    final prepared = await recordings.prepare(root);
    final original = await File(
      '${directory.path}/original.mp4',
    ).writeAsBytes([1, 2, 3]);
    await recordings.attachSource(prepared, XFile(original.path));
    final restored = RecordingService(
      storage,
      store,
      supportDirectory: () async => directory,
    );
    await restored.commit(store.jobs.single);
    expect(storage.saves, 1);
    expect(store.jobs, isEmpty);
    expect(await original.exists(), false);
    expect(await File(prepared.sourcePath).exists(), false);
  });

  test('SAF 写入失败保留完整暂存，重试不再依赖原缓存', () async {
    final prepared = await recordings.prepare(root);
    final original = await File(
      '${directory.path}/original.mp4',
    ).writeAsBytes([4, 5, 6]);
    final job = await recordings.attachSource(prepared, XFile(original.path));
    storage.failSave = true;
    await expectLater(recordings.commit(job), throwsA(isA<Exception>()));
    expect(await File(job.sourcePath).readAsBytes(), [4, 5, 6]);
    expect(store.jobs, hasLength(1));
    storage.failSave = false;
    await recordings.commit(store.jobs.single);
    expect(store.jobs, isEmpty);
  });

  test('源文件暂时不可用时保留恢复信息，恢复后可以重新提交', () async {
    final prepared = await recordings.prepare(root);
    final sourcePath = '${directory.path}/delayed.mp4';
    final job = await recordings.attachSource(prepared, XFile(sourcePath));
    await expectLater(
      recordings.commit(job),
      throwsA(isA<FileSystemException>()),
    );
    expect(store.jobs.single.temporaryPath, sourcePath);
    await File(sourcePath).writeAsBytes([7, 8, 9]);
    await recordings.commit(store.jobs.single);
    expect(store.jobs, isEmpty);
  });

  test('放弃未暂存录像时删除登记的应用缓存源文件', () async {
    final prepared = await recordings.prepare(root);
    final original = await File(
      '${directory.path}/original.mp4',
    ).writeAsBytes([1, 2, 3]);
    final job = await recordings.attachSource(prepared, XFile(original.path));
    await recordings.discard(job);
    expect(await original.exists(), false);
    expect(store.jobs, isEmpty);
  });

  test('放弃录像不能删除缓存目录之外的文件', () async {
    final safeCache = await Directory('${directory.path}/cache').create();
    final guarded = RecordingService(
      storage,
      store,
      supportDirectory: () async => directory,
      temporaryDirectory: () async => safeCache,
    );
    final prepared = await guarded.prepare(root);
    final outside = await File(
      '${directory.path}/outside.mp4',
    ).writeAsBytes([9]);
    final job = await guarded.attachSource(prepared, XFile(outside.path));
    await expectLater(
      guarded.discard(job),
      throwsA(isA<FileSystemException>()),
    );
    expect(await outside.exists(), true);
    expect(store.jobs, hasLength(1));
  });
}
