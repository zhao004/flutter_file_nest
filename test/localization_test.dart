import 'package:cupertino_ui/cupertino_ui.dart' as cupertino_ui;
import 'package:filenest/app/localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// 应用根配置：与 main.dart 保持一致，用于回归“缺少本地化”问题。
  Widget app(Widget home) => MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: appSupportedLocales,
    home: home,
  );

  testWidgets('material_ui 与 cupertino_ui 本地化可用（应用与编辑器）', (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    expect(
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations),
      isNotNull,
      reason: '缺少 material_ui MaterialLocalizations',
    );
    expect(
      Localizations.of<cupertino_ui.CupertinoLocalizations>(
        context,
        cupertino_ui.CupertinoLocalizations,
      ),
      isNotNull,
      reason: '缺少 cupertino_ui CupertinoLocalizations',
    );
  });

  test('legacy 委托保留，供未迁移依赖兜底', () {
    // 未迁移依赖按 flutter_localizations 的 legacy 类型查找本地化；此处只校验
    // 委托已注册，避免为断言类型而在测试中重新引入 legacy 设计库。
    expect(
      appLocalizationsDelegates,
      containsAll(<LocalizationsDelegate<dynamic>>[
        legacy.GlobalMaterialLocalizations.delegate,
        legacy.GlobalCupertinoLocalizations.delegate,
      ]),
    );
  });

  test('支持的地区不含地区变体（material_ui 仅识别语言代码）', () {
    expect(appSupportedLocales, const [Locale('zh'), Locale('en')]);
  });
}
