import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../camera/camera_backend.dart';
import '../home/home_controller.dart';

/// 管理单个活动根目录、录音偏好及失败后保留的录像任务。
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
          SwitchListTile(
            title: const Text('录制声音'),
            secondary: const Icon(Icons.mic_outlined),
            value: controller.preferences.value.audioEnabled,
            onChanged: controller.busy.value
                ? null
                : (value) async {
                    try {
                      await controller.setAudio(value);
                    } catch (_) {
                      controller.error.value = '无法保存录音设置';
                    }
                  },
          ),
          // 专业后端为实验特性：通道不可用时禁用，避免误以为已生效。
          Builder(
            builder: (context) {
              final backend = Get.find<CameraBackendResolver>();
              return SwitchListTile(
                title: const Text('专业录像后端（实验）'),
                subtitle: Text(
                  backend.proAvailable
                      ? '使用原生 Camera2 会话，手动参数将在后续版本开放'
                      : '当前设备不支持或未接入',
                ),
                secondary: const Icon(Icons.videocam_outlined),
                value: controller.preferences.value.proCameraEnabled,
                onChanged: !backend.proAvailable || controller.busy.value
                    ? null
                    : (value) async {
                        try {
                          await controller.setProCameraEnabled(value);
                        } catch (_) {
                          controller.error.value = '无法保存相机后端设置';
                        }
                      },
              );
            },
          ),
          // 录制方式决定底部栏“录制”按钮的行为；关闭后进入应用内相机。
          SwitchListTile(
            title: const Text('录制时使用系统相机'),
            subtitle: const Text('关闭则使用应用内相机（变焦、曝光、预设等专业功能）'),
            secondary: const Icon(Icons.switch_video_outlined),
            value: controller.preferences.value.systemCameraRecording,
            onChanged: controller.busy.value
                ? null
                : (value) async {
                    try {
                      await controller.setSystemCameraRecording(value);
                    } catch (_) {
                      controller.error.value = '无法保存录制方式设置';
                    }
                  },
          ),
          const Divider(),
          if (controller.pending.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('待保存录像', style: TextStyle(fontSize: 18)),
            ),
          for (final job in controller.pending)
            ListTile(
              leading: const Icon(Icons.video_file_outlined),
              title: Text(job.fileName),
              subtitle: const Text('尚未保存到原文件夹'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '重试保存到原文件夹',
                    onPressed: controller.busy.value
                        ? null
                        : () => controller.retryRecording(job),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: '放弃本地录像',
                    onPressed: controller.busy.value
                        ? null
                        : () async {
                            final discard = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('放弃这段待保存录像？'),
                                content: const Text('将永久删除本地暂存的视频，无法恢复。'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('放弃录像'),
                                  ),
                                ],
                              ),
                            );
                            if (discard == true) {
                              await controller.discardRecording(job);
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
