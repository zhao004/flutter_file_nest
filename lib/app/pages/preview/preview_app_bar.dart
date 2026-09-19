import 'package:material_ui/material_ui.dart';

/// 沉浸式（深色背景）预览页顶部栏的图标样式。
///
/// 主题的 `AppBarTheme.iconTheme` 会覆盖 `AppBar.foregroundColor`：浅色主题下
/// 为深色、深色主题下为浅色。黑底预览页必须显式指定白色图标，否则浅色模式下
/// 顶部按钮不可见。图片、PDF 与视频预览统一使用本样式。
const IconThemeData immersivePreviewIconTheme = IconThemeData(
  color: Colors.white,
);
