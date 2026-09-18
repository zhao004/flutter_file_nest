/// 文件类型分类；供图标、中文标签与后续按类型过滤使用。
///
/// 分类只描述语义类型，不绑定扩展名或 MIME 字符串；同一分类下可包含
/// 多种扩展名（例如 `.jpg` 与 `.heic` 同属 [image]）。
enum FileCategory {
  /// 文件夹；由 SAF/DocumentFile 的目录标记判定，不来自扩展名。
  folder,

  /// 图片，含位图与矢量图。
  image,

  /// 视频。
  video,

  /// 音频，含录音文件。
  audio,

  /// PDF 文档，单独成类便于识别。
  pdf,

  /// 文字处理文档，如 Word/RTF。
  document,

  /// 表格，如 Excel/CSV/ODS。
  spreadsheet,

  /// 演示文稿，如 PowerPoint/ODP。
  presentation,

  /// 压缩包，如 ZIP/RAR/7Z/TAR。
  archive,

  /// Android 应用安装包。
  apk,

  /// 纯文本，如 TXT/MD/日志/配置。
  text,

  /// 代码与结构化配置，如 Dart/Java/JSON/XML。
  code,

  /// 数据库文件与 SQL 脚本。
  database,

  /// 字体文件。
  font,

  /// 电子书。
  ebook,

  /// 字幕文件。
  subtitle,

  /// 未识别类型；不根据文件名猜测。
  unknown,
}
