import 'package:flutter/services.dart';

import '../models/batch_models.dart';
import '../models/storage_entry.dart';

/// 缩略图请求的最长边像素；列表显示区域仅 48 逻辑像素，
/// 采用较小尺寸可降低原生解码、通道传输与 Dart 解码成本。
const int thumbnailDimension = 128;

/// 封装平台协议，测试通过替代此接口覆盖权限与文件失败状态。
abstract interface class StorageGateway {
  Future<StorageEntry?> pickRoot();
  Future<StorageEntry> validateRoot(String rootUri);
  Future<List<StorageEntry>> list(StorageEntry folder);
  Future<StorageEntry> createFolder(StorageEntry parent, String name);

  /// 重命名文件或文件夹；返回新标识的条目，调用方须以返回值为准。
  Future<StorageEntry> renameEntry(
    StorageEntry parent,
    StorageEntry entry,
    String name,
  );

  /// 移动条目到同一已授权根目录下的目标文件夹。
  ///
  /// 提供方不支持移动时由原生侧回退为复制、校验、再删除源；
  /// 源删除失败时返回 [MoveResult]，不得静默复制出重复文件。
  Future<MoveResult> move(
    StorageEntry parent,
    StorageEntry entry,
    StorageEntry targetFolder,
  );

  /// 视频或图片的缩略图 PNG 数据；失败或不可解码时返回 null。
  Future<Uint8List?> thumbnail(
    StorageEntry entry, {
    int maxDimension = thumbnailDimension,
  });

  /// 视频的可读属性（时长/尺寸等）；缺失的键按未知处理。
  Future<Map<String, Object?>> videoDetails(StorageEntry entry);
  Future<DeletionImpact> deletionImpact(StorageEntry entry);
  Future<void> delete(StorageEntry entry);
  Future<void> openFile(StorageEntry entry);
  Future<void> openAppSettings();

  /// 从系统选择器批量导入内容到目标目录；取消返回空列表。
  ///
  /// 支持一次选择多个任意类型文件，逐个复制到目标目录；部分失败由实现上报。
  Future<List<StorageEntry>> pickImport(
    List<String> mimeTypes,
    StorageEntry targetFolder,
  );

  /// 将外部来源（content:// 或 file://）批量复制到目标目录；来源为空返回空列表。
  ///
  /// 用于接收其他应用“打开方式/分享”的文件；部分失败由实现上报。
  Future<List<StorageEntry>> importDocuments(
    List<String> sourceUris,
    StorageEntry targetFolder,
  );

  /// 系统相机拍摄照片并复制到目标目录；取消或拍摄失败返回 null。
  Future<StorageEntry?> takePhoto(StorageEntry targetFolder);

  /// 系统相机录制视频并复制到目标目录；取消或录制失败返回 null。
  Future<StorageEntry?> takeVideo(StorageEntry targetFolder);

  /// 读取文档字节；仅用于应用内图片预览等有界场景。
  Future<Uint8List?> readDocument(StorageEntry entry);

  /// 读取文档字节并限制最大长度；超出 [maxBytes] 的部分不传输。
  ///
  /// 用于文本、代码、归档与电子书预览，避免大文件占用内存；调用方通过
  /// [DocumentBytes.truncated] 判断是否被截断并给出提示。
  Future<DocumentBytes> readDocumentLimited(
    StorageEntry entry, {
    required int maxBytes,
  });

  /// PDF 页数；受密码保护或损坏时抛出结构化错误。
  Future<Map<String, Object?>> pdfInfo(StorageEntry entry);

  /// 渲染 PDF 指定页为 JPEG 字节；[page] 从 0 开始。
  Future<Uint8List?> pdfPage(StorageEntry entry, {required int page});
}

/// 受限读取结果：字节内容与是否因超过上限被截断。
class DocumentBytes {
  const DocumentBytes(this.bytes, {required this.truncated});

  final Uint8List bytes;
  final bool truncated;
}

class DeletionImpact {
  const DeletionImpact(this.files, this.folders);
  final int files;
  final int folders;
}

class SafStorage implements StorageGateway {
  static const channel = MethodChannel('lens_vault/saf_storage');

  Map<String, Object> _entry(StorageEntry entry) => {
    'rootUri': entry.rootUri,
    'documentId': entry.documentId,
  };
  Map<String, Object> _parent(StorageEntry entry) => {
    'rootUri': entry.rootUri,
    'parentDocumentId': entry.documentId,
  };

  Future<StorageEntry> _document(
    String method,
    Map<String, Object> args,
  ) async {
    final value = await channel.invokeMapMethod<Object?, Object?>(method, args);
    if (value == null) {
      throw PlatformException(code: 'invalid_response', message: '存储响应为空');
    }
    return StorageEntry.fromMap(value);
  }

  @override
  Future<StorageEntry?> pickRoot() async {
    final value = await channel.invokeMapMethod<Object?, Object?>('pickRoot');
    return value == null ? null : StorageEntry.fromMap(value);
  }

  @override
  Future<StorageEntry> validateRoot(String rootUri) =>
      _document('validateRoot', {'rootUri': rootUri});

