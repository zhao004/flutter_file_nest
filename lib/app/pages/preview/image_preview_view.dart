import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../di/injector.dart';

import '../../file_type/file_type_info.dart';
import '../../localization.dart';
import '../../models/storage_entry.dart';
import '../../preview/image_decode.dart';
import '../../services/archive_service.dart';
import '../../services/saf_storage.dart';
import 'preview_app_bar.dart';

/// 应用内图片预览：经内容 URI 读取字节，支持缩放、双击与拖动查看。
///
/// SVG 交由 `flutter_svg` 渲染；位图沿用 Flutter 解码器，不支持的格式
/// （如部分 HEIC）展示错误并提供“用其他应用打开”。
class ImagePreviewView extends StatefulWidget {
  const ImagePreviewView({required this.entry, super.key});
  final StorageEntry entry;
  @override
  State<ImagePreviewView> createState() => _ImagePreviewViewState();
}

class _ImagePreviewViewState extends State<ImagePreviewView> {
  late final StorageGateway _storage = getIt<StorageGateway>();
  late final Future<Uint8List?> _future = _storage.readDocument(widget.entry);
  final _controller = TransformationController();

  /// 是否已切换为原图解码；放大超过 [previewDecodeFactor] 时置位。
  bool _fullResolution = false;

  bool get _isSvg => widget.entry.name.toLowerCase().endsWith('.svg');

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTransformChanged);
  }

  /// 放大超过降采样倍率后改用原图解码，避免细节模糊；只升不降。
  void _handleTransformChanged() {
    if (_fullResolution) return;
    if (_controller.value.getMaxScaleOnAxis() > previewDecodeFactor) {
      setState(() => _fullResolution = true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  /// 以视口中心为基准缩放到 [scale]；1.0 表示适配窗口。
  void _zoomTo(double scale) {
    final size = context.size;
    final center = size == null
        ? Offset.zero
        : Offset(size.width / 2, size.height / 2);
    _controller.value = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  /// 双击在“适配”与 2 倍之间切换。
  void _handleDoubleTap() {
    final scale = _controller.value.getMaxScaleOnAxis();
    _zoomTo(scale > 1.01 ? 1.0 : 2.0);
  }

  Future<void> _showInfo() async {
    final entry = widget.entry;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.imageInfo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(dialogContext, dialogContext.l10n.commonName, entry.name),
            _infoRow(
              dialogContext,
              dialogContext.l10n.commonType,
              fileCategoryLabel(entry.fileCategory, dialogContext.l10n),
            ),
            _infoRow(
              dialogContext,
              dialogContext.l10n.commonSize,
              formatBytes(entry.size, dialogContext.l10n),
            ),
            _infoRow(
              dialogContext,
              dialogContext.l10n.commonModifiedTime,
              entry.modifiedAt == null
                  ? dialogContext.l10n.commonUnknown
                  : _formatTime(entry.modifiedAt!),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        Expanded(child: SelectableText(value)),
      ],
    ),
  );

  Future<void> _share() async {
    if (!getIt.isRegistered<ArchiveGateway>()) return;
    await getIt<ArchiveGateway>().share([widget.entry]);
  }

  /// 位图解码器：默认按视口上限降采样，放大后改用原图。
  ImageProvider _bitmapProvider(Uint8List bytes) {
    final provider = MemoryImage(bytes);
    if (_fullResolution) return provider;
    return boundedImageProvider(provider, bounds: decodeBoundsOf(context));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      // 沉浸式黑底查看器需显式指定图标色：主题的 AppBar 图标色会覆盖
      // foregroundColor，浅色模式下为深色，在黑底上不可见。
      iconTheme: immersivePreviewIconTheme,
      actionsIconTheme: immersivePreviewIconTheme,
      title: Text(
        widget.entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: context.l10n.imageInfo,
          onPressed: _showInfo,
          icon: const Icon(Icons.info_outline),
        ),
        if (getIt.isRegistered<ArchiveGateway>())
          IconButton(
            tooltip: context.l10n.commonShare,
            onPressed: _share,
            icon: const Icon(Icons.ios_share),
          ),
        IconButton(
          tooltip: context.l10n.commonOpenExternal,
          onPressed: () => _storage.openFile(widget.entry),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (bytes == null) return _errorBody(context);
          return GestureDetector(
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.5,
              maxScale: 8,
              child: Center(
                child: _isSvg
                    ? SvgPicture.memory(
                        bytes,
                        fit: BoxFit.contain,
                        placeholderBuilder: (_) =>
                            const CircularProgressIndicator(),
                        errorBuilder: (context, error, stack) =>
                            _errorBody(context),
                      )
                    : Image(
                        image: _bitmapProvider(bytes),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stack) =>
                            _errorBody(context),
                      ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _errorBody(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          Text(context.l10n.imageUnsupported, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _storage.openFile(widget.entry),
            icon: const Icon(Icons.open_in_new),
            label: Text(context.l10n.commonOpenExternal),
          ),
        ],
      ),
    ),
  );
}

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
