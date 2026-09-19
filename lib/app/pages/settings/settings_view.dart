import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../home/home_controller.dart';
import '../preview/preview_settings_controller.dart';

/// 管理活动根目录与外观设置；文件导入与录制均交由系统应用完成。
class SettingsView extends GetView<HomeController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();
    final editor = Get.find<PreviewSettingsController>();
    return Obx(
      () => Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          children: [
            if (controller.busy.value) const LinearProgressIndicator(),
            if (controller.error.value != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  controller.error.value!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('存储文件夹'),
              subtitle: Text(controller.folders.firstOrNull?.name ?? '尚未选择'),
              trailing: const Icon(Icons.chevron_right),
              enabled: !controller.busy.value,
              onTap: controller.pickRoot,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('外观模式'),
              subtitle: Text(themeModeLabel(theme.mode.value)),
              onTap: () => _pickMode(context, theme),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('主题配色'),
              subtitle: Text(theme.scheme.value.data.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed<void>(Routes.themePicker),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('编辑器配置'),
              subtitle: Text('字号 ${editor.fontSize.value.round()}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed<void>(Routes.editorSettings),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择跟随系统/浅色/深色；取消不改变当前模式。
  Future<void> _pickMode(BuildContext context, ThemeController theme) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('外观模式'),
        children: [
          for (final mode in ThemeMode.values)
            ListTile(
              title: Text(themeModeLabel(mode)),
              trailing: mode == theme.mode.value
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(dialogContext, mode),
            ),
        ],
      ),
    );
    if (selected != null) await theme.setMode(selected);
  }
}
