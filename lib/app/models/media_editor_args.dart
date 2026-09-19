import 'storage_entry.dart';

/// 图片/视频编辑器入口参数：被编辑文件与其所在目录（另存为新副本的目标目录）。
///
/// [parent] 必须可创建文件；保存时在 [parent] 下生成副本，原文件不受影响。
/// 保存成功后编辑器以副本文件名作为路由返回值 pop，调用方经
/// `context.push<String>` 获取并提示。
class MediaEditorArgs {
  const MediaEditorArgs({required this.entry, required this.parent});

  final StorageEntry entry;
  final StorageEntry parent;
}
