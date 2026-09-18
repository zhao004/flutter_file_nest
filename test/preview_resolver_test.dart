import 'package:flutter_lens_vault/app/file_type/file_extension_map.dart';
import 'package:flutter_lens_vault/app/preview/preview_kind.dart';
import 'package:flutter_lens_vault/app/preview/preview_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  PreviewKind resolve(String name, {String? mime, bool directory = false}) =>
      resolvePreviewKind(entry(name, directory: directory, mime: mime));

  test('fileExtension 返回最后一段小写扩展名', () {
    expect(fileExtension('PHOTO.JPG'), 'jpg');
    expect(fileExtension('archive.tar.gz'), 'gz');
    expect(fileExtension('noext'), '');
    expect(fileExtension('trailing.'), '');
    expect(fileExtension('my.file.txt'), 'txt');
  });

  test('图片与 SVG 都由图片查看器处理', () {
    expect(resolve('photo.jpg'), PreviewKind.image);
    expect(resolve('scan.heic', mime: 'image/heic'), PreviewKind.image);
    expect(resolve('logo.svg'), PreviewKind.image);
  });

  test('视频与音频各自解析', () {
    expect(resolve('clip.mp4'), PreviewKind.video);
    expect(resolve('noext', mime: 'video/mp4'), PreviewKind.video);
    expect(resolve('song.mp3'), PreviewKind.audio);
    expect(resolve('voice', mime: 'audio/mpeg'), PreviewKind.audio);
  });

  test('PDF 与文本类按扩展名细分', () {
    expect(resolve('report.pdf'), PreviewKind.pdf);
    expect(resolve('app.log'), PreviewKind.text);
    expect(resolve('notes.txt'), PreviewKind.text);
    expect(resolve('README.md'), PreviewKind.markdown);
    expect(resolve('guide.markdown'), PreviewKind.markdown);
    expect(resolve('main.dart'), PreviewKind.code);
    expect(resolve('config.yaml'), PreviewKind.code);
    expect(resolve('data.csv', mime: 'text/csv'), PreviewKind.csv);
  });

  test('Office 与不支持的表格交给系统打开', () {
    expect(resolve('sheet.xlsx'), PreviewKind.external);
    expect(resolve('report.docx'), PreviewKind.external);
    expect(resolve('deck.pptx'), PreviewKind.external);
  });

  test('归档仅 ZIP/TAR 系列可应用内浏览', () {
    expect(resolve('backup.zip'), PreviewKind.archive);
    expect(resolve('backup.tar.gz'), PreviewKind.archive);
    expect(resolve('logs.tar.xz'), PreviewKind.archive);
    expect(resolve('bundle.tgz'), PreviewKind.archive);
    expect(resolve('archive.7z'), PreviewKind.external);
    expect(resolve('archive.rar'), PreviewKind.external);
  });

  test('电子书仅 EPUB 应用内预览', () {
    expect(resolve('book.epub'), PreviewKind.ebook);
    expect(resolve('book.mobi'), PreviewKind.external);
    expect(resolve('book.azw3'), PreviewKind.external);
  });

  test('字体仅 TTF/OTF 可加载', () {
    expect(resolve('Roboto.ttf'), PreviewKind.font);
    expect(resolve('Roboto.otf'), PreviewKind.font);
    expect(resolve('Roboto.ttc'), PreviewKind.external);
    expect(resolve('Roboto.woff2'), PreviewKind.external);
  });

  test('字幕使用字幕查看器', () {
    expect(resolve('movie.srt'), PreviewKind.subtitle);
    expect(resolve('movie.ass'), PreviewKind.subtitle);
    expect(resolve('movie.vtt'), PreviewKind.subtitle);
  });

  test('未知与不可预览类型进入信息页', () {
    expect(resolve('app.apk'), PreviewKind.unsupported);
    expect(resolve('store.db'), PreviewKind.unsupported);
    expect(resolve('mystery.xxx'), PreviewKind.unsupported);
    expect(resolve('无扩展名'), PreviewKind.unsupported);
    expect(resolve('相册', directory: true), PreviewKind.unsupported);
  });

  test('shouldOpenExternally 只对 external 返回 true', () {
    expect(shouldOpenExternally(entry('report.docx')), isTrue);
    expect(shouldOpenExternally(entry('archive.rar')), isTrue);
    expect(shouldOpenExternally(entry('app.apk')), isFalse);
    expect(shouldOpenExternally(entry('photo.jpg')), isFalse);
  });
}
