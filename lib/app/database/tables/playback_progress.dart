import 'package:drift/drift.dart';

/// 媒体续播位置：按内容 URI 记录最近一次播放进度与时长。
///
/// URI 视为不透明标识；文件被删除或移动后记录可能残留，读取时以条目
/// 是否仍存在为准，不主动跨目录清理。
class PlaybackProgress extends Table {
  TextColumn get uri => text()();

  /// 已播放位置（毫秒）。
  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  /// 内容总时长（毫秒）；未知时为 0。
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {uri};
}
