import 'package:material_ui/material_ui.dart';
import 'package:hugeicons/hugeicons.dart';

import 'file_category.dart';
import 'file_icon_mapper.dart';

/// 文件分类图标的统一渲染组件。
///
/// 封装 hugeicons 的 `HugeIcon`，使 UI 层不直接依赖图标库；[color] 为空时按
/// 当前 IconTheme 取色，再回落到 material_ui 主题色，避免其 legacy 主题兜底。
class FileCategoryIcon extends StatelessWidget {
  const FileCategoryIcon({
    required this.category,
    this.folderState = FolderIconState.closed,
    this.size = 24,
    this.color,
    this.strokeWidth = 1.8,
    super.key,
  });

  final FileCategory category;
  final FolderIconState folderState;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => HugeIcon(
    icon: fileCategoryIcon(category, folderState: folderState),
    size: size,
    color:
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface,
    strokeWidth: strokeWidth,
  );
}
