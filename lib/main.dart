import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'app/di/injector.dart';
import 'app/localization.dart';
import 'app/routes/app_router.dart';
import 'app/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit 使用 libmpv，需在创建 Player 前完成初始化。
  MediaKit.ensureInitialized();
  // 依赖注册必须在首帧前完成，主题读取失败时保留默认值。
  await configureDependencies();
  runApp(FileNestApp(router: createAppRouter()));
}

/// Android 文件与录制应用入口；主题变化时仅重建应用根配置。
class FileNestApp extends StatelessWidget {
  const FileNestApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final theme = getIt<ThemeController>();
      return MaterialApp.router(
        title: 'FileNest',
        debugShowCheckedModeBanner: false,
        theme: theme.lightTheme,
        darkTheme: theme.darkTheme,
        themeMode: theme.mode.value,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        routerConfig: router,
      );
    },
  );
}
