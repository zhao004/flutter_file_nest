import 'package:get/get.dart';

import '../models/storage_entry.dart';
import '../routes/app_pages.dart';
import '../services/saf_storage.dart';
import 'preview_resolver.dart';

/// 打开条目预览：外部类型交给 Android 系统应用，其余进入应用内分发页。
///
/// 返回 true 表示进入了应用内预览页，调用方可在返回后刷新列表以反映
/// 预览页可能产生的改动（如解压、另存）。
Future<bool> openEntryPreview(
  StorageEntry entry, {
  required StorageGateway storage,
}) async {
  if (entry.isDirectory) return false;
  if (shouldOpenExternally(entry)) {
    await storage.openFile(entry);
    return false;
  }
  await Get.toNamed<void>(Routes.preview, arguments: entry);
  return true;
}
