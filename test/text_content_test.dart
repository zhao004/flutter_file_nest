import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_lens_vault/app/preview/text_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('严格 UTF-8 与 UTF-8 BOM 解码', () async {
    final plain = await decodeTextBytes(
      Uint8List.fromList(utf8.encode('你好，LensVault')),
    );
    expect(plain.text, '你好，LensVault');
    expect(plain.encoding, 'UTF-8');

    final withBom = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('abc'),
    ]);
    final bom = await decodeTextBytes(withBom);
    expect(bom.text, 'abc');
    expect(bom.encoding, 'UTF-8');
  });

  test('UTF-16LE 与 UTF-16BE BOM 解码', () async {
    final little = Uint8List.fromList([0xFF, 0xFE, 0x48, 0x00, 0x69, 0x00]);
    final le = await decodeTextBytes(little);
    expect(le.text, 'Hi');
    expect(le.encoding, 'UTF-16LE');

    final big = Uint8List.fromList([0xFE, 0xFF, 0x00, 0x48, 0x00, 0x69]);
    final be = await decodeTextBytes(big);
    expect(be.text, 'Hi');
    expect(be.encoding, 'UTF-16BE');
  });

  test('非 UTF-8 且平台解码不可用时回退 Latin-1', () async {
    // 0xE4 0xF6 在 UTF-8 中非法；测试环境无 charset 平台通道，回退 Latin-1。
    final bytes = Uint8List.fromList([0xE4, 0xF6, 0x20, 0x41]);
    final decoded = await decodeTextBytes(bytes);
    expect(decoded.encoding, 'Latin-1');
  });

  test('截断的 UTF-8 尾部不完整序列被容忍', () async {
    final full = utf8.encode('中文内容');
    final truncated = Uint8List.fromList(full.sublist(0, full.length - 1));
    final decoded = await decodeTextBytes(truncated, truncated: true);
    expect(decoded.encoding, 'UTF-8');
    expect(decoded.text, '中文内');
  });

  test('未截断时非法 UTF-8 不按 UTF-8 处理', () async {
    final full = utf8.encode('中文内容');
    final truncated = Uint8List.fromList(full.sublist(0, full.length - 1));
    final decoded = await decodeTextBytes(truncated);
    expect(decoded.encoding, isNot('UTF-8'));
  });

  test('detectLineEnding 识别 CRLF', () {
    expect(detectLineEnding('a\nb'), '\n');
    expect(detectLineEnding('a\r\nb'), '\r\n');
  });

  test('按原换行风格回写 UTF-8', () async {
    final bytes = await encodeTextBytes(
      'a\r\nb\nc',
      encoding: 'UTF-8',
      lineEnding: '\r\n',
    );
    expect(utf8.decode(bytes), 'a\r\nb\r\nc');
  });

  test('UTF-8 BOM 往返', () async {
    final bytes = await encodeTextBytes('你好', encoding: 'UTF-8', hasBom: true);
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final decoded = await decodeTextBytes(bytes);
    expect(decoded.text, '你好');
    expect(decoded.hasBom, isTrue);
  });

  test('UTF-16LE 往返', () async {
    final bytes = await encodeTextBytes(
      'Hi',
      encoding: 'UTF-16LE',
      hasBom: true,
    );
    expect(bytes.sublist(0, 2), [0xFF, 0xFE]);
    final decoded = await decodeTextBytes(bytes);
    expect(decoded.text, 'Hi');
    expect(decoded.encoding, 'UTF-16LE');
    expect(decoded.hasBom, isTrue);
  });

  test('平台不支持时 GBK 编码抛出结构化异常', () async {
    await expectLater(
      encodeTextBytes('中文', encoding: 'GBK'),
      throwsA(isA<TextEncodeException>()),
    );
  });
}
