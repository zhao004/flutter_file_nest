import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

/// 由 material_ui 主题构建 Markdown 样式表。
///
/// flutter_markdown_plus 尚未迁移到 material_ui，其默认样式表读取 legacy
/// `Theme.of`；在 material_ui 应用内会回落到浅色兜底主题，深色模式下正文与
/// 代码块颜色不可用。这里按当前主题显式映射，避免引入 legacy Theme 兼容层。
MarkdownStyleSheet markdownStyleSheetFor(ThemeData theme) {
  final scheme = theme.colorScheme;
  final textTheme = theme.textTheme;
  final body = textTheme.bodyMedium;

  return MarkdownStyleSheet(
    a: TextStyle(color: scheme.primary),
    p: body,
    pPadding: EdgeInsets.zero,
    code: body?.copyWith(
      backgroundColor: scheme.surfaceContainerHighest,
      fontFamily: 'monospace',
      fontSize: body.fontSize == null ? null : body.fontSize! * 0.85,
    ),
    h1: textTheme.headlineSmall,
    h1Padding: EdgeInsets.zero,
    h2: textTheme.titleLarge,
    h2Padding: EdgeInsets.zero,
    h3: textTheme.titleMedium,
    h3Padding: EdgeInsets.zero,
    h4: textTheme.bodyLarge,
    h4Padding: EdgeInsets.zero,
    h5: textTheme.bodyLarge,
    h5Padding: EdgeInsets.zero,
    h6: textTheme.bodyLarge,
    h6Padding: EdgeInsets.zero,
    em: const TextStyle(fontStyle: FontStyle.italic),
    strong: const TextStyle(fontWeight: FontWeight.bold),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    blockquote: body,
    img: body,
    checkbox: body?.copyWith(color: scheme.primary),
    blockSpacing: 8,
    listIndent: 24,
    listBullet: body,
    listBulletPadding: const EdgeInsets.only(right: 4),
    tableHead: const TextStyle(fontWeight: FontWeight.w600),
    tableBody: body,
    tableHeadAlign: TextAlign.center,
    tablePadding: const EdgeInsets.only(bottom: 4),
    tableBorder: TableBorder.all(color: scheme.outlineVariant),
    tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    tableCellsDecoration: const BoxDecoration(),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(3),
      border: Border(left: BorderSide(color: scheme.primary, width: 3)),
    ),
    codeblockPadding: const EdgeInsets.all(8),
    codeblockDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(2),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(width: 5, color: scheme.outlineVariant)),
    ),
  );
}
