import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../home/home_controller.dart';

/// 管理单个活动根目录；文件导入与录制均交由系统应用完成。
class SettingsView extends GetView<HomeController> {
  const SettingsView({super.key});
  @override
  Widget build(BuildContext context) => Obx(
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
        ],
      ),
    ),
  );
}
