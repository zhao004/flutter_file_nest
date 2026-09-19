import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../di/injector.dart';

import '../../models/storage_entry.dart';
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
                label: const Text('重试'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => getIt<StorageGateway>().openFile(entry),
                icon: const Icon(Icons.open_in_new),
                label: const Text('用其他应用打开'),
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
      title: const Text('文件较大，仅显示前一部分内容'),
      trailing: TextButton(
        onPressed: () => getIt<StorageGateway>().openFile(entry),
        child: const Text('其他应用'),
      ),
    ),
  );
}

/// 将读取异常转换为可展示的中文文案。
String previewErrorMessage(Object error, {String fallback = '无法读取此文件'}) {
  if (error is PlatformException) {
    return switch (error.code) {
      'not_found' => '文件或存储设备不可用',
      'permission_denied' => '目录访问权限已失效，请重新选择存储文件夹',
      'read_failed' || 'io_error' => '文件读取失败',
      _ => error.message ?? fallback,
    };
  }
  return fallback;
}
