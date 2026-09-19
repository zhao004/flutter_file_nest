import 'package:material_ui/material_ui.dart';

/// 在 [text] 中高亮全部 [query] 匹配（大小写不敏感）；空查询返回纯文本。
///
/// 纯函数，便于单测；调用方通过 [base] 与 [matchStyle] 控制普通文本与
/// 命中片段的样式。
TextSpan highlightMatches(
  String text,
  String query, {
  TextStyle? base,
  required TextStyle matchStyle,
}) {
  if (query.isEmpty) return TextSpan(text: text, style: base);
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start)));
      }
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index)));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: matchStyle,
      ),
    );
    start = index + query.length;
  }
  return TextSpan(style: base, children: spans);
}
