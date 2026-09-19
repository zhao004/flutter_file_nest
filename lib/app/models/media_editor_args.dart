import 'storage_entry.dart';

/// 图片/视频编辑器入口参数：被编辑文件与其所在目录（另存为新副本的目标目录）。
///
/// [parent] 必须可创建文件；保存时在 [parent] 下生成副本，原文件不受影响。
class MediaEditorArgs {
  const MediaEditorArgs({
    required this.entry,
    required this.parent,
    this.onSaved,
  });

  final StorageEntry entry;
  final StorageEntry parent;

  /// 保存副本成功后的回调，参数为副本文件名。
  ///
  /// GetX 的命名路由经 `onGenerateRoute` 重建，无法承载 `Get.toNamed<T>` 的
  /// 类型化返回值（会抛 `Route<String?>` 转换错误），因此用回调回传结果。
  final void Function(String name)? onSaved;
}
