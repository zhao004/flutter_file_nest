import 'package:flutter/widgets.dart';

/// 代码编辑器控制器：由平台视图实现，测试可注入假件。
///
/// 文本读写跨越平台通道；可编辑性、亮暗主题与撤销重做由原生编辑器承担。
abstract interface class CodeEditorController {
  Future<void> setText(String text);
  Future<String> readText();
  Future<void> setEditable(bool editable);
  Future<void> setDark(bool dark);
  Future<void> undo();
  Future<void> redo();
}

/// 编辑器组件的构建配置。
class CodeEditorHostConfig {
  const CodeEditorHostConfig({
    required this.editable,
    required this.dark,
    required this.onController,
    required this.onChanged,
  });

  final bool editable;
  final bool dark;
  final ValueChanged<CodeEditorController> onController;
  final VoidCallback onChanged;
}

/// 编辑器构建器；默认使用 sora-editor 平台视图，测试可替换为假实现。
typedef CodeEditorBuilder = Widget Function(CodeEditorHostConfig config);
