import 'package:filenest/app/preview/video_editor_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

TrimDurationSpan span(int startMs, int endMs) => TrimDurationSpan(
  start: Duration(milliseconds: startMs),
  end: Duration(milliseconds: endMs),
);

void main() {
  test('左手柄拖动定位到裁剪起点', () {
    expect(
      trimPreviewSeekTarget(span(0, 5000), span(1200, 5000)),
      const Duration(milliseconds: 1200),
    );
  });

  test('右手柄拖动定位到裁剪终点', () {
    expect(
      trimPreviewSeekTarget(span(0, 5000), span(0, 3200)),
      const Duration(milliseconds: 3200),
    );
  });

  test('整体平移定位到新的裁剪起点', () {
    expect(
      trimPreviewSeekTarget(span(0, 5000), span(800, 5800)),
      const Duration(milliseconds: 800),
    );
  });

  test('范围未变化或首次设置不跳转', () {
    expect(trimPreviewSeekTarget(span(0, 5000), span(0, 5000)), isNull);
    expect(trimPreviewSeekTarget(null, span(0, 5000)), isNull);
  });
}
