import 'package:material_ui/material_ui.dart';

import '../../models/storage_entry.dart';
import '../../preview/preview_kind.dart';
import '../../preview/preview_resolver.dart';
import '../video/video_view.dart';
import 'archive_preview_view.dart';
import 'audio_preview_view.dart';
import 'code_preview_view.dart';
import 'csv_preview_view.dart';
import 'epub_preview_view.dart';
import 'font_preview_view.dart';
import 'image_preview_view.dart';
import 'markdown_preview_view.dart';
import 'pdf_preview_view.dart';
import 'subtitle_preview_view.dart';
import 'text_preview_view.dart';
import 'unsupported_preview_view.dart';

/// 应用内预览分发页：按 [resolvePreviewKind] 选择具体查看器。
///
/// 每种查看器本身即为整页 Widget（含自己的 AppBar 与安全区），因此这里
/// 直接返回对应实例，不额外包裹 Scaffold，避免嵌套与双重 AppBar。
class FilePreviewPage extends StatelessWidget {
  const FilePreviewPage({required this.entry, super.key});

  final StorageEntry entry;

  @override
  Widget build(BuildContext context) => switch (resolvePreviewKind(entry)) {
    PreviewKind.image => ImagePreviewView(entry: entry),
    PreviewKind.video => VideoView(entry: entry),
    PreviewKind.audio => AudioPreviewView(entry: entry),
    PreviewKind.pdf => PdfPreviewView(entry: entry),
    PreviewKind.text => TextPreviewView(entry: entry),
    PreviewKind.code => CodePreviewView(entry: entry),
    PreviewKind.markdown => MarkdownPreviewView(entry: entry),
    PreviewKind.csv => CsvPreviewView(entry: entry),
    PreviewKind.subtitle => SubtitlePreviewView(entry: entry),
    PreviewKind.font => FontPreviewView(entry: entry),
    PreviewKind.archive => ArchivePreviewView(entry: entry),
    PreviewKind.ebook => EpubPreviewView(entry: entry),
    // 其余查看器在后续阶段接入；当前统一回退到信息页。
    _ => UnsupportedPreviewView(entry: entry),
  };
}
