import 'file_category.dart';

/// 扩展名（小写、不带点）到文件分类的映射。
///
/// 复合扩展名必须整体登记，否则会被最后一段误判；检测时先匹配
/// [_compoundExtensions]，再退化到最后一个点后的单段扩展名。
const Map<String, FileCategory> _extensionCategories = {
  // 图片
  'jpg': FileCategory.image,
  'jpeg': FileCategory.image,
  'jpe': FileCategory.image,
  'png': FileCategory.image,
  'webp': FileCategory.image,
  'gif': FileCategory.image,
  'bmp': FileCategory.image,
  'tif': FileCategory.image,
  'tiff': FileCategory.image,
  'heic': FileCategory.image,
  'heif': FileCategory.image,
  'avif': FileCategory.image,
  'ico': FileCategory.image,
  'svg': FileCategory.image,
  // 视频
  'mp4': FileCategory.video,
  'm4v': FileCategory.video,
  'mov': FileCategory.video,
  'mkv': FileCategory.video,
  'avi': FileCategory.video,
  'flv': FileCategory.video,
  'webm': FileCategory.video,
  'wmv': FileCategory.video,
  'mpeg': FileCategory.video,
  'mpg': FileCategory.video,
  '3gp': FileCategory.video,
  'ts': FileCategory.video,
  'm2ts': FileCategory.video,
  // 音频
  'mp3': FileCategory.audio,
  'm4a': FileCategory.audio,
  'aac': FileCategory.audio,
  'wav': FileCategory.audio,
  'flac': FileCategory.audio,
  'ogg': FileCategory.audio,
  'opus': FileCategory.audio,
  'wma': FileCategory.audio,
  'aiff': FileCategory.audio,
  'aif': FileCategory.audio,
  'amr': FileCategory.audio,
  'mid': FileCategory.audio,
  'midi': FileCategory.audio,
  // PDF
  'pdf': FileCategory.pdf,
  // 文档
  'doc': FileCategory.document,
  'docx': FileCategory.document,
  'docm': FileCategory.document,
  'dot': FileCategory.document,
  'dotx': FileCategory.document,
  'rtf': FileCategory.document,
  // 表格
  'xls': FileCategory.spreadsheet,
  'xlsx': FileCategory.spreadsheet,
  'xlsm': FileCategory.spreadsheet,
  'xlsb': FileCategory.spreadsheet,
  'csv': FileCategory.spreadsheet,
  'ods': FileCategory.spreadsheet,
  // 演示文稿
  'ppt': FileCategory.presentation,
  'pptx': FileCategory.presentation,
  'pptm': FileCategory.presentation,
  'pps': FileCategory.presentation,
  'ppsx': FileCategory.presentation,
  'odp': FileCategory.presentation,
  // 压缩包
  'zip': FileCategory.archive,
  '7z': FileCategory.archive,
  'rar': FileCategory.archive,
  'tar': FileCategory.archive,
  'tar.gz': FileCategory.archive,
  'tgz': FileCategory.archive,
  'tar.bz2': FileCategory.archive,
  'tbz2': FileCategory.archive,
  'tar.xz': FileCategory.archive,
  'txz': FileCategory.archive,
  'gz': FileCategory.archive,
  'bz2': FileCategory.archive,
  'xz': FileCategory.archive,
  'zst': FileCategory.archive,
  // Android 应用
  'apk': FileCategory.apk,
  'apks': FileCategory.apk,
  'xapk': FileCategory.apk,
  'apkm': FileCategory.apk,
  // 文本与配置
  'txt': FileCategory.text,
  'md': FileCategory.text,
  'markdown': FileCategory.text,
  'log': FileCategory.text,
  'ini': FileCategory.text,
  'cfg': FileCategory.text,
  'conf': FileCategory.text,
  // 代码与结构化配置
  'dart': FileCategory.code,
  'java': FileCategory.code,
  'kt': FileCategory.code,
  'kts': FileCategory.code,
  'js': FileCategory.code,
  'mjs': FileCategory.code,
  'cjs': FileCategory.code,
  'tsx': FileCategory.code,
  'py': FileCategory.code,
  'pyw': FileCategory.code,
  'c': FileCategory.code,
  'h': FileCategory.code,
  'cpp': FileCategory.code,
  'hpp': FileCategory.code,
  'cc': FileCategory.code,
  'cxx': FileCategory.code,
  'cs': FileCategory.code,
  'rs': FileCategory.code,
  'go': FileCategory.code,
  'php': FileCategory.code,
  'swift': FileCategory.code,
  'sh': FileCategory.code,
  'bash': FileCategory.code,
  'zsh': FileCategory.code,
  'json': FileCategory.code,
  'xml': FileCategory.code,
  'yaml': FileCategory.code,
  'yml': FileCategory.code,
  'toml': FileCategory.code,
  'properties': FileCategory.code,
  'env': FileCategory.code,
  'html': FileCategory.code,
  'htm': FileCategory.code,
  // 数据库
  'db': FileCategory.database,
  'sqlite': FileCategory.database,
  'sqlite3': FileCategory.database,
  'sql': FileCategory.database,
  // 字体
  'ttf': FileCategory.font,
  'otf': FileCategory.font,
  'ttc': FileCategory.font,
  'woff': FileCategory.font,
  'woff2': FileCategory.font,
  // 电子书
  'epub': FileCategory.ebook,
  'mobi': FileCategory.ebook,
  'azw': FileCategory.ebook,
  'azw3': FileCategory.ebook,
  'fb2': FileCategory.ebook,
  // 字幕
  'srt': FileCategory.subtitle,
  'ass': FileCategory.subtitle,
  'ssa': FileCategory.subtitle,
  'vtt': FileCategory.subtitle,
  'sub': FileCategory.subtitle,
  'sup': FileCategory.subtitle,
};

/// 需要整体匹配、含多个点段的扩展名键。
const Set<String> _compoundExtensions = {'tar.gz', 'tar.bz2', 'tar.xz'};

/// 文件名扩展名判定的分类；无法识别时返回 [FileCategory.unknown]。
///
/// 文件名大小写不敏感；只取最后一个点后的单段扩展名，因此
/// `my.file.txt` 判定为文本，而 `archive.tar.gz` 命中复合键。
FileCategory categoryFromExtension(String name) {
  final lowered = name.toLowerCase();
  for (final compound in _compoundExtensions) {
    if (lowered.endsWith('.$compound')) return _extensionCategories[compound]!;
  }
  final dot = lowered.lastIndexOf('.');
  if (dot < 0 || dot == lowered.length - 1) return FileCategory.unknown;
  return _extensionCategories[lowered.substring(dot + 1)] ??
      FileCategory.unknown;
}
