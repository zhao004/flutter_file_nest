import 'file_category.dart';

/// 文件分类图标的数据类型；由 hugeicons 的 `HugeIcons.strokeRoundedX` 提供。
///
/// 该结构是 hugeicons 的图标描述（SVG 路径 JSON），不是字体 `IconData`，
/// 必须通过 `FileCategoryIcon` 组件渲染。
typedef FileIcon = List<List<dynamic>>;

/// 文件分类的展示信息：中文标签与图标。
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

/// 分类的中文名称；未知类型不暴露原始扩展名。
String fileCategoryLabel(FileCategory category) => switch (category) {
  FileCategory.folder => '文件夹',
  FileCategory.image => '图片',
  FileCategory.video => '视频',
  FileCategory.audio => '音频',
  FileCategory.pdf => 'PDF',
  FileCategory.document => '文档',
  FileCategory.spreadsheet => '表格',
  FileCategory.presentation => '演示文稿',
  FileCategory.archive => '压缩包',
  FileCategory.apk => '安装包',
  FileCategory.text => '文本',
  FileCategory.code => '代码',
  FileCategory.database => '数据库',
  FileCategory.font => '字体',
  FileCategory.ebook => '电子书',
  FileCategory.subtitle => '字幕',
  FileCategory.unknown => '未知文件',
};
