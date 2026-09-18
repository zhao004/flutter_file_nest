import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:filenest/app/pages/home/home_controller.dart';
import 'package:filenest/app/pages/settings/settings_view.dart';
import 'package:filenest/app/pages/settings/theme_picker_view.dart';
import 'package:filenest/app/theme/theme_controller.dart';

import 'support/archive_fakes.dart';
import 'support/fakes.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  /// 注册主题控制器并返回其内存存储，便于断言持久化结果。
  Future<(ThemeController, MemoryThemeStore)> registerTheme() async {
    final store = MemoryThemeStore();
    final controller = ThemeController(store);
    await controller.initialize();
    Get.put<ThemeController>(controller);
    return (controller, store);
  }

  testWidgets('设置页可切换外观模式并持久化', (tester) async {
    final (theme, store) = await registerTheme();
    Get.put(
      HomeController(
        storage: FakeStorage(),
        store: MemoryStore(),
        archive: FakeArchive(),
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        theme: theme.lightTheme,
        darkTheme: theme.darkTheme,
        themeMode: theme.mode.value,
        home: const SettingsView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('外观模式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);

    await tester.tap(find.text('外观模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(store.value.mode, ThemeMode.dark);
    // 选择后设置页副标题同步为深色。
    expect(find.text('深色'), findsOneWidget);
  });

  testWidgets('主题选择页选中方案后持久化', (tester) async {
    final (theme, store) = await registerTheme();
    await tester.pumpWidget(
      GetMaterialApp(theme: theme.lightTheme, home: const ThemePickerView()),
    );
    await tester.pumpAndSettle();

    // 默认配色为 blue，改选其它方案以验证选择确实生效并持久化。
    final target = find.text(FlexScheme.indigo.data.name).first;
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(store.value.scheme, FlexScheme.indigo);
  });
}
