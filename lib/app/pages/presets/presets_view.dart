import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/camera_presets.dart';
import '../camera/app_camera_controller.dart';
import 'presets_controller.dart';

/// 拍摄预设列表：内置示例与我的预设，应用前按当前镜头能力校验。
class PresetsView extends GetView<PresetsController> {
  const PresetsView({super.key});

  /// 询问预设名称；返回去除首尾空白后的名称，取消返回 null。
  Future<String?> _askName(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? initial,
  }) async {
    final text = TextEditingController(text: initial ?? '');
    String? error;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: text,
            autofocus: true,
            maxLength: 30,
            decoration: InputDecoration(labelText: '预设名称', errorText: error),
            onChanged: (value) =>
                setState(() => error = validatePresetName(value)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: error == null && text.text.trim().isNotEmpty
                  ? () => Navigator.pop(dialogContext, text.text.trim())
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _notify(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 应用预设：录制中先确认停止保存，有校验调整项时逐项展示后确认。
  Future<void> _apply(BuildContext context, CameraPreset preset) async {
    if (!preset.usable) {
      _notify(context, preset.issue ?? '预设配置不可用');
      return;
    }
    final camera = controller.camera;
    if (camera.state.value == CaptureState.recording) {
      final proceed = await _confirm(
        context,
        title: '应用预设前停止录像？',
        message: '当前正在录像，应用预设需要先停止并保存。',
        confirmLabel: '停止并应用',
      );
      if (!proceed) return;
    }
    final validation = controller.validate(preset);
    if (validation.hasAdjustments) {
      if (!context.mounted) return;
      final proceed = await _confirm(
        context,
        title: '按设备能力调整后应用？',
        message: validation.adjustments
            .map((item) => '· ${item.message}')
            .join('\n'),
        confirmLabel: '调整并应用',
      );
      if (!proceed) return;
    }
    final report = await controller.apply(preset);
    if (context.mounted) {
      _notify(context, report.summary);
    }
  }

  Future<void> _createFromCurrent(BuildContext context) async {
    final name = await _askName(context, title: '保存当前配置', confirmLabel: '保存');
    if (name == null) return;
    final created = await controller.createFromCurrent(name);
    if (!context.mounted) return;
    _notify(
      context,
      created ? '已保存预设：$name' : controller.error.value ?? '保存失败',
    );
  }

  Future<void> _rename(BuildContext context, CameraPreset preset) async {
    final name = await _askName(
      context,
      title: '重命名预设',
      confirmLabel: '重命名',
      initial: preset.name,
    );
    if (name == null) return;
    final renamed = await controller.rename(preset, name);
    if (!context.mounted) return;
    _notify(
      context,
      renamed ? '已重命名为：$name' : controller.error.value ?? '重命名失败',
    );
  }

  Future<void> _overwrite(BuildContext context, CameraPreset preset) async {
    final proceed = await _confirm(
      context,
      title: '用当前配置覆盖？',
      message: '「${preset.name}」的原有配置将被当前拍摄参数替换。',
      confirmLabel: '覆盖',
    );
    if (!proceed) return;
    final updated = await controller.overwriteFromCurrent(preset);
    if (!context.mounted) return;
    _notify(
      context,
      updated ? '已更新预设：${preset.name}' : controller.error.value ?? '更新失败',
    );
  }

  Future<void> _delete(BuildContext context, CameraPreset preset) async {
    final proceed = await _confirm(
      context,
      title: '删除预设？',
      message: '将删除「${preset.name}」，不影响其他预设。',
      confirmLabel: '删除',
    );
    if (!proceed) return;
    final deleted = await controller.delete(preset);
    if (!context.mounted) return;
    _notify(
      context,
      deleted ? '已删除预设：${preset.name}' : controller.error.value ?? '删除失败',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('拍摄预设')),
    floatingActionButton: Obx(
      () => FloatingActionButton.extended(
        onPressed: controller.busy.value
            ? null
            : () => _createFromCurrent(context),
        icon: const Icon(Icons.add),
        label: const Text('保存当前配置'),
      ),
    ),
    body: Obx(() {
      final camera = controller.camera;
      final activeName = camera.activePresetName.value;
      final modified = camera.presetModified.value;
      return ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (controller.error.value != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                controller.error.value!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          const _SectionHeader(title: '内置预设'),
          for (final preset in controller.builtIns)
            _PresetTile(
              preset: preset,
              active: activeName == preset.name,
              modified: activeName == preset.name && modified,
              onApply: () => _apply(context, preset),
            ),
          const _SectionHeader(title: '我的预设'),
          if (controller.userPresets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '尚未保存预设，可点击右下角保存当前配置。',
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
          for (final preset in controller.userPresets)
            _PresetTile(
              preset: preset,
              active: activeName == preset.name,
              modified: activeName == preset.name && modified,
              onApply: () => _apply(context, preset),
              menu: [
                PopupMenuItem(value: 'overwrite', child: const Text('用当前配置覆盖')),
                PopupMenuItem(value: 'rename', child: const Text('重命名')),
                PopupMenuItem(value: 'delete', child: const Text('删除')),
              ],
              onMenu: (value) {
                switch (value) {
                  case 'overwrite':
                    _overwrite(context, preset);
                  case 'rename':
                    _rename(context, preset);
                  case 'delete':
                    _delete(context, preset);
                }
              },
            ),
        ],
      );
    }),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: Colors.blueGrey),
    ),
  );
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.active,
    required this.modified,
    required this.onApply,
    this.menu,
    this.onMenu,
  });

  final CameraPreset preset;
  final bool active;
  final bool modified;
  final VoidCallback onApply;
  final List<PopupMenuEntry<String>>? menu;
  final ValueChanged<String>? onMenu;

  @override
  Widget build(BuildContext context) {
    final config = preset.config;
    final subtitle = config == null
        ? (preset.issue ?? '配置不可用')
        : '${config.summary}\n${preset.builtIn ? '内置示例，应用前按本机能力校验' : '最近更新：${_formatTime(preset.updatedAt)}'}';
    return ListTile(
      title: Row(
        children: [
          Flexible(child: Text(preset.name, overflow: TextOverflow.ellipsis)),
          if (active)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(modified ? '使用中 · 已修改' : '使用中'),
              ),
            ),
        ],
      ),
      subtitle: Text(subtitle),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonal(
            onPressed: config == null ? null : onApply,
            child: const Text('应用'),
          ),
          if (menu != null && onMenu != null)
            PopupMenuButton<String>(
              tooltip: '预设操作',
              onSelected: onMenu,
              itemBuilder: (context) => menu!,
            ),
        ],
      ),
      onTap: config == null ? null : onApply,
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
