/// 应用内预览器的种类；由 [resolvePreviewKind] 根据文件分类与扩展名解析。
///
/// 这是“文件类型识别”与“预览 UI”之间的唯一契约：识别层只描述语义分类
/// （[FileCategory]），预览层只关心用哪种查看器打开。两者不互相绑定扩展名，
/// 例如 `.md` 与 `.txt` 同属 text 分类，但分别解析为 markdown 与 text。
enum PreviewKind {
  /// 位图与矢量图查看器；SVG 由图片查看器内部选择渲染方式。
  image,

  /// 视频播放器。
  video,

  /// 音频播放器；不显示视频画面。
  audio,

  /// PDF 阅读器。
  pdf,

  /// 纯文本查看器。
  text,

  /// 代码与结构化配置查看器（含语法高亮与行号）。
  code,

  /// Markdown 阅读器（阅读与源码两种模式）。
  markdown,

  /// CSV 表格查看器。
  csv,

  /// 压缩包内容浏览（虚拟文件系统，不映射为真实 SAF 文件）。
  archive,

  /// 电子书阅读器（当前支持 EPUB）。
  ebook,

  /// 字体预览；字体集合与 Web 字体不支持。
  font,

  /// 字幕文件查看器。
  subtitle,

  /// 无法在应用内预览：展示文件信息与“用其他应用打开”。
  unsupported,

  /// 不在应用内预览，直接交给 Android 系统打开。
  external,
}
