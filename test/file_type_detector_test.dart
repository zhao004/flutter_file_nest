import 'package:flutter_lens_vault/app/file_type/file_category.dart';
import 'package:flutter_lens_vault/app/file_type/file_type_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FileCategory detect(String name, {String? mime, bool directory = false}) =>
      detectFileCategory(name: name, mimeType: mime, isDirectory: directory);

  test('目录始终归为文件夹，忽略扩展名与 MIME', () {
    expect(detect('相册', directory: true), FileCategory.folder);
    expect(
      detect('photo.jpg', mime: 'image/jpeg', directory: true),
      FileCategory.folder,
    );
  });

  test('扩展名大小写不敏感并支持复合扩展名', () {
    expect(detect('PHOTO.JPG'), FileCategory.image);
    expect(detect('backup.tar.gz'), FileCategory.archive);
    expect(detect('backup.tar.bz2'), FileCategory.archive);
    expect(detect('logs.tar.xz'), FileCategory.archive);
    expect(detect('bundle.txz'), FileCategory.archive);
  });

  test('无扩展名时依赖 MIME 判定', () {
    expect(detect('clip', mime: 'video/mp4'), FileCategory.video);
    expect(detect('track', mime: 'audio/mpeg'), FileCategory.audio);
    expect(detect('scan', mime: 'application/pdf'), FileCategory.pdf);
  });

  test('泛化 MIME 让位给扩展名', () {
    expect(
      detect('photo.png', mime: 'application/octet-stream'),
      FileCategory.image,
    );
    expect(
      detect('未知.xxx', mime: 'application/octet-stream'),
      FileCategory.unknown,
    );
  });

  test('泛化文本 MIME 不覆盖更具体的扩展名', () {
    expect(detect('main.dart', mime: 'text/plain'), FileCategory.code);
    expect(detect('manifest.json', mime: 'text/plain'), FileCategory.code);
    expect(detect('notes.txt', mime: 'text/plain'), FileCategory.text);
  });

  test('具体 MIME 优先于扩展名', () {
    expect(detect('data.csv', mime: 'text/csv'), FileCategory.spreadsheet);
    expect(
      detect(
        'report',
        mime:
            'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document',
      ),
      FileCategory.document,
    );
    expect(
      detect(
        'sheet',
        mime:
            'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet',
      ),
      FileCategory.spreadsheet,
    );
    expect(
      detect(
        'deck',
        mime:
            'application/vnd.openxmlformats-officedocument'
            '.presentationml.presentation',
      ),
      FileCategory.presentation,
    );
    expect(detect('bundle', mime: 'application/zip'), FileCategory.archive);
    expect(
      detect('app', mime: 'application/vnd.android.package-archive'),
      FileCategory.apk,
    );
  });

  test('常见扩展名归属正确', () {
    expect(detect('clip.ts'), FileCategory.video);
    expect(detect('page.tsx'), FileCategory.code);
    expect(detect('bundle.apks'), FileCategory.apk);
    expect(detect('bundle.xapk'), FileCategory.apk);
    expect(detect('query.sql'), FileCategory.database);
    expect(detect('store.db'), FileCategory.database);
    expect(detect('logo.svg'), FileCategory.image);
    expect(detect('book.epub'), FileCategory.ebook);
    expect(detect('movie.srt'), FileCategory.subtitle);
    expect(detect('font.ttf'), FileCategory.font);
    expect(detect('deck.pptx'), FileCategory.presentation);
    expect(detect('sheet.xlsx'), FileCategory.spreadsheet);
    expect(detect('report.docx'), FileCategory.document);
    expect(detect('archive.7z'), FileCategory.archive);
  });

  test('多点文件名只取最后一段扩展名', () {
    expect(detect('my.file.txt'), FileCategory.text);
    expect(detect('archive.tar.gz'), FileCategory.archive);
  });

  test('未知扩展名与缺失 MIME 归为未知', () {
    expect(detect('mystery.xxx'), FileCategory.unknown);
    expect(detect('无扩展名'), FileCategory.unknown);
    expect(detect('无扩展名', mime: '*/*'), FileCategory.unknown);
  });
}
