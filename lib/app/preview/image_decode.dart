import 'package:material_ui/material_ui.dart';

/// 预览解码冗余倍率：按视口物理像素的该倍数解码，放大不超过它时保持清晰。
const double previewDecodeFactor = 2;

/// 弹窗等小尺寸预览的解码上限（物理像素）。
const Size dialogDecodeBounds = Size(1600, 1600);

/// 单边解码上限，防御异常视口值导致的超大解码。
const int maxDecodeExtent = 16384;

/// 由逻辑视口与像素密度计算解码上限；[factor] 为冗余倍率。
Size decodeBounds(
  Size viewport,
  double devicePixelRatio, {
  double factor = previewDecodeFactor,
}) => Size(
  viewport.width * devicePixelRatio * factor,
  viewport.height * devicePixelRatio * factor,
);

/// 当前屏幕的解码上限；用于全屏预览。
Size decodeBoundsOf(BuildContext context) {
  final media = MediaQuery.of(context);
  return decodeBounds(media.size, media.devicePixelRatio);
}

/// 把图片解码约束在 [bounds] 内，避免大图按原分辨率解码。
///
/// 使用 `fit` 策略等比缩放，且不放大小图（`allowUpscaling` 默认 false）。
ImageProvider boundedImageProvider(
  ImageProvider provider, {
  required Size bounds,
}) => ResizeImage(
  provider,
  width: _extent(bounds.width),
  height: _extent(bounds.height),
  policy: ResizeImagePolicy.fit,
);

int _extent(double value) => value.round().clamp(1, maxDecodeExtent).toInt();
