import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/di/injector.dart';
import 'package:filenest/app/i18n/locale_controller.dart';
import 'package:filenest/app/models/update_models.dart';
import 'package:filenest/app/pages/home/home_controller.dart';
import 'package:filenest/app/pages/preview/preview_settings_controller.dart';
import 'package:filenest/app/pages/settings/editor_settings_view.dart';
import 'package:filenest/app/pages/settings/settings_view.dart';
import 'package:filenest/app/pages/settings/theme_picker_view.dart';
import 'package:filenest/app/pages/settings/update_controller.dart';
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

  /// 注册更新控制器；返回假接口以便注入检查结果。
  FakeUpdateApi registerUpdates() {
    final api = FakeUpdateApi();
    getIt.registerSingleton<UpdateController>(
      UpdateController(
        api: api,
        installer: FakeUpdateInstaller(),
        build: const AppBuildInfo(version: '1.0.0', buildNumber: 1),
      ),
    );
    return api;
  }

  testWidgets('设置页可切换外观模式并持久化', (tester) async {
    final (theme, store) = await registerTheme();
    registerLocale();
    registerUpdates();
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

  testWidgets('设置页外观项按配色、外观模式、语言排序', (tester) async {
    final (theme, _) = await registerTheme();
    registerLocale();
    registerUpdates();
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

    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('主题配色'), lessThan(top('外观模式')));
    expect(top('外观模式'), lessThan(top('语言')));
  });

  testWidgets('设置页可切换语言并持久化', (tester) async {
    final (theme, _) = await registerTheme();
    final (locale, store) = registerLocale();
    registerUpdates();
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

  testWidgets('设置页检查更新展示新版本弹窗', (tester) async {
    final (theme, _) = await registerTheme();
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
    final api = registerUpdates();
    api.outcome = const UpdateAvailable(
      UpdatePackage(
        versionName: '1.2.0',
        downloadUrl: 'https://example.com/app.apk',
        filesize: 2048,
        releaseNotes: '## 新增\n- 修复问题',
      ),
    );
    await tester.pumpWidget(
      localizedApp(const SettingsView(), theme: theme.lightTheme),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前版本 1.0.0 (1)'), findsOneWidget);

    await tester.ensureVisible(find.text('检查更新'));
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 1.2.0'), findsOneWidget);
    expect(find.text('更新内容'), findsOneWidget);
    expect(find.text('安装包大小：2.0 KB'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('稍后再说'), findsOneWidget);
  });

  testWidgets('强制更新弹窗不提供稍后再说', (tester) async {
    final (theme, _) = await registerTheme();
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
    final api = registerUpdates();
    api.outcome = const UpdateAvailable(
      UpdatePackage(
        versionName: '1.2.0',
        downloadUrl: 'https://example.com/app.apk',
        forceUpdate: true,
      ),
    );
    await tester.pumpWidget(
      localizedApp(const SettingsView(), theme: theme.lightTheme),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('检查更新'));
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('此版本为强制更新，需完成后才能继续使用'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('稍后再说'), findsNothing);
  });
}
