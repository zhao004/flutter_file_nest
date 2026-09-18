import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_lens_vault/app/preview/epub_reader.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _epubBytes() {
  const container =
      '<?xml version="1.0"?>'
      '<container version="1.0" '
      'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
      '<rootfiles><rootfile full-path="OEBPS/content.opf" '
      'media-type="application/oebps-package+xml"/></rootfiles>'
      '</container>';
  const opf =
      '<?xml version="1.0"?>'
      '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
      '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
      '<dc:title>示例书</dc:title></metadata>'
      '<manifest>'
      '<item id="c1" href="ch1.xhtml" media-type="application/xhtml+xml"/>'
      '<item id="c2" href="sub/ch2.xhtml" media-type="application/xhtml+xml"/>'
      '</manifest>'
      '<spine><itemref idref="c1"/><itemref idref="c2"/></spine>'
      '</package>';
  const chapter1 =
      '<html><head><title>第一章</title></head><body><p>Hello</p></body></html>';
  const chapter2 =
      '<html><head></head><body><h1>第二章</h1><p>World</p></body></html>';

  final archive = Archive()
    ..addFile(ArchiveFile('mimetype', 20, utf8.encode('application/epub+zip')))
    ..addFile(
      ArchiveFile(
        'META-INF/container.xml',
        container.length,
        utf8.encode(container),
      ),
    )
    ..addFile(ArchiveFile('OEBPS/content.opf', opf.length, utf8.encode(opf)))
    ..addFile(
      ArchiveFile('OEBPS/ch1.xhtml', chapter1.length, utf8.encode(chapter1)),
    )
    ..addFile(
      ArchiveFile(
        'OEBPS/sub/ch2.xhtml',
        chapter2.length,
        utf8.encode(chapter2),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('解析 EPUB 标题与 spine 章节', () {
    final book = readEpub(_epubBytes());
    expect(book.title, '示例书');
    expect(book.chapters.length, 2);
    expect(book.chapters[0].title, '第一章');
    expect(book.chapters[0].html, contains('Hello'));
    // 无 title 时取首个标题标签。
    expect(book.chapters[1].title, '第二章');
  });

  test('非 ZIP 内容抛出结构化异常', () {
    expect(
      () => readEpub(Uint8List.fromList(const [1, 2, 3])),
      throwsA(isA<EpubReadException>()),
    );
  });
}
