import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../i18n/app_l10n.dart';

/// EPUB 章节：标题与原始 XHTML。
class EpubChapter {
  const EpubChapter({required this.title, required this.html});

  final String title;
  final String html;
}

/// 解析后的 EPUB 书籍。
class EpubBook {
  const EpubBook({required this.title, required this.chapters});

  final String title;
  final List<EpubChapter> chapters;
}

/// EPUB 解析失败；调用方转换为可展示文案。
class EpubReadException implements Exception {
  const EpubReadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 解析 EPUB 字节为按 spine 顺序排列的章节。
///
/// 仅解析 container/OPF/spine 与 XHTML 章节文本；目录与图片资源不在本层
/// 处理，章节标题优先取 `<title>` 或首个标题标签，否则按序号命名。
EpubBook readEpub(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw EpubReadException(AppL10n.current.epubInvalid);
  }
  final containerFile = archive.find('META-INF/container.xml');
  if (containerFile == null) {
    throw EpubReadException(AppL10n.current.epubMissingContainer);
  }
  final container = _parseXml(containerFile.content);
  final opfPath = _elementsByLocalName(
    container,
    'rootfile',
  ).firstOrNull?.getAttribute('full-path');
  if (opfPath == null) throw EpubReadException(AppL10n.current.epubMissingOpf);

  final opfFile = archive.find(opfPath);
  if (opfFile == null) {
    throw EpubReadException(AppL10n.current.epubUnreadableManifest);
  }
  final opf = _parseXml(opfFile.content);

  final hrefs = <String, String>{};
  final mediaTypes = <String, String>{};
  for (final item in _elementsByLocalName(opf, 'item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null) continue;
    hrefs[id] = href;
    mediaTypes[id] = item.getAttribute('media-type') ?? '';
  }

  final baseDirectory = _directoryOf(opfPath);
  final spinePaths = <String>[];
  for (final itemref in _elementsByLocalName(opf, 'itemref')) {
    final idref = itemref.getAttribute('idref');
    if (idref == null) continue;
    final href = hrefs[idref];
    if (href == null) continue;
    final media = mediaTypes[idref] ?? '';
    if (media.contains('html') ||
        href.toLowerCase().endsWith('.xhtml') ||
        href.toLowerCase().endsWith('.html')) {
      spinePaths.add(_resolvePath(baseDirectory, href));
    }
  }
  if (spinePaths.isEmpty) throw EpubReadException(AppL10n.current.epubNoSpine);

  final chapters = <EpubChapter>[];
  for (var index = 0; index < spinePaths.length; index++) {
    final file = archive.find(spinePaths[index]);
    if (file == null) continue;
    final html = utf8.decode(file.content, allowMalformed: true);
    chapters.add(
      EpubChapter(title: _chapterTitle(html, index + 1), html: html),
    );
  }
  if (chapters.isEmpty) {
    throw EpubReadException(AppL10n.current.epubEmptyChapters);
  }

  final title = _elementsByLocalName(
    opf,
    'title',
  ).firstOrNull?.innerText.trim();
  return EpubBook(
    title: title == null || title.isEmpty
        ? AppL10n.current.epubUntitled
        : title,
    chapters: chapters,
  );
}

/// 按本地名匹配元素；OPF 元数据可能带 `dc:` 前缀，需忽略命名空间。
Iterable<XmlElement> _elementsByLocalName(XmlNode node, String localName) =>
    node.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == localName,
    );

XmlDocument _parseXml(List<int> bytes) {
  try {
    return XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
  } catch (_) {
    throw EpubReadException(AppL10n.current.epubInvalidManifest);
  }
}

String _directoryOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? '' : path.substring(0, slash);
}

/// 以 OPF 所在目录为基准解析相对路径，并归一化 `..` 段。
String _resolvePath(String base, String href) {
  final raw = href.startsWith('/')
      ? href.substring(1)
      : (base.isEmpty ? href : '$base/$href');
  final segments = <String>[];
  for (final part in raw.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.join('/');
}

/// 章节标题：优先 `<title>`，其次首个 `<h1>`-`<h3>`，最后按序号命名。
String _chapterTitle(String html, int index) {
  final title = RegExp(
    r'<title[^>]*>(.*?)</title>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html)?.group(1);
  if (title != null && title.trim().isNotEmpty) return title.trim();
  final heading = RegExp(
    r'<h[1-3][^>]*>(.*?)</h[1-3]>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html)?.group(1);
  if (heading != null) {
    final text = heading.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    if (text.isNotEmpty) return text;
  }
  return AppL10n.current.epubChapterTitle(index);
}
