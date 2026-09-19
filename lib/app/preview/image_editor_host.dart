import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../localization.dart';
import 'editor_i18n.dart';
import 'media_editor_format.dart';

/// 图片编辑器宿主配置：只暴露页面逻辑所需的输入与回调，
/// 便于测试注入假实现而不依赖第三方重型组件。
class ImageEditorHostConfig {
  const ImageEditorHostConfig({
    required this.filePath,
    required this.sourceName,
    required this.pickSticker,
    required this.onComplete,
    required this.onClose,
  });

  /// 原图缓存路径；由页面经 SAF 导出后传入，编辑器按文件读取以避免
  /// 大字节经平台通道拷贝。
  final String filePath;

  /// 原文件名；用于推断输出编码格式。
  final String sourceName;

  /// 贴纸来源：返回图片字节，取消返回 null。
  final Future<Uint8List?> Function() pickSticker;

  /// 编辑完成回调；参数为合成后的图片字节。
  final ValueChanged<Uint8List> onComplete;

  /// 用户关闭编辑器（未保存）。
  final VoidCallback onClose;
}

/// 图片编辑器构建器；测试可替换为假实现。
typedef ImageEditorBuilder = Widget Function(ImageEditorHostConfig config);

/// 默认宿主：pro_image_editor 的全屏编辑器。
Widget buildProImageEditor(ImageEditorHostConfig config) =>
    _ProImageEditorHost(config: config);

class _ProImageEditorHost extends StatelessWidget {
  const _ProImageEditorHost({required this.config});

  final ImageEditorHostConfig config;

  @override
  Widget build(BuildContext context) => ProImageEditor.file(
    config.filePath,
    configs: ProImageEditorConfigs(
      i18n: editorI18nFor(editorLocale()),
      emojiEditor: EmojiEditorConfigs(emojiSet: editorEmojiSet),
      imageGeneration: ImageGenerationConfigs(
        outputFormat: imageOutputFormatForName(config.sourceName),
        jpegQuality: 95,
      ),
      mainEditor: const MainEditorConfigs(
        tools: [
          SubEditorMode.paint,
          SubEditorMode.text,
          SubEditorMode.cropRotate,
          SubEditorMode.tune,
          SubEditorMode.filter,
          SubEditorMode.blur,
          SubEditorMode.emoji,
          SubEditorMode.sticker,
        ],
      ),
      stickerEditor: StickerEditorConfigs(builder: _buildStickers),
    ),
    callbacks: ProImageEditorCallbacks(
      onImageEditingComplete: (bytes) async => config.onComplete(bytes),
      onCloseEditor: (mode) => config.onClose(),
    ),
  );

  Widget _buildStickers(
    void Function(WidgetLayer widget) setLayer,
    ScrollController scrollController,
  ) => _DeviceStickerPicker(
    scrollController: scrollController,
    pickSticker: config.pickSticker,
    setLayer: setLayer,
  );
}

/// 贴纸选择面板：仅提供“从设备选择”，把所选图片作为贴纸图层加入。
class _DeviceStickerPicker extends StatelessWidget {
  const _DeviceStickerPicker({
    required this.scrollController,
    required this.pickSticker,
    required this.setLayer,
  });

  final ScrollController scrollController;
  final Future<Uint8List?> Function() pickSticker;
  final void Function(WidgetLayer widget) setLayer;

  Future<void> _pick(BuildContext context) async {
    final bytes = await pickSticker();
    if (!context.mounted || bytes == null || bytes.isEmpty) return;
    // 贴纸在后台隔离线程截屏，须先确保图片已完全加载。
    await precacheImage(MemoryImage(bytes), context);
    if (!context.mounted) return;
    setLayer(WidgetLayer(widget: Image.memory(bytes)));
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    child: GridView.count(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      crossAxisCount: 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_photo_alternate_outlined, size: 28),
              const SizedBox(height: 6),
              Text(
                context.l10n.imageEditorPickFromDevice,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
