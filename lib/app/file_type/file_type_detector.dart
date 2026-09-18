import 'file_category.dart';
import 'file_extension_map.dart';
import 'file_mime_map.dart';

/// 综合 MIME 与扩展名判定文件分类。
///
/// 优先级：目录判断 > MIME > 扩展名。但存在两个让位规则，避免 SAF 常见
/// 的泛化 MIME 覆盖更具体的扩展名：
///
/// 1. 泛化 MIME（`application/octet-stream` 等）返回 null，直接使用扩展名；
/// 2. 泛化文本 MIME（`text/plain`）在扩展名能给出更具体分类时让位，
///    例如 `.dart` 保持 [FileCategory.code]，`.csv` 因 MIME 为 `text/csv`
///    仍按 MIME 判为表格。
FileCategory detectFileCategory({
  required String name,
  String? mimeType,
  bool isDirectory = false,
}) {
  if (isDirectory) return FileCategory.folder;
  final extension = categoryFromExtension(name);
  final mime = categoryFromMime(mimeType);
  if (mime == null) return extension;
  if (mime == FileCategory.text &&
      extension != FileCategory.unknown &&
      extension != FileCategory.text) {
    return extension;
  }
  return mime;
}
