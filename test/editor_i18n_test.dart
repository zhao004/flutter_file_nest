import 'dart:ui' show Locale;

import 'package:filenest/app/preview/editor_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  test('中文编辑器文案关键字段', () {
    final i18n = editorI18nFor(const Locale('zh'));

    expect(i18n.cancel, '取消');
    expect(i18n.undo, '撤销');
    expect(i18n.redo, '重做');
    expect(i18n.done, '完成');
    expect(i18n.various.closeEditorWarningTitle, '退出编辑器？');
    expect(i18n.paintEditor.bottomNavigationBarText, '画笔');
    expect(i18n.paintEditor.eraser, '橡皮擦');
    expect(i18n.textEditor.inputHintText, '输入文字');
    expect(i18n.cropRotateEditor.bottomNavigationBarText, '裁剪旋转');
    expect(i18n.tuneEditor.brightness, '亮度');
    expect(i18n.filterEditor.bottomNavigationBarText, '滤镜');
    expect(i18n.blurEditor.bottomNavigationBarText, '模糊');
    expect(i18n.emojiEditor.categoryRecent, '最近使用');
    expect(i18n.stickerEditor.bottomNavigationBarText, '贴纸');
    expect(i18n.clipsEditor.bottomNavigationBarText, '片段');
  });

  test('非中文回落英文默认值', () {
    final i18n = editorI18nFor(const Locale('en'));

    expect(i18n.done, 'Done');
    expect(i18n.paintEditor.bottomNavigationBarText, 'Paint');
    expect(i18n.clipsEditor.bottomNavigationBarText, 'Clips');
  });

  test('Emoji 数据集按语言选择', () {
    expect(editorEmojiSet(const Locale('zh')), same(emojiSetChinese));
    expect(editorEmojiSet(const Locale('en')), same(emojiSetEnglish));
  });
}