  @override
  Future<List<StorageEntry>> list(StorageEntry folder) async {
    final result = await channel.invokeListMethod<Object?>(
      'listChildren',
      _parent(folder),
    );
    return (result ?? [])
        .map((value) => StorageEntry.fromMap(value as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<StorageEntry> createFolder(StorageEntry parent, String name) =>
      _document('createFolder', {..._parent(parent), 'name': name});

  @override
  Future<StorageEntry> renameEntry(
    StorageEntry parent,
    StorageEntry entry,
    String name,
  ) => _document('renameEntry', {
    ..._entry(entry),
    'parentDocumentId': parent.documentId,
    'name': name,
  });

  @override
  Future<MoveResult> move(
    StorageEntry parent,
    StorageEntry entry,
    StorageEntry targetFolder,
  ) async {
    final result = await channel
        .invokeMapMethod<Object?, Object?>('moveEntry', {
          ..._entry(entry),
          'parentDocumentId': parent.documentId,
          'targetParentDocumentId': targetFolder.documentId,
        });
    if (result == null) {
      throw PlatformException(code: 'invalid_response', message: '移动响应为空');
    }
    return MoveResult(
      StorageEntry.fromMap(result['entry']! as Map<Object?, Object?>),
      sourceDeleted: result['sourceDeleted'] != false,
    );
  }

  @override
  Future<Uint8List?> thumbnail(
    StorageEntry entry, {
    int maxDimension = thumbnailDimension,
  }) => channel.invokeMethod<Uint8List>('loadThumbnail', {
    ..._entry(entry),
    'maxDimension': maxDimension,
  });

  @override
  Future<Map<String, Object?>> videoDetails(StorageEntry entry) async {
    final result = await channel.invokeMapMethod<String, Object?>(
      'videoMetadata',
      _entry(entry),
    );
    return result ?? const {};
  }

  @override
  Future<DeletionImpact> deletionImpact(StorageEntry entry) async {
    final result = await channel.invokeMapMethod<String, Object?>(
      'getDeletionImpact',
      _entry(entry),
    );
    return DeletionImpact(
      (result!['fileCount'] as num).toInt(),
      (result['folderCount'] as num).toInt(),
    );
  }

  @override
  Future<void> delete(StorageEntry entry) =>
      channel.invokeMethod<void>('deleteEntry', _entry(entry));

  @override
  Future<void> openFile(StorageEntry entry) =>
      channel.invokeMethod<void>('openFile', _entry(entry));

  @override
  Future<void> openAppSettings() =>
      channel.invokeMethod<void>('openAppSettings');

  @override
  Future<List<StorageEntry>> pickImport(
    List<String> mimeTypes,
    StorageEntry targetFolder,
  ) async {
    final values = await channel.invokeListMethod<Object?>('pickImport', {
      'mimeTypes': mimeTypes,
      'rootUri': targetFolder.rootUri,
      'parentDocumentId': targetFolder.documentId,
    });
    return (values ?? [])
        .map((value) => StorageEntry.fromMap(value as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<List<StorageEntry>> importDocuments(
    List<String> sourceUris,
    StorageEntry targetFolder,
  ) async {
    final values = await channel.invokeListMethod<Object?>('importDocuments', {
      'sources': sourceUris,
      'rootUri': targetFolder.rootUri,
      'parentDocumentId': targetFolder.documentId,
    });
    return (values ?? [])
        .map((value) => StorageEntry.fromMap(value as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<StorageEntry?> takePhoto(StorageEntry targetFolder) async {
    final value = await channel.invokeMapMethod<Object?, Object?>('takePhoto', {
      'rootUri': targetFolder.rootUri,
      'parentDocumentId': targetFolder.documentId,
    });
    return value == null ? null : StorageEntry.fromMap(value);
  }

  @override
  Future<StorageEntry?> takeVideo(StorageEntry targetFolder) async {
    final value = await channel.invokeMapMethod<Object?, Object?>('takeVideo', {
      'rootUri': targetFolder.rootUri,
      'parentDocumentId': targetFolder.documentId,
    });
    return value == null ? null : StorageEntry.fromMap(value);
  }

  @override
  Future<Uint8List?> readDocument(StorageEntry entry) =>
      channel.invokeMethod<Uint8List>('readDocument', _entry(entry));

  @override
  Future<DocumentBytes> readDocumentLimited(
    StorageEntry entry, {
    required int maxBytes,
  }) async {
    final value = await channel.invokeMapMethod<Object?, Object?>(
      'readDocumentLimited',
      {..._entry(entry), 'maxBytes': maxBytes},
    );
    if (value == null) {
      throw PlatformException(code: 'invalid_response', message: '读取响应为空');
    }
    final raw = value['bytes'];
    final bytes = raw is Uint8List
        ? raw
        : Uint8List.fromList((raw as List<Object?>? ?? const []).cast<int>());
    return DocumentBytes(bytes, truncated: value['truncated'] == true);
  }

  @override
  Future<Map<String, Object?>> pdfInfo(StorageEntry entry) async {
    final result = await channel.invokeMapMethod<String, Object?>(
      'pdfInfo',
      _entry(entry),
    );
    return result ?? const {'pageCount': 0};
  }

  @override
  Future<Uint8List?> pdfPage(StorageEntry entry, {required int page}) =>
      channel.invokeMethod<Uint8List>('pdfPageBytes', {
        ..._entry(entry),
        'page': page,
      });
}

String userError(Object error) {
  if (error is PlatformException) return error.message ?? '文件操作失败';
  return '操作未完成，请重试';
}
