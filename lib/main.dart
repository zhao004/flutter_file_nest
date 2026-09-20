import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'app/di/injector.dart';
import 'app/i18n/locale_controller.dart';
import 'app/localization.dart';
import 'app/routes/app_router.dart';
import 'app/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit 使用 libmpv，需在创建 Player 前完成初始化。
  MediaKit.ensureInitialized();
  // 依赖注册必须在首帧前完成，主题与语言读取失败时保留默认值。
  await configureDependencies();
  runApp(FileNestApp(router: createAppRouter()));
}

/// Android 文件与录制应用入口；主题与语言变化时重建应用根配置。
class FileNestApp extends StatefulWidget {
  const FileNestApp({required this.router, super.key});

  final GoRouter router;

  @override
  State<FileNestApp> createState() => _FileNestAppState();
}

class _FileNestAppState extends State<FileNestApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 系统语言变化时刷新非控件文案入口；界面文案由 MaterialApp 自行重建。
  @override
  void didChangeLocales(List<Locale>? locales) =>
      getIt<LocaleController>().syncCurrent();

  @override
  Widget build(BuildContext context) =>
      SignalBuilder(
        builder: (context) {
          final theme = getIt<ThemeController>();
          final locale = getIt<LocaleController>();
          return MaterialApp.router(
            title: 'FileNest',
            debugShowCheckedModeBanner: false,
            theme: theme.lightTheme,
            darkTheme: theme.darkTheme,
            themeMode: theme.mode.value,
            locale: locale.locale.value,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            routerConfig: widget.router,
          );
        },
      );
}
