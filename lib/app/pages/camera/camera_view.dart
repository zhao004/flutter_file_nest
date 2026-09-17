import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';
import 'app_camera_controller.dart';

/// 横竖屏录制界面；系统返回需先完成停止保存，保存失败可保留待处理任务。
class CameraView extends GetView<AppCameraController> {
  const CameraView({super.key});

  Future<bool> _confirmStop(BuildContext context) async {
    if (controller.state.value != CaptureState.recording) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('停止并保存当前录像？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续录制'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('停止并保存'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _back(BuildContext context) async {
    if (controller.busy.value || !await _confirmStop(context)) return;
    if (controller.state.value == CaptureState.recording) {
      await controller.stop();
    }
    if (controller.state.value == CaptureState.pending) {
      if (!context.mounted) return;
      if (!controller.canLeavePending) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('录像尚不能离页恢复，请先重试或放弃本次录像')));
        return;
      }
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('视频尚未保存到文件夹'),
          content: const Text('返回后可在待保存录像中重试。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('留在此页'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保留并返回'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    Get.back<void>();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final state = controller.state.value;
    final busy = controller.busy.value;
    final live = state == CaptureState.ready || state == CaptureState.recording;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: '返回文件夹',
            onPressed: busy ? null : () => _back(context),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            controller.folder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: controller.audioEnabled.value ? '关闭录音' : '开启录音',
              onPressed: busy || !live
                  ? null
                  : () async {
                      if (await _confirmStop(context)) {
                        await controller.toggleAudio();
                      }
                    },
              icon: Icon(
                controller.audioEnabled.value ? Icons.mic : Icons.mic_off,
              ),
            ),
            IconButton(
              tooltip: '切换摄像头',
              onPressed: busy || !live || controller.cameraCount.value < 2
                  ? null
                  : () async {
                      if (await _confirmStop(context)) {
                        await controller.switchCamera();
                      }
                    },
              icon: const Icon(Icons.cameraswitch),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final preview = Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (live) controller.driver.preview(),
                    if (state == CaptureState.initializing ||
                        state == CaptureState.saving)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              state == CaptureState.saving ? '正在保存' : '正在打开相机',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    if (state == CaptureState.failed ||
                        state == CaptureState.pending ||
                        state == CaptureState.saved ||
                        state == CaptureState.suspended)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  state == CaptureState.saved
                                      ? Icons.check_circle_outline
                                      : Icons.videocam_off_outlined,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  controller.message.value ?? '相机已暂停',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 20),
                                if (state == CaptureState.saved)
                                  FilledButton(
                                    onPressed: () => Get.back<void>(),
                                    child: const Text('返回文件夹'),
                                  ),
                                if (state == CaptureState.pending)
                                  FilledButton(
                                    onPressed: busy
                                        ? null
                                        : controller.retrySave,
                                    child: Text(
                                      controller.needsStop ? '重试停止' : '重试保存',
                                    ),
                                  ),
                                if (state == CaptureState.pending)
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final confirmed =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                        title: const Text(
                                                          '放弃本次录像？',
                                                        ),
                                                        content: const Text(
                                                          '未保存的本地录像将被永久删除。',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              '取消',
                                                            ),
                                                          ),
                                                          FilledButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              '放弃录像',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                            if (confirmed == true) {
                                              await controller.discard();
                                            }
                                          },
                                    child: const Text('放弃录像'),
                                  ),
                                if (state == CaptureState.failed)
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      FilledButton(
                                        onPressed: busy
                                            ? null
                                            : controller.initialize,
                                        child: const Text('重试'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Get.find<StorageGateway>()
                                                .openAppSettings(),
                                        child: const Text('系统权限设置'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (live)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          children: [
                            Text(
                              controller.targetLabel.value,
                              style: const TextStyle(
                                color: Colors.white,
                                backgroundColor: Colors.black54,
                              ),
                            ),
                            if (controller.message.value != null)
                              Text(
                                controller.message.value!,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  backgroundColor: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
              final controls = SizedBox(
                width: constraints.maxWidth > constraints.maxHeight
                    ? 184
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatDuration(controller.elapsed.value),
                        style: TextStyle(
                          color: state == CaptureState.recording
                              ? Colors.redAccent
                              : Colors.white,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            tooltip: '恢复 1 倍',
                            onPressed: live && !busy
                                ? () => controller.setZoom(1)
                                : null,
                            icon: const Icon(Icons.restart_alt),
                            color: Colors.white,
                          ),
                          Expanded(
                            child: Text(
                              '${controller.zoomLevel.value.toStringAsFixed(1)}x',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        min: controller.minZoom.value,
                        max: controller.maxZoom.value,
                        value: controller.zoomLevel.value.clamp(
                          controller.minZoom.value,
                          controller.maxZoom.value,
                        ),
                        onChanged:
                            live &&
                                controller.maxZoom.value >
                                    controller.minZoom.value
                            ? controller.setZoom
                            : null,
                      ),
                      SizedBox.square(
                        dimension: 76,
                        child: IconButton.filled(
                          tooltip: state == CaptureState.recording
                              ? '停止录制'
                              : '开始录制',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: !live || busy
                              ? null
                              : () async {
                                  if (state == CaptureState.recording) {
                                    await controller.stop();
                                    if (controller.state.value ==
                                        CaptureState.saved) {
                                      Get.back<void>();
                                    }
                                  } else {
                                    await controller.start();
                                  }
                                },
                          icon: Icon(
                            state == CaptureState.recording
                                ? Icons.stop
                                : Icons.fiber_manual_record,
                            size: 38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              return constraints.maxWidth > constraints.maxHeight
                  ? Row(
                      children: [
                        preview,
                        SingleChildScrollView(child: controls),
                      ],
                    )
                  : Column(children: [preview, controls]);
            },
          ),
        ),
      ),
    );
  });
}
