import 'package:material_ui/material_ui.dart';

/// 语义色助手：`ColorScheme` 未覆盖的成功/警告状态色，按亮暗模式取值。
abstract final class AppColors {
  /// 成功状态色（批量任务成功、校验通过等）。
  static Color success(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.green.shade300
      : Colors.green.shade700;

  /// 警告状态色（部分完成、源未删除等）。
  static Color warning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.orange.shade300
      : Colors.orange.shade800;

  /// 中性/未知状态色（等待中、占位图标等）。
  static Color neutral(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
}
