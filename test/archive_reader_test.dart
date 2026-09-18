import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_lens_vault/app/preview/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zipBytes() {
  final archive = Archive();
  final content = utf8.encode('hello');
  archive
    ..addFile(ArchiveFile.directory('docs/'))
    ..addFile(ArchiveFile('docs/readme.txt', content.length, content));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('列出 ZIP 条目并读取单个文件内容', () {
    final contents = readArchive(
      _zipBytes(),
      extension: 'zip',
      archiveName: 'backup.zip',
    );
    final paths = contents.entries.map((entry) => entry.path).toList();
    expect(paths, containsAll(['docs/', 'docs/readme.txt']));
    expect(
      contents.entries
          .firstWhere((entry) => entry.path.contains('readme'))
          .size,
      5,
    );
    expect(utf8.decode(contents.readEntry('docs/readme.txt')), 'hello');
  });

  test('读取目录条目抛出结构化异常', () {
    final contents = readArchive(
      _zipBytes(),
      extension: 'zip',
      archiveName: 'backup.zip',
    );
    expect(
      () => contents.readEntry('docs/'),
      throwsA(isA<ArchiveReadException>()),
    );
  });

  test('单文件 GZ 解压为单条目', () {
    final packed = GZipEncoder().encode(utf8.encode('payload'));
    final contents = readArchive(
      Uint8List.fromList(packed),
      extension: 'gz',
      archiveName: 'note.txt.gz',
    );
    expect(contents.entries.single.path, 'note.txt');
    expect(utf8.decode(contents.readEntry('note.txt')), 'payload');
  });

  test('不支持的扩展名抛出异常', () {
    expect(
      () => readArchive(
        Uint8List.fromList(const [1, 2, 3]),
        extension: 'rar',
        archiveName: 'a.rar',
      ),
      throwsA(isA<ArchiveReadException>()),
    );
  });
}
