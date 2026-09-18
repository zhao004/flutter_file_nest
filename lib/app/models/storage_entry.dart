import '../file_type/file_category.dart';
import '../file_type/file_type_detector.dart';

enum EntrySort { name, modified, created, size }

/// 文档提供方返回的当前快照；documentId 与 URI 均为不透明标识。
class StorageEntry {
  const StorageEntry({
    required this.rootUri,
    required this.documentId,
    required this.uri,
    required this.name,
    required this.isDirectory,
    this.mimeType,
    this.size,
    this.modifiedAt,
    this.canCreate = false,
    this.canRename = false,
    this.canDelete = false,
  });

  factory StorageEntry.fromMap(Map<Object?, Object?> map) => StorageEntry(
    rootUri: map['rootUri'] as String,
    documentId: map['documentId'] as String,
    uri: map['uri'] as String,
    name: map['name'] as String,
    isDirectory: map['isDirectory'] as bool,
    mimeType: map['mimeType'] as String?,
    size: (map['size'] as num?)?.toInt(),
    modifiedAt: map['lastModified'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (map['lastModified'] as num).toInt(),
          ),
    canCreate: map['canCreate'] == true,
    canRename: map['canRename'] == true,
    canDelete: map['canDelete'] == true,
  );

  final String rootUri;
  final String documentId;
  final String uri;
  final String name;
  final bool isDirectory;
  final String? mimeType;
  final int? size;
  final DateTime? modifiedAt;
  final bool canCreate;
  final bool canRename;
  final bool canDelete;

  /// 按 MIME 与扩展名判定的文件分类；目录与未知类型也有对应取值。
  FileCategory get fileCategory => detectFileCategory(
    name: name,
    mimeType: mimeType,
    isDirectory: isDirectory,
  );

  bool get isVideo => fileCategory == FileCategory.video;

  /// 是否可直接作为位图预览与缩略图来源。
  ///
  /// SVG 归入图片分类用于图标展示，但 Flutter 无法直接用字节解码，
  /// 因此这里排除，避免点击后进入空白预览。
  bool get isImage =>
      fileCategory == FileCategory.image &&
      !name.toLowerCase().endsWith('.svg');

  bool get isPdf => fileCategory == FileCategory.pdf;
}

List<StorageEntry> sortEntries(
  Iterable<StorageEntry> entries,
  EntrySort field,
  bool descending, {

  /// 按创建时间排序时使用的登记值，键为条目 URI；缺失视为未知并置末尾。
  Map<String, DateTime> createdAt = const {},
}) {
  final sorted = entries.toList();
  sorted.sort((a, b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    final Comparable<Object>? left;
    final Comparable<Object>? right;
    switch (field) {
      case EntrySort.name:
        left = a.name.toLowerCase();
        right = b.name.toLowerCase();
      case EntrySort.modified:
        left = a.modifiedAt;
        right = b.modifiedAt;
      case EntrySort.created:
        // 创建时间只来自本应用登记的元数据，不用修改时间冒充。
        left = createdAt[a.uri];
        right = createdAt[b.uri];
      case EntrySort.size:
        left = a.isDirectory ? null : a.size;
        right = b.isDirectory ? null : b.size;
    }
    if (left == null && right != null) return 1;
    if (left != null && right == null) return -1;
    final comparison = left?.compareTo(right!) ?? 0;
    if (comparison != 0) return descending ? -comparison : comparison;
    return a.name.compareTo(b.name);
  });
  return sorted;
}

String? validateEntryName(String value) {
  final name = value.trim();
  if (name.isEmpty || name == '.' || name == '..') return '请输入有效名称';
  if (name.length > 120) return '名称不能超过 120 个字符';
  if (RegExp(r'[\\/:*?"<>|\x00-\x1f\x7f]').hasMatch(name)) {
    return '名称不能含路径或控制字符';
  }
  return null;
}

String formatBytes(int? bytes) {
  if (bytes == null) return '大小未知';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String recordingFileName(DateTime date) {
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)}_${pad(date.hour)}-${pad(date.minute)}-${pad(date.second)}.mp4';
}

String formatDuration(Duration value) {
  final seconds = value.inSeconds;
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// 播放时间格式：不足 1 小时为 MM:SS，达到 1 小时为 H:MM:SS；负值按 0 处理。
String formatPlaybackTime(Duration value) {
  final total = value.inSeconds < 0 ? 0 : value.inSeconds;
  String two(int part) => part.toString().padLeft(2, '0');
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}
