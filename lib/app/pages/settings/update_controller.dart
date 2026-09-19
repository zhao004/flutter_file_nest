import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../i18n/app_l10n.dart';
import '../../models/update_models.dart';
import '../../services/update_api.dart';
import '../../services/update_installer.dart';

/// 更新检查与安装流程状态。
///
/// 检查由启动静默检查与设置页手动检查触发；下载、校验与安装只在用户确认后
/// 执行。控制器为常驻单例，界面通过 signals 订阅进度与错误，不做重复请求与
/// 并发下载。
class UpdateController {
  UpdateController({
    required this._api,
    required this._installer,
    required this._build,
    this._tempDirectory = getTemporaryDirectory,
  });

  final UpdateApi _api;
  final UpdateInstallerGateway _installer;
  final AppBuildInfo _build;
  final Future<Directory> Function() _tempDirectory;

  /// 当前应用版本；设置页展示与检查参数来源。
  AppBuildInfo get build => _build;

  /// 是否正在请求更新接口。
  final checking = signal(false);

  /// 最近一次检查发现的可用更新；无更新或检查失败时为 null。
  final pending = signal<UpdatePackage?>(null);

  /// 是否正在下载安装包。
  final downloading = signal(false);

  /// 已接收字节数与服务端声明的总字节数。
  final received = signal(0);
  final total = signal<int?>(null);

  /// 是否正在校验安装包摘要。
  final verifying = signal(false);

  /// 是否正在启动系统安装程序。
  final installing = signal(false);

  /// 可展示的错误；关闭弹窗时清除。
  final error = signal<String?>(null);

  /// 安装失败是否因缺少「安装未知应用」权限。
  final needsInstallPermission = signal(false);

  Future<UpdateCheckOutcome>? _checking;
  bool _startupChecked = false;
  UpdateDownload? _task;
  File? _verifiedFile;
  String? _verifiedVersion;

  /// 下载、校验或安装是否进行中。
  bool get busy => downloading.value || verifying.value || installing.value;

  /// 下载完成度；总大小未知时为 null（界面显示不确定进度）。
  double? get downloadFraction {
    final totalBytes = total.value;
    if (totalBytes == null || totalBytes <= 0) return null;
    return (received.value / totalBytes).clamp(0, 1).toDouble();
  }

  /// 检查更新；重复调用复用同一请求，结果不抛异常。
  Future<UpdateCheckOutcome> check() =>
      _checking ??= _runCheck().whenComplete(() => _checking = null);

  /// 启动静默检查：每个应用进程只执行一次。
  ///
  /// 仅在发现可用更新时返回结果；已是最新或检查失败都静默返回 null，
  /// 不打扰用户，需要时可在设置页手动重试。
  Future<UpdateAvailable?> checkOnStartup() async {
    if (_startupChecked) return null;
    _startupChecked = true;
    final outcome = await check();
    return outcome is UpdateAvailable ? outcome : null;
  }

  Future<UpdateCheckOutcome> _runCheck() async {
    checking.value = true;
    pending.value = null;
    error.value = null;
    needsInstallPermission.value = false;
    try {
      final outcome = await _api.check(_build);
      if (outcome is UpdateAvailable) pending.value = outcome.package;
      return outcome;
    } on Exception {
      return UpdateCheckFailure(AppL10n.current.updateErrorNetwork);
    } finally {
      checking.value = false;
    }
  }

  /// 下载并安装 [pending]；返回是否已成功启动系统安装程序。
  ///
  /// 摘要校验不通过或安装失败时保留可展示错误；用户取消下载不作为错误。
  Future<bool> startUpdate() async {
    final package = pending.value;
    if (package == null || busy) return false;
    error.value = null;
    needsInstallPermission.value = false;
    downloading.value = true;
    received.value = 0;
    total.value = null;
    var launched = false;
    try {
      final base = await _tempDirectory();
      final directory = Directory(
        '${base.path}${Platform.pathSeparator}${UpdateApiConfig.downloadDirectoryName}',
      );
      final task = _api.download(package, directory);
      _task = task;
      final subscription = task.progress.listen((event) {
        received.value = event.received;
        total.value = event.total;
      });
      final file = await task.file;
      await subscription.cancel();
      downloading.value = false;
      _task = null;

      verifying.value = true;
      final mismatch = await _verifyFile(file, package);
      verifying.value = false;
      if (mismatch != null) {
        await _deleteQuietly(file);
        _verifiedFile = null;
        _verifiedVersion = null;
        error.value = mismatch;
        return false;
      }
      _verifiedFile = file;
      _verifiedVersion = package.versionName;
      launched = await _install(file);
    } on UpdateDownloadCancelled {
      // 用户主动取消：api 已清理半成品，这里不展示错误。
    } on Exception catch (failure) {
      error.value = failure is UpdateDownloadFailure
          ? failure.message
          : AppL10n.current.updateErrorDownload;
    } finally {
      downloading.value = false;
      verifying.value = false;
      _task = null;
    }
    return launched;
  }

  /// 重试安装；已有通过校验的安装包时不再重新下载。
  Future<bool> retryInstall() async {
    final package = pending.value;
    final file = _verifiedFile;
    if (package == null ||
        file == null ||
        _verifiedVersion != package.versionName) {
      return startUpdate();
    }
    if (!await file.exists()) {
      _verifiedFile = null;
      _verifiedVersion = null;
      return startUpdate();
    }
    needsInstallPermission.value = false;
    return _install(file);
  }

  /// 中止当前下载；半成品由下载实现删除。
  void cancelDownload() => _task?.cancel();

  /// 打开系统「安装未知应用」授权页。
  Future<void> openInstallPermissionSettings() async {
    try {
      await _installer.openInstallPermissionSettings();
    } on UpdateInstallFailure catch (failure) {
      error.value = failure.message;
    }
  }

  /// 关闭弹窗时清理一次性状态；待更新信息与已校验安装包保留以便继续。
  void reset() {
    error.value = null;
    needsInstallPermission.value = false;
    if (!busy) {
      received.value = 0;
      total.value = null;
    }
  }

  Future<bool> _install(File file) async {
    installing.value = true;
    error.value = null;
    try {
      await _installer.installApk(file);
      return true;
    } on UpdateInstallFailure catch (failure) {
      needsInstallPermission.value = failure.permissionRequired;
      error.value = failure.permissionRequired
          ? AppL10n.current.updatePermissionRequired
          : failure.message;
      return false;
    } finally {
      installing.value = false;
    }
  }

  /// 校验安装包摘要；通过返回 null，否则返回可展示错误。
  ///
  /// GitHub 仅在附件提供 sha256；摘要缺失时跳过校验。
  Future<String?> _verifyFile(File file, UpdatePackage package) async {
    final expected = package.sha256;
    if (expected.isEmpty) return null;
    try {
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() == expected.trim().toLowerCase()) {
        return null;
      }
    } on FileSystemException {
      /* 读取失败同样按校验不通过处理。 */
    }
    return AppL10n.current.updateErrorHash;
  }

  /// 清理安装包；失败不影响结果反馈。
  Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      /* 文件可能已被系统缓存清理。 */
    }
  }
}
