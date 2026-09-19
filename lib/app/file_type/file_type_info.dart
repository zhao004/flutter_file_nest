import '../../l10n/generated/app_localizations.dart';
import 'file_category.dart';

/// 文件分类图标的数据类型；由 hugeicons 的 `HugeIcons.strokeRoundedX` 提供。
///
/// 该结构是 hugeicons 的图标描述（SVG 路径 JSON），不是字体 `IconData`，
/// 必须通过 `FileCategoryIcon` 组件渲染。
typedef FileIcon = List<List<dynamic>>;

/// 文件分类的展示信息：本地化标签与图标。
///
/// 供详情页等同时需要标签和图标的场景使用；列表图标可直接调用
/// `fileCategoryIcon`，无需构造本对象。
class FileTypeInfo {
  const FileTypeInfo({
    required this.category,
    required this.label,
    required this.icon,
  });

  final FileCategory category;
  final String label;
  final FileIcon icon;
}

/// 分类的本地化名称；未知类型不暴露原始扩展名。
String fileCategoryLabel(FileCategory category, AppLocalizations l10n) =>
    switch (category) {
      FileCategory.folder => l10n.categoryFolder,
      FileCategory.image => l10n.categoryImage,
      FileCategory.video => l10n.categoryVideo,
      FileCategory.audio => l10n.categoryAudio,
      FileCategory.pdf => l10n.categoryPdf,
      FileCategory.document => l10n.categoryDocument,
      FileCategory.spreadsheet => l10n.categorySpreadsheet,
      FileCategory.presentation => l10n.categoryPresentation,
      FileCategory.archive => l10n.categoryArchive,
      FileCategory.apk => l10n.categoryApk,
      FileCategory.text => l10n.categoryText,
      FileCategory.code => l10n.categoryCode,
      FileCategory.database => l10n.categoryDatabase,
      FileCategory.font => l10n.categoryFont,
      FileCategory.ebook => l10n.categoryEbook,
      FileCategory.subtitle => l10n.categorySubtitle,
      FileCategory.unknown => l10n.categoryUnknown,
    };
