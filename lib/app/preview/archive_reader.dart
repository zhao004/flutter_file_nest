import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'preview_limits.dart';

/// 归档条目元信息；不携带内容，避免一次性展开全部文件。
class ArchiveEntryInfo {
  const ArchiveEntryInfo({
    required this.path,
    required this.isDirectory,
    required this.size,
  });

  /// 归档内的相对路径，统一使用 `/` 分隔。
  final String path;
  final bool isDirectory;
  final int size;
}

/// 已解码归档的可浏览句柄；条目内容按需读取以限制内存。
class ArchiveContents {
  ArchiveContents._(this.entries, this._archive, this._single);

  final List<ArchiveEntryInfo> entries;
  final Archive? _archive;
  final Uint8List? _single;

  /// 读取指定路径条目的字节；目录、不存在或解析失败时抛出异常。
  Uint8List readEntry(String path) {
    final single = _single;
    if (single != null) {
      if (entries.length == 1 && entries.first.path == path) return single;
      throw const ArchiveReadException('归档内容不可用');
    }
    final file = _archive?.find(path);
    if (file == null || !file.isFile) {
      throw const ArchiveReadException('无法读取该条目');
    }
    return Uint8List.fromList(file.content);
  }
}

/// 归档解析失败；调用方转换为可展示文案。
class ArchiveReadException implements Exception {
  const ArchiveReadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 解析归档字节为可浏览内容。
///
/// [extension] 为文件名最后一段扩展名，[archiveName] 用于单文件压缩的命名。
/// 支持 ZIP、TAR、GZ/TGZ、BZ2/TBZ2、XZ/TXZ；RAR/7Z 与 ZSTD 不在支持范围，
/// 由解析层提前交给系统打开。
ArchiveContents readArchive(
  Uint8List bytes, {
  required String extension,
  required String archiveName,
}) {
  final Archive archive;
  switch (extension) {
    case 'zip':
      archive = ZipDecoder().decodeBytes(bytes);
    case 'tar':
      archive = TarDecoder().decodeBytes(bytes);
    case 'gz':
    case 'tgz':
      final decompressed = GZipDecoder().decodeBytes(bytes);
      if (extension == 'tgz' || archiveName.toLowerCase().endsWith('.tar.gz')) {
        archive = TarDecoder().decodeBytes(decompressed);
      } else {
        return _singleContents(archiveName, '.gz', decompressed);
      }
    case 'bz2':
    case 'tbz2':
      final decompressed = BZip2Decoder().decodeBytes(bytes);
      if (extension == 'tbz2' ||
          archiveName.toLowerCase().endsWith('.tar.bz2')) {
        archive = TarDecoder().decodeBytes(decompressed);
      } else {
        return _singleContents(archiveName, '.bz2', decompressed);
      }
    case 'xz':
    case 'txz':
      final decompressed = XZDecoder().decodeBytes(bytes);
      if (extension == 'txz' || archiveName.toLowerCase().endsWith('.tar.xz')) {
        archive = TarDecoder().decodeBytes(decompressed);
      } else {
        return _singleContents(archiveName, '.xz', decompressed);
      }
    default:
      throw ArchiveReadException('不支持的压缩包格式：$extension');
  }
  return _contentsFromArchive(archive);
}

ArchiveContents _contentsFromArchive(Archive archive) {
  final files = archive.files;
  if (files.length > maxArchiveEntries) {
    throw const ArchiveReadException('压缩包条目数超过上限，已停止解析');
  }
  var total = 0;
  final entries = <ArchiveEntryInfo>[];
  for (final file in files) {
    final path = file.name.replaceAll('\\', '/');
    final isDirectory = !file.isFile || path.endsWith('/');
    final size = isDirectory ? 0 : file.size;
    total += size;
    if (total > maxArchiveUncompressedBytes) {
      throw const ArchiveReadException('压缩包展开体积超过上限，已停止解析');
    }
    entries.add(
      ArchiveEntryInfo(path: path, isDirectory: isDirectory, size: size),
    );
  }
  return ArchiveContents._(entries, archive, null);
}

ArchiveContents _singleContents(
  String archiveName,
  String suffix,
  List<int> decompressed,
) {
  final bytes = Uint8List.fromList(decompressed);
  final name = archiveName.toLowerCase().endsWith(suffix)
      ? archiveName.substring(0, archiveName.length - suffix.length)
      : '$archiveName.out';
  return ArchiveContents._(
    [ArchiveEntryInfo(path: name, isDirectory: false, size: bytes.length)],
    null,
    bytes,
  );
}
