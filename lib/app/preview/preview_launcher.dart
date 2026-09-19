import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/storage_entry.dart';
import '../routes/app_routes.dart';
import '../services/saf_storage.dart';
import 'preview_kind.dart';
import 'preview_limits.dart';
import 'preview_resolver.dart';

/// text/code 且可写且未超过读取上限时，直接进入编辑器；其余走只读预览。
///
/// 不可写或超限的文件仍可在只读预览中查看，并可通过“用其他应用打开”编辑。
bool prefersTextEditor(StorageEntry entry) {
  final kind = resolvePreviewKind(entry);
  if (kind != PreviewKind.text && kind != PreviewKind.code) return false;
  if (!entry.canWrite) return false;
  final size = entry.size;
  return size == null || size <= textReadLimit;
}

/// 打开条目预览：外部类型交给 Android 系统应用，文本/代码直接进入编辑，
/// 其余进入应用内分发页。
///
/// 返回 true 表示进入了应用内页面，调用方可在返回后刷新列表以反映
/// 预览/编辑可能产生的改动。
Future<bool> openEntryPreview(
  BuildContext context,
  StorageEntry entry, {
  required StorageGateway storage,
}) async {
  if (entry.isDirectory) return false;
  if (shouldOpenExternally(entry)) {
    await storage.openFile(entry);
    return false;
  }
  if (prefersTextEditor(entry)) {
    await context.push<void>(Routes.textEditor, extra: entry);
    return true;
  }
  await context.push<void>(Routes.preview, extra: entry);
  return true;
}
