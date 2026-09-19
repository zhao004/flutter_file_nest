import 'package:filenest/app/localization.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

void main() {
  /// 应用根配置：与 main.dart 保持一致，用于回归“缺少本地化”问题。
  legacy.Widget app(legacy.Widget home) => legacy.MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: appSupportedLocales,
    home: home,
  );

  testWidgets('legacy Material/Cupertino 本地化可用（应用自身组件）', (tester) async {
    await tester.pumpWidget(app(const legacy.SizedBox()));
    final context = tester.element(find.byType(legacy.SizedBox));

    expect(
      legacy.Localizations.of<legacy.MaterialLocalizations>(
        context,
        legacy.MaterialLocalizations,
      ),
      isNotNull,
      reason: '应用自身组件缺少 legacy MaterialLocalizations',
    );
    expect(
      legacy.Localizations.of<cupertino.CupertinoLocalizations>(
        context,
        cupertino.CupertinoLocalizations,
      ),
      isNotNull,
      reason: '应用自身组件缺少 legacy CupertinoLocalizations',
    );
  });

  testWidgets('material_ui 本地化可用（图片/视频编辑器）', (tester) async {
    await tester.pumpWidget(app(const legacy.SizedBox()));
    final context = tester.element(find.byType(legacy.SizedBox));

    expect(
      legacy.Localizations.of<material_ui.MaterialLocalizations>(
        context,
        material_ui.MaterialLocalizations,
      ),
      isNotNull,
      reason: '编辑器缺少 material_ui MaterialLocalizations',
    );
  });

  test('支持的地区不含地区变体（material_ui 仅识别语言代码）', () {
    expect(appSupportedLocales, const [
      legacy.Locale('zh'),
      legacy.Locale('en'),
    ]);
  });
}
