import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/services/thumbnail_service.dart';

import 'support/fakes.dart';

class _SlowStorage extends FakeStorage {
  final pending = <Completer<void>>[];
  int inflightCount = 0;
  @override
  Future<Uint8List?> thumbnail(StorageEntry target, {int maxDimension = 128}) {
    inflightCount++;
    final completer = Completer<void>();
    pending.add(completer);
    return completer.future.then((_) => Uint8List.fromList([1]));
  }
}

void main() {
  test('同一请求命中缓存，不重复触发加载', () async {
    final storage = FakeStorage();
    final service = ThumbnailService(storage);
    final target = entry('视频.mp4', mime: 'video/mp4');
    final first = await service.load(target);
    final second = await service.load(target);
    expect(first, isNotNull);
    expect(identical(first, second), true);
    expect(storage.thumbnailLoads, 1);
  });

  test('修改时间不同的条目使用不同缓存键', () async {
    final storage = FakeStorage();
    final service = ThumbnailService(storage);
    final before = entry('视频.mp4', mime: 'video/mp4', modified: DateTime(2026));
    final after = entry(
      '视频.mp4',
      mime: 'video/mp4',
      modified: DateTime(2026, 1, 2),
    );
    await service.load(before);
    await service.load(after);
    expect(storage.thumbnailLoads, 2);
  });

  test('加载失败返回 null 且不缓存失败结果，可再次重试', () async {
    final storage = FakeStorage()..thumbnailResult = null;
    final service = ThumbnailService(storage);
    final target = entry('视频.mp4', mime: 'video/mp4');
    expect(await service.load(target), isNull);
    expect(await service.load(target), isNull);
    expect(storage.thumbnailLoads, 2);
  });

  test('并发受上限控制，超出部分排队后按序执行', () async {
    final storage = _SlowStorage();
    final service = ThumbnailService(storage, maxConcurrency: 2);
    final futures = [
      service.load(entry('a.mp4', mime: 'video/mp4')),
      service.load(entry('b.mp4', mime: 'video/mp4')),
      service.load(entry('c.mp4', mime: 'video/mp4')),
    ];
    // 前两个立即执行，第三个仍在队列等待。
    expect(storage.inflightCount, 2);
    expect(storage.pending.length, 2);
    storage.pending[0].complete();
    storage.pending[1].complete();
    await pumpEventQueue();
    // 第三项进入执行；全部完成后结果返回。
    expect(storage.pending.length, 3);
    for (final completer in storage.pending.sublist(2)) {
      completer.complete();
    }
    final results = await Future.wait(futures);
    for (final result in results) {
      expect(result, isNotNull);
    }
    expect(service.inflightCount, 0);
    expect(service.pendingCount, 0);
  });

  test('取消排队请求后不再执行加载，已开始的请求仍可完成', () async {
    final storage = _SlowStorage();
    final service = ThumbnailService(storage, maxConcurrency: 1);
    final running = service.load(entry('a.mp4', mime: 'video/mp4'));
    final queued = service.load(entry('b.mp4', mime: 'video/mp4'));
    expect(storage.inflightCount, 1);
    expect(service.pendingCount, 1);
    service.cancel(entry('b.mp4', mime: 'video/mp4'));
    expect(service.pendingCount, 0);
    // 被取消的等待者立即以 null 结束，且不会触发底层加载。
    expect(await queued, isNull);
    expect(storage.inflightCount, 1);
    // 已开始的请求不受取消影响。
    storage.pending.first.complete();
    expect(await running, isNotNull);
    expect(service.inflightCount, 0);
  });

  test('清空排队请求后不再执行加载，正在执行的请求仍完成', () async {
    final storage = _SlowStorage();
    final service = ThumbnailService(storage, maxConcurrency: 1);
    final running = service.load(entry('a.mp4', mime: 'video/mp4'));
    final queued = service.load(entry('b.mp4', mime: 'video/mp4'));
    expect(service.pendingCount, 1);
    service.clearPending();
    expect(service.pendingCount, 0);
    expect(await queued, isNull);
    expect(storage.inflightCount, 1);
    storage.pending.first.complete();
    expect(await running, isNotNull);
    expect(service.inflightCount, 0);
  });
}
