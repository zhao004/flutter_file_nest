import 'package:filenest/app/preview/markdown_style.dart';
import 'package:filenest/app/theme/app_theme.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Markdown 样式表取自传入主题', () {
    final light = buildLightTheme(FlexScheme.blue);
    final dark = buildDarkTheme(FlexScheme.blue);

    final lightSheet = markdownStyleSheetFor(light);
    expect(lightSheet.a?.color, light.colorScheme.primary);
    expect(lightSheet.p, light.textTheme.bodyMedium);
    expect(
      lightSheet.code?.backgroundColor,
      light.colorScheme.surfaceContainerHighest,
    );
    expect(lightSheet.tableBorder, isNotNull);

    final darkSheet = markdownStyleSheetFor(dark);
    expect(darkSheet.a?.color, dark.colorScheme.primary);
    expect(
      darkSheet.code?.backgroundColor,
      dark.colorScheme.surfaceContainerHighest,
    );
    // 深浅主题产生不同颜色，确认未落到 legacy 兜底主题。
    expect(darkSheet.a?.color, isNot(lightSheet.a?.color));
  });
}
