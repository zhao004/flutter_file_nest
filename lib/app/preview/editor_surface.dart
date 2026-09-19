import 'package:flutter/widgets.dart';

/// 代码编辑器控制器：由平台视图实现，测试可注入假件。
///
/// 文本读写跨越平台通道；可编辑性、显示偏好、亮暗主题与撤销重做由原生
/// 编辑器承担。[setFontSize] 接收逻辑像素，与 Flutter 预览字号一致。
abstract interface class CodeEditorController {
  Future<void> setText(String text);
  Future<String> readText();
  Future<void> setEditable(bool editable);
  Future<void> setDark(bool dark);
  Future<void> setFontSize(double logicalPixels);
  Future<void> setWrap(bool wrap);
  Future<void> setLineNumbers(bool enabled);
  Future<void> setTabWidth(int spaces);
  Future<void> setAutoIndent(bool enabled);
  Future<void> undo();
  Future<void> redo();
}

/// 编辑器组件的构建配置。
///
/// [fontSize] 为逻辑像素；[wrap]、[lineNumbers]、[tabWidth]、[autoIndent]
/// 与预览/编辑器偏好保持一致。
class CodeEditorHostConfig {
  const CodeEditorHostConfig({
    required this.editable,
    required this.dark,
    required this.fontSize,
    required this.wrap,
    required this.lineNumbers,
    required this.tabWidth,
    required this.autoIndent,
    required this.onController,
    required this.onChanged,
  });

  final bool editable;
  final bool dark;
  final double fontSize;
  final bool wrap;
  final bool lineNumbers;
  final int tabWidth;
  final bool autoIndent;
  final ValueChanged<CodeEditorController> onController;
  final VoidCallback onChanged;
}

/// 编辑器构建器；默认使用 sora-editor 平台视图，测试可替换为假实现。
typedef CodeEditorBuilder = Widget Function(CodeEditorHostConfig config);
