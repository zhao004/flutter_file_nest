import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/di/injector.dart';
import 'package:filenest/app/i18n/locale_controller.dart';
import 'package:filenest/app/pages/home/home_controller.dart';
import 'package:filenest/app/pages/preview/preview_settings_controller.dart';
import 'package:filenest/app/pages/settings/editor_settings_view.dart';
import 'package:filenest/app/pages/settings/settings_view.dart';
import 'package:filenest/app/pages/settings/theme_picker_view.dart';
import 'package:filenest/app/theme/theme_controller.dart';

import 'support/archive_fakes.dart';
import 'support/fakes.dart';
import 'support/localization.dart';

void main() {
  tearDown(() => getIt.reset());

  /// 注册主题控制器并返回其内存存储，便于断言持久化结果。
  Future<(ThemeController, MemoryThemeStore)> registerTheme() async {
    final store = MemoryThemeStore();
    final controller = ThemeController(store);
    await controller.initialize();
    getIt.registerSingleton<ThemeController>(controller);
    return (controller, store);
  }

  /// 注册语言控制器并返回其内存存储，便于断言持久化结果。
  (LocaleController, MemoryStore) registerLocale() {
    final store = MemoryStore();
    final controller = LocaleController(store);
    getIt.registerSingleton<LocaleController>(controller);
    return (controller, store);
  }

  testWidgets('设置页可切换外观模式并持久化', (tester) async {
    final (theme, store) = await registerTheme();
    registerLocale();
    getIt.registerSingleton(
      HomeController(
        storage: FakeStorage(),
        store: MemoryStore(),
        archive: FakeArchive(),
      ),
    );
    getIt.registerSingleton<PreviewSettingsController>(
      PreviewSettingsController(MemoryStore()),
    );
    await tester.pumpWidget(
      localizedApp(
        const SettingsView(),
        theme: theme.lightTheme,
        darkTheme: theme.darkTheme,
        themeMode: theme.mode.value,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('外观模式'), findsOneWidget);
    // “跟随系统”同时作为外观模式与语言偏好的副标题出现。
    expect(find.text('跟随系统'), findsWidgets);
    expect(find.text('编辑器配置'), findsOneWidget);

    await tester.tap(find.text('外观模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(store.value.mode, ThemeMode.dark);
    // 选择后设置页副标题同步为深色。
    expect(find.text('深色'), findsOneWidget);
  });

  testWidgets('设置页可切换语言并持久化', (tester) async {
    final (theme, _) = await registerTheme();
    final (locale, store) = registerLocale();
    getIt.registerSingleton(
      HomeController(
        storage: FakeStorage(),
        store: MemoryStore(),
        archive: FakeArchive(),
      ),
    );
    getIt.registerSingleton<PreviewSettingsController>(
      PreviewSettingsController(MemoryStore()),
    );
    await tester.pumpWidget(
      localizedApp(const SettingsView(), theme: theme.lightTheme),
    );
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    expect(find.text('跟随系统'), findsWidgets);

    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(store.value.locale, 'en');
    expect(locale.localeName.value, 'en');
    // 选择后设置页副标题同步为 English。
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('编辑器配置页切换行号并持久化', (tester) async {
    final store = MemoryStore();
    getIt.registerSingleton<PreviewSettingsController>(
      PreviewSettingsController(store),
    );
    await tester.pumpWidget(localizedApp(const EditorSettingsView()));
    await tester.pumpAndSettle();

    expect(find.text('显示行号'), findsOneWidget);
    expect(store.value.showLineNumbers, true);

    await tester.tap(find.text('显示行号'));
    await tester.pumpAndSettle();

    expect(store.value.showLineNumbers, false);
  });

  testWidgets('编辑器配置页可切换 Markdown 展示模式', (tester) async {
    final store = MemoryStore();
    getIt.registerSingleton<PreviewSettingsController>(
      PreviewSettingsController(store),
    );
    await tester.pumpWidget(localizedApp(const EditorSettingsView()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('展示模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('源码'));
    await tester.pumpAndSettle();

    expect(store.value.markdownMode, 'source');
  });

  testWidgets('主题选择页选中方案后持久化', (tester) async {
    final (theme, store) = await registerTheme();
    await tester.pumpWidget(
      localizedApp(const ThemePickerView(), theme: theme.lightTheme),
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
