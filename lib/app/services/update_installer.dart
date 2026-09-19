import 'dart:io';

import 'package:flutter/services.dart';

import '../i18n/app_l10n.dart';

/// 系统安装器网关；测试通过替代实现注入。
abstract interface class UpdateInstallerGateway {
  /// 启动系统安装程序；失败抛出 [UpdateInstallFailure]。
  Future<void> installApk(File file);

  /// 打开「安装未知应用」授权页；仅 Android 8.0+ 需要。
  Future<void> openInstallPermissionSettings();
}

/// 安装失败；[permissionRequired] 表示需先授予安装未知应用权限。
class UpdateInstallFailure implements Exception {
  const UpdateInstallFailure(this.code, this.message);

  final String code;
  final String message;

  bool get permissionRequired =>
      code == UpdateInstallerService.permissionRequiredCode;

  @override
  String toString() => 'UpdateInstallFailure($code, $message)';
}

/// `filenest/update` 通道封装。
class UpdateInstallerService implements UpdateInstallerGateway {
  const UpdateInstallerService();

  static const channel = MethodChannel('filenest/update');

  /// 与 Android 侧约定：未授予「安装未知应用」权限。
  static const permissionRequiredCode = 'permission_required';

  @override
  Future<void> installApk(File file) async {
    try {
      await channel.invokeMethod<void>('installApk', {'path': file.path});
    } on PlatformException catch (failure) {
      throw UpdateInstallFailure(
        failure.code,
        failure.message ?? AppL10n.current.updateErrorInstall,
      );
    } on MissingPluginException {
      throw UpdateInstallFailure(
        'unavailable',
        AppL10n.current.updateErrorInstall,
      );
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    try {
      await channel.invokeMethod<void>('openInstallPermissionSettings');
    } on PlatformException catch (failure) {
      throw UpdateInstallFailure(
        failure.code,
        failure.message ?? AppL10n.current.updateErrorInstall,
      );
    } on MissingPluginException {
      throw UpdateInstallFailure(
        'unavailable',
        AppL10n.current.updateErrorInstall,
      );
    }
  }
}
