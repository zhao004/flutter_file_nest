import 'package:flutter_lens_vault/app/preview/preview_launcher.dart';
import 'package:flutter_lens_vault/app/preview/preview_limits.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  test('可写的文本与代码文件直接进入编辑器', () {
    expect(prefersTextEditor(entry('notes.txt')), isTrue);
    expect(prefersTextEditor(entry('main.dart')), isTrue);
    expect(prefersTextEditor(entry('index.html')), isTrue);
  });

  test('非文本类型不进入编辑器', () {
    expect(prefersTextEditor(entry('photo.jpg')), isFalse);
    expect(prefersTextEditor(entry('README.md')), isFalse);
    expect(prefersTextEditor(entry('data.csv')), isFalse);
  });

  test('不可写或超过读取上限的文本回退预览', () {
    expect(prefersTextEditor(entry('notes.txt', canWrite: false)), isFalse);
    expect(
      prefersTextEditor(entry('big.txt', size: textReadLimit + 1)),
      isFalse,
    );
    expect(prefersTextEditor(entry('small.txt', size: textReadLimit)), isTrue);
  });
}
