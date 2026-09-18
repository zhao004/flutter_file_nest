import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../file_type/file_category.dart';
import '../../file_type/file_extension_map.dart';
import '../../file_type/file_icon_mapper.dart';
import '../../file_type/file_type_detector.dart';
import '../../models/storage_entry.dart';
import '../../preview/archive_reader.dart';
import '../../preview/preview_limits.dart';
import '../../preview/text_content.dart';
import '../../services/saf_storage.dart';
import 'preview_widgets.dart';

/// 压缩包内容浏览：以虚拟文件系统列出条目，可逐级进入并预览文本或图片。
///
/// 内部条目不是真实 SAF 文件，仅存在于归档中；解压仍由文件列表的长按菜单
/// 完成，避免在此页引入源文件夹依赖。
class ArchivePreviewView extends StatefulWidget {
  const ArchivePreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<ArchivePreviewView> createState() => _ArchivePreviewViewState();
}

class _ArchivePreviewViewState extends State<ArchivePreviewView> {
  /// 内嵌预览文本的最大字节数；超出部分不展示。
  static const _inlineTextLimit = 256 * 1024;

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'ico',
  };

  late final StorageGateway _storage = Get.find<StorageGateway>();
  late Future<ArchiveContents> _future = _load();
  String _prefix = '';

  Future<ArchiveContents> _load() async {
    final result = await _storage.readDocumentLimited(
      widget.entry,
      maxBytes: archiveReadLimit,
    );
    // 让加载态先渲染一帧，再执行可能较慢的解码。
    await Future<void>.delayed(Duration.zero);
    return readArchive(
      result.bytes,
      extension: fileExtension(widget.entry.name),
      archiveName: widget.entry.name,
    );
  }

  void _retry() => setState(() {
    _prefix = '';
    _future = _load();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: '用其他应用打开',
          onPressed: () => _storage.openFile(widget.entry),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: FutureBuilder<ArchiveContents>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = snapshot.error;
        if (error != null) {
          return PreviewErrorView(
            entry: widget.entry,
            message: error is ArchiveReadException
                ? error.message
                : previewErrorMessage(error, fallback: '无法解析此压缩包'),
            icon: Icons.folder_zip_outlined,
            onRetry: _retry,
          );
        }
        final contents = snapshot.data!;
        final rows = _children(contents, _prefix);
        return Column(
          children: [
            if (_prefix.isNotEmpty) _breadcrumb(),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('压缩包为空'))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 60),
                      itemBuilder: (context, index) =>
                          _rowTile(contents, rows[index]),
                    ),
            ),
          ],
        );
      },
    ),
  );

  Widget _breadcrumb() => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Row(
      children: [
        IconButton(
          tooltip: '上一级',
          onPressed: () {
            final parent = _prefix.replaceFirst(RegExp(r'[^/]+/$'), '');
            setState(() => _prefix = parent);
          },
          icon: const Icon(Icons.arrow_upward),
        ),
        Expanded(
          child: Text(_prefix, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );

  Widget _rowTile(ArchiveContents contents, _ArchiveRow row) {
    final icon = row.isDirectory
        ? fileCategoryIcon(FileCategory.folder)
        : fileCategoryIcon(detectFileCategory(name: row.name));
    return ListTile(
      leading: Icon(icon),
      title: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: row.isDirectory ? null : Text(formatBytes(row.size)),
      trailing: row.isDirectory
          ? const Icon(Icons.chevron_right, size: 18)
          : null,
      onTap: () => row.isDirectory
          ? setState(() => _prefix = row.path)
          : _openEntry(contents, row),
    );
  }

  Future<void> _openEntry(ArchiveContents contents, _ArchiveRow row) async {
    final Uint8List bytes;
    try {
      bytes = contents.readEntry(row.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法读取该条目')));
      }
      return;
    }
    final extension = fileExtension(row.name);
    final Widget content;
    if (extension == 'svg') {
      content = SvgPicture.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('无法预览此图片'),
      );
    } else if (_imageExtensions.contains(extension)) {
      content = Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('无法预览此图片'),
      );
    } else if (_isTextLike(row.name)) {
      final display = bytes.length > _inlineTextLimit
          ? Uint8List.sublistView(bytes, 0, _inlineTextLimit)
          : bytes;
      final decoded = await decodeTextBytes(
        display,
        truncated: display.length != bytes.length,
      );
      content = SelectableText(
        decoded.text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      );
    } else {
      content = const Center(child: Text('此类型不支持内嵌预览'));
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(row.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(dialogContext).height * 0.6,
          child: content is Image || content is SvgPicture
              ? InteractiveViewer(child: Center(child: content))
              : SingleChildScrollView(child: content),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 按当前目录前缀列出直接子项，目录在前并按名称排序。
  List<_ArchiveRow> _children(ArchiveContents contents, String prefix) {
    final directories = <String>{};
    final files = <_ArchiveRow>[];
    for (final entry in contents.entries) {
      final path = entry.path;
      if (path.isEmpty || path == prefix || !path.startsWith(prefix)) continue;
      final rest = path.substring(prefix.length);
      if (rest.isEmpty) continue;
      final slash = rest.indexOf('/');
      if (slash < 0) {
        if (entry.isDirectory) {
          directories.add(rest);
        } else {
          files.add(
            _ArchiveRow(
              name: rest,
              path: path,
              isDirectory: false,
              size: entry.size,
            ),
          );
        }
      } else {
        directories.add(rest.substring(0, slash));
      }
    }
    final rows = <_ArchiveRow>[
      for (final name in directories)
        _ArchiveRow(
          name: name,
          path: '$prefix$name/',
          isDirectory: true,
          size: 0,
        ),
      ...files,
    ];
    rows.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return rows;
  }
}

/// 文本类条目的判定：文本、代码、字幕与表格分类都可内嵌查看。
bool _isTextLike(String name) {
  final category = detectFileCategory(name: name);
  return category == FileCategory.text ||
      category == FileCategory.code ||
      category == FileCategory.subtitle ||
      category == FileCategory.spreadsheet;
}

/// 归档浏览中的一行：目录或文件。
class _ArchiveRow {
  const _ArchiveRow({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
}
