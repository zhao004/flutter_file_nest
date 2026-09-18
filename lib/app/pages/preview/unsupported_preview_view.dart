import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../file_type/file_icon_mapper.dart';
import '../../file_type/file_type_info.dart';
import '../../models/storage_entry.dart';
import '../../services/archive_service.dart';
import '../../services/saf_storage.dart';

/// 无法在应用内预览的文件信息页：展示名称、类型与大小，并引导外部打开。
///
/// 不做内容解析，避免把未知二进制当成文本误读；分享入口在归档服务
/// 未注册时隐藏，保证测试与最小运行环境可用。
class UnsupportedPreviewView extends StatelessWidget {
  const UnsupportedPreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageGateway>();
    final archive = Get.isRegistered<ArchiveGateway>()
        ? Get.find<ArchiveGateway>()
        : null;
    final category = entry.fileCategory;
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fileCategoryIcon(category),
                size: 64,
                color: fileCategoryColor(context, category),
              ),
              const SizedBox(height: 16),
              Text(
                entry.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '暂不支持在应用内预览此文件',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(entry: entry),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => storage.openFile(entry),
                icon: const Icon(Icons.open_in_new),
                label: const Text('用其他应用打开'),
              ),
              if (archive != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => archive.share([entry]),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('分享'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 文件基础信息：类型、大小与修改时间；缺失时显示“未知”。
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.entry});

  final StorageEntry entry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(context, '类型', fileCategoryLabel(entry.fileCategory)),
          _row(context, '大小', formatBytes(entry.size)),
          _row(context, '修改时间', _formatTime(entry.modifiedAt)),
        ],
      ),
    ),
  );

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _formatTime(DateTime? time) {
  if (time == null) return '未知';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
