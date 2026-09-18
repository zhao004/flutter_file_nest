/// 文本、代码与 Markdown 预览的显示默认值。
///
/// 这些值同时作为数据库列默认值，集中定义避免 SQL 与 Dart 两处漂移。
/// 字号单位为逻辑像素；自动换行关闭时预览改为横向滚动。
const double kDefaultTextFontSize = 14;

/// 文本预览允许的最小字号。
const double minTextFontSize = 10;

/// 文本预览允许的最大字号。
const double maxTextFontSize = 32;

/// 文本预览默认自动换行。
const bool kDefaultTextWrap = true;

/// Markdown 默认展示模式；可选 `read`（阅读）与 `source`（源码）。
const String kDefaultMarkdownMode = 'read';

/// Markdown 源码模式取值。
const String kMarkdownModeSource = 'source';
