import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/camera_presets.dart';
import '../../services/saf_storage.dart';
import '../../services/vault_store.dart';
import '../camera/app_camera_controller.dart';

/// 预设列表与增删改应用。
///
/// 配置校验与逐项应用结果由 [validatePresetConfig] 与相机控制器给出；
/// 本控制器只负责持久化用户预设与错误呈现，不复制相机参数逻辑。
class PresetsController extends GetxController {
  PresetsController({required this.camera, required this.store});

  final AppCameraController camera;
  final VaultStore store;

  /// 用户预设，按最近更新排序；内置预设来自代码常量。
  final userPresets = <CameraPreset>[].obs;
  final busy = false.obs;
  final error = RxnString();

  List<CameraPreset> get builtIns => builtInPresets;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    busy.value = true;
    error.value = null;
    try {
      await _reload();
    } catch (failure) {
      error.value = userError(failure);
    } finally {
      busy.value = false;
    }
  }

  /// 应用前按当前镜头能力校验，返回建议调整项供界面确认。
  PresetValidation validate(CameraPreset preset) => validatePresetConfig(
    preset.config ?? const PresetConfig(),
    camera.capabilities.value,
  );

  /// 应用预设；返回逐项结果，部分应用不得报告为完整成功。
  Future<PresetApplyReport> apply(CameraPreset preset) =>
      camera.applyPreset(preset);

  /// 将当前相机配置保存为新预设，并标记为已选。
  Future<bool> createFromCurrent(String name) => _run(() async {
    final invalid = validatePresetName(name);
    if (invalid != null) {
      throw PlatformException(code: 'invalid_name', message: invalid);
    }
    final now = DateTime.now();
    await store.savePreset(
      CameraPreset(
        id: 'user:${now.microsecondsSinceEpoch}',
        name: name.trim(),
        configVersion: presetConfigVersion,
        config: camera.capturePresetConfig(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    camera.markPresetApplied(name.trim());
  });

  /// 用当前配置覆盖已有预设；覆盖前由界面确认。
  Future<bool> overwriteFromCurrent(CameraPreset preset) => _run(() async {
    await store.savePreset(
      preset.copyWith(
        config: camera.capturePresetConfig(),
        configVersion: presetConfigVersion,
        updatedAt: DateTime.now(),
        clearIssue: true,
      ),
    );
    camera.markPresetApplied(preset.name);
  });

  /// 重命名预设；不改变其配置。
  Future<bool> rename(CameraPreset preset, String name) => _run(() async {
    final invalid = validatePresetName(name);
    if (invalid != null) {
      throw PlatformException(code: 'invalid_name', message: invalid);
    }
    final renamed = name.trim();
    await store.savePreset(
      preset.copyWith(name: renamed, updatedAt: DateTime.now()),
    );
    if (camera.activePresetName.value == preset.name) {
      camera.activePresetName.value = renamed;
    }
  });

  /// 删除用户预设；不影响其他预设。
  Future<bool> delete(CameraPreset preset) => _run(() async {
    await store.deletePreset(preset.id);
    if (camera.activePresetName.value == preset.name) {
      camera.clearActivePreset();
    }
  });

  Future<void> _reload() async {
    userPresets.assignAll(await store.userPresets());
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy.value) return false;
    busy.value = true;
    error.value = null;
    try {
      await action();
      await _reload();
      return true;
    } catch (failure) {
      error.value = userError(failure);
      return false;
    } finally {
      busy.value = false;
    }
  }
}
