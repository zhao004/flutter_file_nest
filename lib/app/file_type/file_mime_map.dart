import 'file_category.dart';

/// MIME 无法说明具体类型时使用的泛化取值。
///
/// 这些 MIME 在 SAF 中很常见，但不足以判定类型，必须让位给扩展名判断。
const Set<String> _genericMimeTypes = {
  'application/octet-stream',
  'binary/octet-stream',
  'application/unknown',
  'content/unknown',
  '*/*',
};

/// 按前缀匹配的 MIME 族。
const Map<String, FileCategory> _mimePrefixes = {
  'image/': FileCategory.image,
  'video/': FileCategory.video,
  'audio/': FileCategory.audio,
  'font/': FileCategory.font,
};

/// 需要精确匹配的 MIME。
const Map<String, FileCategory> _exactMimeCategories = {
  'application/pdf': FileCategory.pdf,
  // 表格：CSV 虽为文本，但按表格呈现更符合文件管理器习惯。
  'text/csv': FileCategory.spreadsheet,
  'text/comma-separated-values': FileCategory.spreadsheet,
  'text/markdown': FileCategory.text,
  'text/x-markdown': FileCategory.text,
  // 代码与结构化配置。
  'application/json': FileCategory.code,
  'text/json': FileCategory.code,
  'application/xml': FileCategory.code,
  'text/xml': FileCategory.code,
  'application/x-yaml': FileCategory.code,
  'text/yaml': FileCategory.code,
  'text/x-yaml': FileCategory.code,
  'text/html': FileCategory.code,
  // 文档。
  'application/msword': FileCategory.document,
  'application/rtf': FileCategory.document,
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      FileCategory.document,
  'application/vnd.openxmlformats-officedocument.wordprocessingml.template':
      FileCategory.document,
  'application/vnd.oasis.opendocument.text': FileCategory.document,
  // 表格。
  'application/vnd.ms-excel': FileCategory.spreadsheet,
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      FileCategory.spreadsheet,
  'application/vnd.openxmlformats-officedocument.spreadsheetml.template':
      FileCategory.spreadsheet,
  'application/vnd.oasis.opendocument.spreadsheet': FileCategory.spreadsheet,
  // 演示文稿。
  'application/vnd.ms-powerpoint': FileCategory.presentation,
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      FileCategory.presentation,
  'application/vnd.openxmlformats-officedocument.presentationml.template':
      FileCategory.presentation,
  'application/vnd.openxmlformats-officedocument.presentationml.slideshow':
      FileCategory.presentation,
  'application/vnd.oasis.opendocument.presentation': FileCategory.presentation,
  // 压缩包。
  'application/zip': FileCategory.archive,
  'application/x-zip-compressed': FileCategory.archive,
  'application/x-rar-compressed': FileCategory.archive,
  'application/vnd.rar': FileCategory.archive,
  'application/x-7z-compressed': FileCategory.archive,
  'application/x-tar': FileCategory.archive,
  'application/gzip': FileCategory.archive,
  'application/x-gzip': FileCategory.archive,
  'application/x-bzip2': FileCategory.archive,
  'application/zstd': FileCategory.archive,
  'application/x-xz': FileCategory.archive,
  // Android 应用。
  'application/vnd.android.package-archive': FileCategory.apk,
  // 数据库。
  'application/x-sqlite3': FileCategory.database,
  'application/vnd.sqlite3': FileCategory.database,
  'application/sql': FileCategory.database,
  // 电子书。
  'application/epub+zip': FileCategory.ebook,
  'application/x-mobipocket-ebook': FileCategory.ebook,
  'application/vnd.amazon.ebook': FileCategory.ebook,
};

/// MIME 判定的分类；泛化或未知 MIME 返回 null，由调用方回退到扩展名。
FileCategory? categoryFromMime(String? mimeType) {
  if (mimeType == null) return null;
  final mime = mimeType.toLowerCase().trim();
  if (mime.isEmpty || _genericMimeTypes.contains(mime)) return null;
  final exact = _exactMimeCategories[mime];
  if (exact != null) return exact;
  for (final entry in _mimePrefixes.entries) {
    if (mime.startsWith(entry.key)) return entry.value;
  }
  return null;
}
