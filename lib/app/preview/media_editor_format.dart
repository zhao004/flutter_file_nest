import 'package:pro_image_editor/pro_image_editor.dart';

/// 视频副本扩展名；Android 端 pro_video_editor 仅支持 MP4 输出。
const String videoCopyExtension = 'mp4';

/// 图片副本的输出格式：`jpg/jpeg` 保持 JPEG，其余（含 png）输出 PNG 以保留透明。
OutputFormat imageOutputFormatForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return OutputFormat.jpg;
  }
  return OutputFormat.png;
}

/// 与 [imageOutputFormatForName] 对应的副本文件扩展名。
String imageCopyExtension(OutputFormat format) =>
    format == OutputFormat.jpg ? 'jpg' : 'png';

/// 生成“另存为副本”的文件名：`原名_edited.扩展名`，重名时追加 `(2)`、`(3)`…
///
/// 扩展名由调用方给出，保证与实际编码格式或容器一致。
String editedCopyName(
  String originalName,
  String extension,
  Iterable<String> existingNames,
) {
  final dot = originalName.lastIndexOf('.');
  final rawBase = dot > 0 ? originalName.substring(0, dot) : originalName;
  final base = rawBase.trim().isEmpty ? 'media' : rawBase;
  final existing = existingNames.map((value) => value.toLowerCase()).toSet();
  var index = 0;
  while (true) {
    final suffix = index == 0 ? '_edited' : '_edited(${index + 1})';
    final name = '$base$suffix.$extension';
    if (!existing.contains(name.toLowerCase())) return name;
    index++;
  }
}
