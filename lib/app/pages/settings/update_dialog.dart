import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../localization.dart';
import '../../models/storage_entry.dart' show formatBytes;
import '../../models/update_models.dart';
import '../../preview/markdown_style.dart';
import 'update_controller.dart';

/// 新版本弹窗：展示版本信息与更新日志，并承载下载、校验与安装流程。
///
/// [UpdatePackage.forceUpdate] 为 true 或流程进行中时禁止关闭弹窗；安装程序
/// 成功启动后由本弹窗自行关闭，并提示用户在系统界面完成安装。
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    required this.controller,
    required this.package,
    super.key,
  });

  final UpdateController controller;
  final UpdatePackage package;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateController get controller => widget.controller;
  UpdatePackage get package => widget.package;

  /// 下载并安装；成功启动安装程序后关闭弹窗并提示。
  Future<void> _startUpdate() async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.updateInstallLaunched;
    final launched = await controller.startUpdate();
    if (!mounted || !launched) return;
    controller.reset();
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// 权限授予后重试安装；必要时重新下载。
  Future<void> _retryInstall() async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.updateInstallLaunched;
    final launched = await controller.retryInstall();
    if (!mounted || !launched) return;
    controller.reset();
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final downloading = controller.downloading.value;
      final verifying = controller.verifying.value;
      final installing = controller.installing.value;
      final error = controller.error.value;
      final needsPermission = controller.needsInstallPermission.value;
      return PopScope(
        canPop: !package.forceUpdate && !controller.busy,
        child: AlertDialog(
          title: Text(context.l10n.updateAvailableTitle(package.versionName)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (package.forceUpdate) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(context.l10n.updateForceHint)),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.l10n.updatePackageSize(
                      formatBytes(package.filesize, context.l10n),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (package.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.updateReleaseNotes,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildNotes(context),
                  ],
                  if (downloading || verifying || installing) ...[
                    const SizedBox(height: 16),
                    _buildProgress(
                      context,
                      downloading: downloading,
                      verifying: verifying,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: _buildActions(
            context,
            downloading: downloading,
            verifying: verifying,
            installing: installing,
            busy: controller.busy,
            needsPermission: needsPermission,
          ),
        ),
      );
    },
  );

  /// 更新日志以 GitHub Release 正文（Markdown）渲染。
  Widget _buildNotes(BuildContext context) => MarkdownBody(
    data: package.releaseNotes,
    selectable: true,
    styleSheet: markdownStyleSheetFor(Theme.of(context)),
  );

  Widget _buildProgress(
    BuildContext context, {
    required bool downloading,
    required bool verifying,
  }) {
    if (downloading) {
      final fraction = controller.downloadFraction;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 8),
          Text(
            fraction == null
                ? context.l10n.updatePrepareDownload
                : context.l10n.updateDownloading((fraction * 100).round()),
          ),
        ],
      );
    }
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          verifying
              ? context.l10n.updateVerifying
              : context.l10n.updateInstalling,
        ),
      ],
    );
  }

  List<Widget> _buildActions(
    BuildContext context, {
    required bool downloading,
    required bool verifying,
    required bool installing,
    required bool busy,
    required bool needsPermission,
  }) {
    final l10n = context.l10n;
    if (downloading) {
      return [
        TextButton(
          onPressed: controller.cancelDownload,
          child: Text(l10n.updateCancelDownload),
        ),
      ];
    }
    if (verifying || installing) {
      return [
        TextButton(
          onPressed: null,
          child: Text(verifying ? l10n.updateVerifying : l10n.updateInstalling),
        ),
      ];
    }
    if (needsPermission) {
      return [
        if (!package.forceUpdate)
          TextButton(
            onPressed: () {
              controller.reset();
              Navigator.of(context).pop();
            },
            child: Text(l10n.updateLater),
          ),
        TextButton(
          onPressed: controller.openInstallPermissionSettings,
          child: Text(l10n.updateOpenSettings),
        ),
        FilledButton(
          onPressed: busy ? null : _retryInstall,
          child: Text(l10n.updateRetryInstall),
        ),
      ];
    }
    return [
      if (!package.forceUpdate)
        TextButton(
          onPressed: () {
            controller.reset();
            Navigator.of(context).pop();
          },
          child: Text(l10n.updateLater),
        ),
      FilledButton(
        onPressed: busy ? null : _startUpdate,
        child: Text(
          controller.error.value == null ? l10n.updateNow : l10n.commonRetry,
        ),
      ),
    ];
  }
}

/// 显示新版本弹窗；强制更新时禁止点击遮罩关闭，由设置页与启动检查共用。
Future<void> showUpdateDialog({
  required BuildContext context,
  required UpdateController controller,
  required UpdatePackage package,
}) => showDialog<void>(
  context: context,
  barrierDismissible: !package.forceUpdate,
  builder: (_) => UpdateDialog(controller: controller, package: package),
);
