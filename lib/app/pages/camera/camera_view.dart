import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/camera_capture_settings.dart';
import '../../models/camera_parameter_models.dart';
import '../../models/storage_entry.dart';
import '../../routes/app_pages.dart';
import '../../services/saf_storage.dart';
import 'app_camera_controller.dart';

/// 倍率快捷键候选值；展示前按当前镜头变焦范围过滤。
const _zoomPresets = [1.0, 2.0, 3.0, 5.0, 10.0];

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

  /// 可用倍率候选：超出设备范围的快捷键不展示。
  List<double> get _availableZoomPresets {
    final min = controller.minZoom.value;
    final max = controller.maxZoom.value;
    return [
      for (final value in _zoomPresets)
        if (value >= min - 1e-6 && value <= max + 1e-6) value,
    ];
  }

  Widget _zoomPresetRow() {
    final presets = _availableZoomPresets;
    final current = controller.zoomLevel.value;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final value in presets)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(52, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: (current - value).abs() < 0.05
                      ? Colors.amber
                      : Colors.white,
                  side: BorderSide(
                    color: (current - value).abs() < 0.05
                        ? Colors.amber
                        : Colors.white38,
                  ),
                ),
                onPressed: () => controller.setZoom(value),
                child: Text(
                  '${value == value.roundToDouble() ? value.round() : value}x',
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 应用新的录制规格；录制中需先通过停止保存确认。
  Future<void> _changeSettings(
    RecordingSettings next,
    BuildContext context,
  ) async {
    if (next == controller.requestedSettings.value) return;
    if (controller.state.value == CaptureState.recording) {
      if (!await _confirmStop(context)) return;
    }
    await controller.applyCaptureSettings(next);
  }

  /// 校验自定义码率输入（Mbps）；返回错误文案，合法输入返回 null。
  String? _validateBitrateInput(String input) {
    final value = double.tryParse(input.trim());
    if (value == null) return '请输入数字';
    if (value < minCustomBitrateBps / 1000000 ||
        value > maxCustomBitrateBps / 1000000) {
      return '范围 ${minCustomBitrateBps ~/ 1000000} – '
          '${maxCustomBitrateBps ~/ 1000000} Mbps';
    }
    return null;
  }

  /// 自定义码率输入对话框；返回换算后的 bps，取消返回 null。
  Future<int?> _editCustomBitrate(BuildContext context) async {
    final current = controller.requestedSettings.value;
    final initial =
        current.bitrate == VideoBitratePreset.custom &&
            current.hasValidCustomBitrate
        ? (current.customBitrateBps! / 1000000).toStringAsFixed(0)
        : '';
    final text = TextEditingController(text: initial);
    String? error;
    final bps = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('自定义码率'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: text,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      setState(() => error = _validateBitrateInput(value)),
                  decoration: const InputDecoration(
                    labelText: '码率（Mbps）',
                    hintText: '1 – 100',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: error == null
                    ? () {
                        final value = double.tryParse(text.text.trim());
                        if (value == null) return;
                        Navigator.pop(dialogContext, (value * 1000000).round());
                      }
                    : null,
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    if (bps == null) return null;
    return bps;
  }

  Widget _specChip(String label, bool selected, VoidCallback? onTap) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: selected ? Colors.amber : Colors.blueGrey,
        side: BorderSide(color: selected ? Colors.amber : Colors.blueGrey),
      ),
      onPressed: onTap,
      child: Text(label),
    ),
  );

  Widget _chipRow(List<Widget> chips) => SizedBox(
    height: 40,
    child: ListView(scrollDirection: Axis.horizontal, children: chips),
  );

  /// 防抖控件：仅在设备报告了 off 以外的可用模式时展示。
  Widget _stabilizationSection() {
    final modes = List.of(controller.stabilizationModes);
    final current = controller.stabilizationMode.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('防抖', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        _chipRow([
          for (final mode in modes)
            _specChip(
              switch (mode) {
                VideoStabilizationMode.off => '关闭',
                VideoStabilizationMode.level1 => '一级',
                VideoStabilizationMode.level2 => '二级',
                VideoStabilizationMode.level3 => '三级',
              },
              current == mode,
              () => controller.setStabilization(mode),
            ),
        ]),
      ],
    );
  }

  /// 录制规格区块：分辨率、帧率与码率均为请求值；切换将重建会话。
  Widget _specSection(BuildContext context) {
    final settings = controller.requestedSettings.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('录制规格', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        _labeledChipRow('分辨率', [
          for (final quality in CaptureQuality.values)
            _specChip(
              switch (quality) {
                CaptureQuality.p480 => '480p',
                CaptureQuality.p720 => '720p',
                CaptureQuality.p1080 => '1080p',
                CaptureQuality.max => '设备最高',
              },
              settings.quality == quality,
              () => _changeSettings(settings.withQuality(quality), context),
            ),
        ]),
        _labeledChipRow('帧率', [
          for (final fps in CaptureFps.values)
            _specChip(
              switch (fps) {
                CaptureFps.auto => '自动',
                CaptureFps.fps30 => '30 FPS',
                CaptureFps.fps60 => '60 FPS',
              },
              settings.fps == fps,
              () => _changeSettings(settings.withFps(fps), context),
            ),
        ]),
        _labeledChipRow('码率', [
          for (final preset in VideoBitratePreset.values)
            _specChip(
              preset == VideoBitratePreset.custom
                  ? '自定义…'
                  : switch (preset) {
                      VideoBitratePreset.auto => '自动',
                      VideoBitratePreset.low => '低',
                      VideoBitratePreset.standard => '标准',
                      VideoBitratePreset.high => '高',
                      VideoBitratePreset.custom => '自定义…',
                    },
              settings.bitrate == preset,
              preset == VideoBitratePreset.custom
                  ? () async {
                      final bps = await _editCustomBitrate(context);
                      if (bps == null || !context.mounted) return;
                      await _changeSettings(
                        settings.withBitrate(
                          VideoBitratePreset.custom,
                          customBitrateBps: bps,
                        ),
                        context,
                      );
                    }
                  : () =>
                        _changeSettings(settings.withBitrate(preset), context),
            ),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '码率为请求值，实际码率以成品文件为准',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _labeledChipRow(String label, List<Widget> chips) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: 52,
        child: Text(label, style: const TextStyle(color: Colors.blueGrey)),
      ),
      Expanded(
        child: SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: chips),
        ),
      ),
    ],
  );

  /// 参数抽屉：曝光补偿、补光灯、点按对焦/测光与录制规格的集中入口。
  void _openParameterPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Obx(() {
        final caps = controller.capabilities.value;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '拍摄参数',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (caps == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('未能读取镜头能力，参数不可用'),
                    )
                  else ...[
                    if (caps.hasExposureOffset) _exposureControl(caps),
                    if (!caps.hasExposureOffset)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('当前镜头不支持曝光补偿'),
                      ),
                    if (caps.torchSupported)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('补光灯'),
                        subtitle: const Text('录制与预览期间持续补光'),
                        value: controller.torchEnabled.value,
                        onChanged: (_) => controller.toggleTorch(),
                      ),
                    if (controller.focusPoint.value != null ||
                        controller.exposurePoint.value != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('已设置点按对焦/测光'),
                        subtitle: const Text('点击清除可恢复默认中央区域'),
                        trailing: TextButton(
                          onPressed: controller.clearFocusPoint,
                          child: const Text('清除'),
                        ),
                      ),
                    if (controller.stabilizationModes.length > 1) ...[
                      const Divider(),
                      _stabilizationSection(),
                    ],
                    const Divider(),
                    _specSection(context),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _exposureControl(LensCapabilities caps) {
    final min = caps.exposureOffsetMin;
    final max = caps.exposureOffsetMax;
    final value = controller.exposureOffset.value.clamp(min, max).toDouble();
    final divisions = caps.exposureOffsetStep > 0
        ? ((max - min) / caps.exposureOffsetStep).round()
        : null;
    final display = value >= 0
        ? '+${value.toStringAsFixed(1)}'
        : value.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('曝光补偿'),
            Expanded(
              child: Text(
                '$display EV',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ),
            TextButton(
              onPressed: value == 0 ? null : controller.resetExposure,
              child: const Text('复位'),
            ),
          ],
        ),
        Slider(
          min: min,
          max: max,
          divisions: divisions,
          value: value,
          label: display,
          onChanged: (value) => controller.applyExposureOffset(value),
        ),
      ],
    );
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
              tooltip: '拍摄预设',
              onPressed: busy || !live
                  ? null
                  : () => Get.toNamed<void>(Routes.presets),
              icon: const Icon(Icons.bookmarks_outlined),
            ),
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
                    if (live) _interactivePreview(),
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
                              controller.specLabel.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                backgroundColor: Colors.black54,
                              ),
                            ),
                            if (controller.activePresetName.value != null)
                              Text(
                                '预设：${controller.activePresetName.value}'
                                '${controller.presetModified.value ? '（已修改）' : ''}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  backgroundColor: Colors.black54,
                                  fontSize: 12,
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
                    if (live && controller.focusPoint.value != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment(
                              controller.focusPoint.value!.dx * 2 - 1,
                              controller.focusPoint.value!.dy * 2 - 1,
                            ),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white70),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
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
                      if (live && _availableZoomPresets.length > 1)
                        _zoomPresetRow(),
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
                          IconButton(
                            tooltip: '拍摄参数',
                            onPressed:
                                live &&
                                    !busy &&
                                    controller.capabilities.value != null
                                ? () => _openParameterPanel(context)
                                : null,
                            icon: const Icon(Icons.tune),
                            color: Colors.white,
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

  /// 预览层手势：双指捏合连续变焦，单指点按对焦/测光；捏合期间忽略点按。
  Widget _interactivePreview() {
    return _PreviewGestures(
      onTap: controller.tapFocus,
      onPinchStart: controller.beginPinch,
      onPinchUpdate: (scale) => unawaited(controller.updatePinch(scale)),
      onPinchEnd: controller.endPinch,
      child: controller.driver.preview(),
    );
  }
}

/// 承载捏合状态的预览手势层；无状态父级重建时手势状态保持稳定。
class _PreviewGestures extends StatefulWidget {
  const _PreviewGestures({
    required this.child,
    required this.onTap,
    required this.onPinchStart,
    required this.onPinchUpdate,
    required this.onPinchEnd,
  });

  final Widget child;
  final void Function(Offset normalizedPoint) onTap;
  final VoidCallback onPinchStart;
  final void Function(double scale) onPinchUpdate;
  final VoidCallback onPinchEnd;

  @override
  State<_PreviewGestures> createState() => _PreviewGesturesState();
}

class _PreviewGesturesState extends State<_PreviewGestures> {
  bool _pinching = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: (details) {
      if (_pinching) return;
      final box = context.findRenderObject()! as RenderBox;
      final size = box.size;
      if (size.width <= 0 || size.height <= 0) return;
      widget.onTap(
        Offset(
          (details.localPosition.dx / size.width).clamp(0.0, 1.0),
          (details.localPosition.dy / size.height).clamp(0.0, 1.0),
        ),
      );
    },
    onScaleStart: (details) {
      if (details.pointerCount > 1) {
        _pinching = true;
        widget.onPinchStart();
      }
    },
    onScaleUpdate: (details) {
      if (details.pointerCount > 1) widget.onPinchUpdate(details.scale);
    },
    onScaleEnd: (_) {
      if (_pinching) {
        _pinching = false;
        widget.onPinchEnd();
      }
    },
    child: widget.child,
  );
}
