import '../file_type/file_category.dart';
import '../file_type/file_extension_map.dart';
import '../models/storage_entry.dart';
import 'preview_kind.dart';

/// 可应用内浏览的压缩包格式；RAR/7Z 因缺少成熟稳定的 Dart 解析库，ZSTD
/// 无可用解码器，均由 [PreviewKind.external] 交给系统应用处理。
const Set<String> _browsableArchiveExtensions = {
  'zip',
  'tar',
  'gz',
  'tgz',
  'bz2',
  'tbz2',
  'xz',
  'txz',
};

/// Flutter 可直接加载的字体格式；`.ttc`（字体集合）与 `.woff/.woff2`
/// 不支持，走系统打开。
const Set<String> _loadableFontExtensions = {'ttf', 'otf'};

/// Markdown 扩展名；归类为 text，但使用渲染阅读器。
const Set<String> _markdownExtensions = {'md', 'markdown'};

/// 解析条目应采用的应用内预览器；不适用时返回 [PreviewKind.external]
/// 或 [PreviewKind.unsupported]。
///
/// 判断只依赖 [StorageEntry.fileCategory]（已综合 MIME 与扩展名）与最后
/// 一段扩展名，不对文件名做其他猜测。目录不参与预览。
PreviewKind resolvePreviewKind(StorageEntry entry) {
  if (entry.isDirectory) return PreviewKind.unsupported;
  final extension = fileExtension(entry.name);
  return switch (entry.fileCategory) {
    FileCategory.image => PreviewKind.image,
    FileCategory.video => PreviewKind.video,
    FileCategory.audio => PreviewKind.audio,
    FileCategory.pdf => PreviewKind.pdf,
    FileCategory.text =>
      _markdownExtensions.contains(extension)
          ? PreviewKind.markdown
          : PreviewKind.text,
    FileCategory.code => PreviewKind.code,
    FileCategory.spreadsheet =>
      extension == 'csv' ? PreviewKind.csv : PreviewKind.external,
    FileCategory.archive =>
      _browsableArchiveExtensions.contains(extension)
          ? PreviewKind.archive
          : PreviewKind.external,
    FileCategory.ebook =>
      extension == 'epub' ? PreviewKind.ebook : PreviewKind.external,
    FileCategory.font =>
      _loadableFontExtensions.contains(extension)
          ? PreviewKind.font
          : PreviewKind.external,
    FileCategory.subtitle => PreviewKind.subtitle,
    // Office 文档内嵌解析复杂度高，交给系统应用；其余无法预览的展示信息页。
    FileCategory.document || FileCategory.presentation => PreviewKind.external,
    FileCategory.folder ||
    FileCategory.apk ||
    FileCategory.database ||
    FileCategory.unknown => PreviewKind.unsupported,
  };
}

/// 该条目是否应交由系统打开；仅 [PreviewKind.external] 返回 true，
/// [PreviewKind.unsupported] 仍在应用内展示信息页。
bool shouldOpenExternally(StorageEntry entry) =>
    resolvePreviewKind(entry) == PreviewKind.external;
