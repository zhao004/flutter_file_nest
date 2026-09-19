import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../di/injector.dart';

import '../../models/storage_entry.dart';
import '../../i18n/app_l10n.dart';
import '../../localization.dart';
import '../../services/saf_storage.dart';

/// 预览读取失败的统一样式：说明、重试与外部打开入口。
class PreviewErrorView extends StatelessWidget {
  const PreviewErrorView({
    required this.entry,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
    super.key,
  });

  final StorageEntry entry;
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => getIt<StorageGateway>().openFile(entry),
                icon: const Icon(Icons.open_in_new),
                label: Text(context.l10n.commonOpenExternal),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 截断提示条：内容超过读取上限，仅展示前一部分。
class TruncatedNotice extends StatelessWidget {
  const TruncatedNotice({required this.entry, super.key});

  final StorageEntry entry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.info_outline, size: 20),
      title: Text(context.l10n.previewTruncated),
      trailing: TextButton(
        onPressed: () => getIt<StorageGateway>().openFile(entry),
        child: Text(context.l10n.commonOpenExternalShort),
      ),
    ),
  );
}

/// 将读取异常转换为可展示的中文文案。
String previewErrorMessage(Object error, {String? fallback}) {
  if (error is PlatformException) {
    return switch (error.code) {
      'not_found' => AppL10n.current.previewErrorNotFound,
      'permission_denied' => AppL10n.current.previewErrorPermission,
      'read_failed' || 'io_error' => AppL10n.current.previewErrorRead,
      _ => error.message ?? fallback ?? AppL10n.current.previewErrorFallback,
    };
  }
  return fallback ?? AppL10n.current.previewErrorFallback;
}
