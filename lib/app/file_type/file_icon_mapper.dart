import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'file_category.dart';
import 'file_type_info.dart';

/// 文件夹图标的展示状态。
///
/// 文件夹不是文件类型，而是通过 SAF/DocumentFile 判定的目录；不同场景
/// （普通目录、根目录提示、新建、受保护）需要不同图标，因此单独建模。
enum FolderIconState {
  /// 普通目录。
  closed,

  /// 展开/当前目录，例如选择存储位置的提示。
  open,

  /// 新建文件夹入口。
  create,

  /// 受保护或只读目录。
  locked,
}

/// 分类到图标的映射；UI 只依赖分类，不感知扩展名。
///
/// 图标来自 hugeicons 免费 stroke-rounded 集；[folderState] 仅在分类为
/// [FileCategory.folder] 时生效。渲染请使用 `FileCategoryIcon`。
FileIcon fileCategoryIcon(
  FileCategory category, {
  FolderIconState folderState = FolderIconState.closed,
}) => switch (category) {
  FileCategory.folder => switch (folderState) {
    FolderIconState.closed => HugeIcons.strokeRoundedFolder01,
    FolderIconState.open => HugeIcons.strokeRoundedFolderOpen,
    FolderIconState.create => HugeIcons.strokeRoundedFolderAdd,
    FolderIconState.locked => HugeIcons.strokeRoundedFolderLocked,
  },
  FileCategory.image => HugeIcons.strokeRoundedImage01,
  FileCategory.video => HugeIcons.strokeRoundedVideo01,
  FileCategory.audio => HugeIcons.strokeRoundedMusicNote01,
  FileCategory.pdf => HugeIcons.strokeRoundedPdf01,
  FileCategory.document => HugeIcons.strokeRoundedDoc01,
  FileCategory.spreadsheet => HugeIcons.strokeRoundedXls01,
  FileCategory.presentation => HugeIcons.strokeRoundedPpt01,
  FileCategory.archive => HugeIcons.strokeRoundedZip01,
  FileCategory.apk => HugeIcons.strokeRoundedAndroid,
  FileCategory.text => HugeIcons.strokeRoundedNote01,
  FileCategory.code => HugeIcons.strokeRoundedSourceCode,
  FileCategory.database => HugeIcons.strokeRoundedDatabase,
  FileCategory.font => HugeIcons.strokeRoundedTextFont,
  FileCategory.ebook => HugeIcons.strokeRoundedBook01,
  FileCategory.subtitle => HugeIcons.strokeRoundedSubtitle,
  FileCategory.unknown => HugeIcons.strokeRoundedFileUnknown,
};

/// 分类到图标配色的映射；集中管理以免 UI 各处硬编码颜色。
///
/// [folderState] 仅在分类为 [FileCategory.folder] 时生效：受保护目录使用
/// 中性轮廓色，其余目录沿用主题第三色。
Color fileCategoryColor(
  BuildContext context,
  FileCategory category, {
  FolderIconState folderState = FolderIconState.closed,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (category == FileCategory.folder) {
    return folderState == FolderIconState.locked
        ? scheme.outline
        : scheme.tertiary;
  }
  return switch (category) {
    FileCategory.image ||
    FileCategory.video ||
    FileCategory.audio ||
    FileCategory.pdf => scheme.primary,
    _ => scheme.onSurfaceVariant,
  };
}

/// 组合分类的中文标签与图标；文件夹图标随 [folderState] 变化。
FileTypeInfo fileTypeInfo(
  FileCategory category, {
  FolderIconState folderState = FolderIconState.closed,
}) => FileTypeInfo(
  category: category,
  label: fileCategoryLabel(category),
  icon: fileCategoryIcon(category, folderState: folderState),
);
