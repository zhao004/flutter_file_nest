import 'dart:typed_data';

import 'package:filenest/app/preview/image_decode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('解码上限按视口物理像素与倍率计算', () {
    expect(decodeBounds(const Size(360, 800), 3), const Size(2160, 4800));
    expect(
      decodeBounds(const Size(360, 800), 3, factor: 1),
      const Size(1080, 2400),
    );
  });

  test('约束 provider 使用 fit 策略且只缩不放', () {
    final provider = boundedImageProvider(
      MemoryImage(Uint8List.fromList(const [1, 2, 3])),
      bounds: const Size(1600.4, 900.6),
    );

    expect(provider, isA<ResizeImage>());
    final resize = provider as ResizeImage;
    expect(resize.width, 1600);
    expect(resize.height, 901);
    expect(resize.policy, ResizeImagePolicy.fit);
    expect(resize.allowUpscaling, isFalse);
  });

  test('异常解码尺寸被限制在合法范围内', () {
    final resize = boundedImageProvider(
      MemoryImage(Uint8List.fromList(const [1])),
      bounds: const Size(0, 1e9),
    ) as ResizeImage;
    expect(resize.width, 1);
    expect(resize.height, maxDecodeExtent);
  });
}
