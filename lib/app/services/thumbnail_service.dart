import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../models/storage_entry.dart';
import 'saf_storage.dart';

/// 缩略图平台契约；测试通过假件覆盖加载失败与缓存行为。
abstract interface class ThumbnailGateway {
  Future<Uint8List?> load(
    StorageEntry entry, {
    int maxDimension = thumbnailDimension,
  });

  /// 取消尚未开始的排队请求；已开始的请求无法中断，其结果由调用方忽略。
  void cancel(StorageEntry entry, {int maxDimension = thumbnailDimension});

  /// 清空排队中的请求；用于目录切换时丢弃旧目录的陈旧加载。
  void clearPending();
}

/// 无缩略图能力的默认实现；测试与不支持的平台使用。
class NoThumbnails implements ThumbnailGateway {
  const NoThumbnails();
  @override
  Future<Uint8List?> load(
    StorageEntry entry, {
    int maxDimension = thumbnailDimension,
  }) async => null;

  @override
  void cancel(StorageEntry entry, {int maxDimension = thumbnailDimension}) {}

  @override
  void clearPending() {}
}

/// 视频缩略图加载器。
///
/// - 缓存键包含内容 URI、可取得的修改时间指纹与请求尺寸；URI 不变不代表
///   内容不变，缺少可靠修改时间时依赖有效期显式失效。
/// - LRU 缓存有上限；失败结果不缓存，条目再次可见时可重试。
/// - 并发受上限控制，快速滚动时按可见项惰性请求；并发数偏低以保证
///   加载期间目录切换与滚动仍然跟手。
class ThumbnailService implements ThumbnailGateway {
  ThumbnailService(
    this._storage, {
    this.maxCacheEntries = 128,
    this.maxConcurrency = 2,
    this.ttl = const Duration(minutes: 10),
  });
  final StorageGateway _storage;
  final int maxCacheEntries;
  final int maxConcurrency;

  /// 缓存有效期；提供方不返回修改时间时防止陈旧内容长期驻留。
  final Duration ttl;

  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _inflight = {};
  final Queue<_ThumbnailRequest> _queue = Queue();
  int _running = 0;

  /// 正在执行的加载数；测试观察用。
  int get inflightCount => _running;

  /// 队列中等待的请求数；测试观察用。
  int get pendingCount => _queue.length;

  @override
  Future<Uint8List?> load(
    StorageEntry entry, {
    int maxDimension = thumbnailDimension,
  }) {
    final key = _key(entry, maxDimension);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.stored) < ttl) {
      _cache.remove(key);
      _cache[key] = cached;
      return Future<Uint8List?>.value(cached.bytes);
    }
    if (cached != null) _cache.remove(key);
    final existing = _inflight[key];
    if (existing != null) return existing;
    final completer = Completer<Uint8List?>();
    _queue.add(_ThumbnailRequest(entry, maxDimension, key, completer));
    _inflight[key] = completer.future;
    _drain();
    return completer.future;
  }

  /// 取消排队中的请求：移除队列、结束等待并清理在途记录。
  ///
  /// 已进入原生执行的请求无法中断，仍会写入缓存；再次请求时直接命中缓存。
  @override
  void cancel(StorageEntry entry, {int maxDimension = thumbnailDimension}) {
    final key = _key(entry, maxDimension);
    final pending = _queue.where((request) => request.key == key).toList();
    if (pending.isEmpty) return;
    _queue.removeWhere((request) => request.key == key);
    for (final request in pending) {
      _inflight.remove(request.key);
      if (!request.completer.isCompleted) request.completer.complete(null);
    }
  }

  /// 清空排队中的全部请求；已开始的请求仍会完成并写入缓存。
  @override
  void clearPending() {
    if (_queue.isEmpty) return;
    final pending = _queue.toList();
    _queue.clear();
    for (final request in pending) {
      _inflight.remove(request.key);
      if (!request.completer.isCompleted) request.completer.complete(null);
    }
  }

  String _key(StorageEntry entry, int maxDimension) =>
      '${entry.uri}|${entry.modifiedAt?.millisecondsSinceEpoch ?? 0}|$maxDimension';

  void _drain() {
    while (_running < maxConcurrency && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      _running++;
      unawaited(_fetch(request));
    }
  }

  Future<void> _fetch(_ThumbnailRequest request) async {
    Uint8List? bytes;
    try {
      bytes = await _storage.thumbnail(
        request.entry,
        maxDimension: request.maxDimension,
      );
    } catch (_) {
      // 失败不缓存；返回 null 由界面回退占位图标。
      bytes = null;
    } finally {
      _running--;
      _inflight.remove(request.key);
      if (bytes != null) {
        _cache[request.key] = _CacheEntry(bytes, DateTime.now());
        while (_cache.length > maxCacheEntries) {
          _cache.remove(_cache.keys.first);
        }
      }
      request.completer.complete(bytes);
      _drain();
    }
  }
}

class _CacheEntry {
  const _CacheEntry(this.bytes, this.stored);
  final Uint8List bytes;
  final DateTime stored;
}

class _ThumbnailRequest {
  const _ThumbnailRequest(
    this.entry,
    this.maxDimension,
    this.key,
    this.completer,
  );
  final StorageEntry entry;
  final int maxDimension;
  final String key;
  final Completer<Uint8List?> completer;
}
