import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/storage_entry.dart';
import '../preview/preview_defaults.dart';

class VaultPreferences {
  const VaultPreferences({
    this.rootUri,
    this.sort = EntrySort.modified,
    this.descending = true,
    this.textFontSize = kDefaultTextFontSize,
    this.textWrap = kDefaultTextWrap,
    this.markdownMode = kDefaultMarkdownMode,
  });
  final String? rootUri;
  final EntrySort sort;
  final bool descending;

  /// 文本/代码预览字号（逻辑像素）。
  final double textFontSize;

  /// 文本预览是否自动换行。
  final bool textWrap;

  /// Markdown 展示模式：read（阅读）或 source（源码）。
  final String markdownMode;

  VaultPreferences copyWith({
    String? rootUri,
    EntrySort? sort,
    bool? descending,
    double? textFontSize,
    bool? textWrap,
    String? markdownMode,
  }) => VaultPreferences(
    rootUri: rootUri ?? this.rootUri,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
    textFontSize: textFontSize ?? this.textFontSize,
    textWrap: textWrap ?? this.textWrap,
    markdownMode: markdownMode ?? this.markdownMode,
  );
}

abstract interface class VaultStore {
  Future<VaultPreferences> loadPreferences();
  Future<void> savePreferences(VaultPreferences value);
  Future<void> recordCreated(String uri, DateTime time);

  /// 查询本应用登记的创建时间；返回值仅包含已登记的 URI。
  /// 用于创建时间排序与详情展示，外部文件无依据时保持未知。
  Future<Map<String, DateTime>> createdTimes(Iterable<String> uris);

  /// 读取媒体续播位置；无记录返回 null。
  Future<Duration?> playbackPosition(String uri);

  /// 写入或覆盖媒体续播位置；[duration] 未知时传 null。
  Future<void> savePlaybackPosition(
    String uri,
    Duration position, {
    Duration? duration,
  });
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
      sort:
          EntrySort.values
              .where((value) => value.name == row.sortField)
              .firstOrNull ??
          EntrySort.modified,
      descending: row.sortDescending,
      textFontSize: row.textFontSize,
      textWrap: row.textWrap,
      markdownMode: row.markdownMode,
    );
  }

  @override
  Future<void> savePreferences(VaultPreferences value) => database.saveSettings(
    AppSettingsCompanion(
      id: const Value(1),
      rootUri: Value(value.rootUri),
      sortField: Value(value.sort.name),
      sortDescending: Value(value.descending),
      textFontSize: Value(value.textFontSize),
      textWrap: Value(value.textWrap),
      markdownMode: Value(value.markdownMode),
      updatedAt: Value(DateTime.now().toUtc()),
    ),
  );

  @override
  Future<void> recordCreated(String uri, DateTime time) =>
      database.saveCreatedEntry(uri, time.toUtc());

  @override
  Future<Map<String, DateTime>> createdTimes(Iterable<String> uris) async {
    final keys = uris.toSet().toList();
    if (keys.isEmpty) return const {};
    final rows = await (database.select(
      database.entryMetadata,
    )..where((table) => table.uri.isIn(keys))).get();
    return {for (final row in rows) row.uri: row.createdAt.toLocal()};
  }

  @override
  Future<Duration?> playbackPosition(String uri) =>
      database.loadPlaybackPosition(uri);

  @override
  Future<void> savePlaybackPosition(
    String uri,
    Duration position, {
    Duration? duration,
  }) => database.savePlaybackPosition(uri, position, duration: duration);
}
