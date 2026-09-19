import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../di/injector.dart';
import '../../localization.dart';
import '../../models/storage_entry.dart';
import '../../models/video_export_request.dart';
import '../../preview/media_editor_format.dart';
import '../../preview/video_editor_host.dart';
import '../../preview/video_render.dart';
import '../../services/saf_storage.dart';
import 'preview_widgets.dart';

/// 视频编辑器：pro_image_editor 视频界面 + pro_video_editor 渲染。
///
/// 先把 SAF 文档导出为本地缓存文件供编辑器使用；导出时渲染到缓存并导入
/// 保险库，保存为同目录下的 `原名_edited.mp4`，原文件不变。保存成功后以
/// 新文件名作为路由返回值 pop。
class VideoEditorView extends StatefulWidget {
  const VideoEditorView({
    required this.entry,
    required this.parent,
    this.editorBuilder = buildProVideoEditor,
    this.renderer = const ProVideoRenderer(),
    this.tempDirectoryProvider = getTemporaryDirectory,
    super.key,
  });

  final StorageEntry entry;

  /// 副本的目标目录；必须可创建文件。
  final StorageEntry parent;

  /// 编辑器构建器；测试注入假实现。
  final VideoEditorBuilder editorBuilder;

  /// 渲染器；测试注入假实现。
  final VideoRenderer renderer;

  /// 渲染输出目录提供者；测试可替换为本地临时目录。
  final Future<Directory> Function() tempDirectoryProvider;

  @override
  State<VideoEditorView> createState() => _VideoEditorViewState();
}

class _VideoEditorViewState extends State<VideoEditorView> {
  late final StorageGateway _storage = getIt<StorageGateway>();

  String? _filePath;
  String? _error;
  bool _rendering = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _error = null;
      _filePath = null;
    });
    try {
      final path = await _storage.exportToCache(widget.entry);
      if (!mounted) return;
      setState(() => _filePath = path);
    } catch (failure) {
      if (!mounted) return;
      setState(
        () => _error = previewErrorMessage(
          failure,
          fallback: context.l10n.videoEditorOpenFailed,
        ),
      );
    }
  }

  Future<void> _onExport(VideoExportRequest request) async {
    if (_rendering || _closed) return;
    setState(() => _rendering = true);
    String? outputPath;
    try {
      final directory = await widget.tempDirectoryProvider();
      final children = await _storage.list(widget.parent);
      final name = editedCopyName(
        widget.entry.name,
        videoCopyExtension,
        children.map((value) => value.name),
      );
      outputPath = '${directory.path}/$name';
      final rendered = await widget.renderer.render(
        request,
        outputPath: outputPath,
      );
      final imported = await _storage.importDocuments([
        Uri.file(rendered).toString(),
      ], widget.parent);
      final saved = imported.isNotEmpty ? imported.first.name : name;
      await _cleanup(outputPath);
      if (!mounted) return;
      _closed = true;
      Navigator.of(context).pop(saved);
    } catch (failure) {
      await _cleanup(outputPath);
      if (!mounted) return;
      setState(() => _rendering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            previewErrorMessage(
              failure,
              fallback: context.l10n.videoEditorExportFailed,
            ),
          ),
        ),
      );
    }
  }

  void _onClose() {
    if (_closed) return;
    _closed = true;
    _cleanup(_filePath);
    Navigator.of(context).pop();
  }

  /// 同步删除缓存文件，避免异步 I/O 影响页面时序。
  Future<void> _cleanup(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // 缓存清理失败不影响主流程，系统可后续回收。
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: PreviewErrorView(
          entry: widget.entry,
          message: error,
          onRetry: _prepare,
        ),
      );
    }
    final path = _filePath;
    if (path == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Stack(
        children: [
          widget.editorBuilder(
            VideoEditorHostConfig(
              filePath: path,
              pickClip: _storage.pickVideoToCache,
              onExport: _onExport,
              onClose: _onClose,
              onError: (message) => setState(() => _error = message),
            ),
          ),
          if (_rendering)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.videoEditorExporting,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
