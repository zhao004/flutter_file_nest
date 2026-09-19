import 'package:flutter/material.dart';
import 'package:filenest/app/file_type/file_category.dart';
import 'package:filenest/app/file_type/file_category_icon.dart';
import 'package:filenest/app/file_type/file_icon_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

import 'support/localization.dart';

void main() {
  test('每个分类都有非空标签与图标', () {
    for (final category in FileCategory.values) {
      final info = fileTypeInfo(category, zhL10n);
      expect(info.label, isNotEmpty, reason: category.name);
      expect(info.icon, isNotEmpty, reason: category.name);
    }
  });

  test('文件夹四种状态使用互不相同的图标', () {
    final icons = {
      for (final state in FolderIconState.values)
        identityHashCode(
          fileCategoryIcon(FileCategory.folder, folderState: state),
        ),
    };
    expect(icons.length, FolderIconState.values.length);
  });

  testWidgets('FileCategoryIcon 渲染 hugeicons 图标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FileCategoryIcon(category: FileCategory.image)),
      ),
    );
    expect(find.byType(HugeIcon), findsOneWidget);
  });

  testWidgets('文件夹与媒体分类的配色有别，其余分类统一', (tester) async {
    late Map<FileCategory, Color> colors;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            colors = {
              for (final category in [
                FileCategory.folder,
                FileCategory.image,
                FileCategory.video,
                FileCategory.pdf,
                FileCategory.code,
                FileCategory.unknown,
              ])
                category: fileCategoryColor(context, category),
            };
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(colors[FileCategory.folder], isNot(colors[FileCategory.image]));
    expect(colors[FileCategory.image], colors[FileCategory.video]);
    expect(colors[FileCategory.image], colors[FileCategory.pdf]);
    expect(colors[FileCategory.code], colors[FileCategory.unknown]);
    expect(colors[FileCategory.image], isNot(colors[FileCategory.unknown]));
  });

  testWidgets('受保护文件夹使用中性配色', (tester) async {
    late Color openColor;
    late Color lockedColor;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            openColor = fileCategoryColor(
              context,
              FileCategory.folder,
              folderState: FolderIconState.closed,
            );
            lockedColor = fileCategoryColor(
              context,
              FileCategory.folder,
              folderState: FolderIconState.locked,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(lockedColor, isNot(openColor));
  });
}
