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

/// 默认显示行号；代码预览与编辑器共用同一偏好。
const bool kDefaultShowLineNumbers = true;

/// 编辑器默认启用自动缩进；回车时复制当前行前导空白。
const bool kDefaultEditorAutoIndent = true;

/// 编辑器默认 Tab 缩进宽度（空格数）。
const int kDefaultEditorTabWidth = 4;

/// 编辑器可选的 Tab 缩进宽度（空格数）；供设置页选择，避免自由输入非法值。
const List<int> kEditorTabWidthOptions = [2, 4, 6, 8];
