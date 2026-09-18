import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

import '../models/storage_entry.dart';
import '../services/saf_storage.dart';
import 'preview_limits.dart';

/// 已解码的文本内容及其来源编码。
class TextContent {
  const TextContent({
    required this.text,
    required this.encoding,
    required this.truncated,
    this.hasBom = false,
    this.lineEnding = '\n',
  });

  final String text;

  /// 实际采用的编码名称，用于状态栏提示（例如 `UTF-8`、`GBK`）。
  final String encoding;

  /// 是否因超过读取上限被截断。
  final bool truncated;

  /// 原文件是否带字节序标记；保存时原样保留。
  final bool hasBom;

  /// 原文换行风格：`\n` 或 `\r\n`；保存时还原。
  final String lineEnding;
}

/// 读取条目文本并按编码解码；超出上限时截断并标记。
Future<TextContent> loadTextContent(
  StorageGateway storage,
  StorageEntry entry, {
  int maxBytes = textReadLimit,
}) async {
  final result = await storage.readDocumentLimited(entry, maxBytes: maxBytes);
  final decoded = await decodeTextBytes(
    result.bytes,
    truncated: result.truncated,
  );
  return TextContent(
    text: decoded.text,
    encoding: decoded.encoding,
    truncated: result.truncated,
    hasBom: decoded.hasBom,
    lineEnding: detectLineEnding(decoded.text),
  );
}

/// 推断文本换行风格：出现 `\r\n` 即按 CRLF 处理，否则 LF。
String detectLineEnding(String text) => text.contains('\r\n') ? '\r\n' : '\n';

/// 文本编码失败；调用方提示原因并保留编辑内容，不落盘。
class TextEncodeException implements Exception {
  const TextEncodeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 按原编码、BOM 与换行风格把文本编码回字节，用于覆盖保存。
///
/// UTF-16 手写编码并补 BOM；GBK 依赖平台能力，不可用时抛出
/// [TextEncodeException]；Latin-1 遇到越界字符同样抛出，避免静默损坏。
Future<Uint8List> encodeTextBytes(
  String text, {
  required String encoding,
  bool hasBom = false,
  String lineEnding = '\n',
}) async {
  final normalized = _normalizeLineEnding(text, lineEnding);
  switch (encoding) {
    case 'UTF-16LE':
      return _encodeUtf16(normalized, littleEndian: true, bom: hasBom);
    case 'UTF-16BE':
      return _encodeUtf16(normalized, littleEndian: false, bom: hasBom);
    case 'GBK':
      try {
        return Uint8List.fromList(
          await CharsetConverter.encode('GBK', normalized),
        );
      } catch (_) {
        throw const TextEncodeException('无法按 GBK 编码保存，请使用其他应用编辑');
      }
    case 'Latin-1':
      try {
        return Uint8List.fromList(latin1.encode(normalized));
      } on ArgumentError {
        throw const TextEncodeException('内容含无法以 Latin-1 保存的字符');
      }
    default:
      final bytes = utf8.encode(normalized);
      if (!hasBom) return Uint8List.fromList(bytes);
      return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...bytes]);
  }
}

/// 归一化换行后按 [lineEnding] 还原。
String _normalizeLineEnding(String text, String lineEnding) {
  final unified = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (lineEnding == '\n') return unified;
  return unified.replaceAll('\n', lineEnding);
}

/// 按 UTF-16 代码单元编码；Dart 标准库未提供 UTF-16 编码器。
Uint8List _encodeUtf16(
  String text, {
  required bool littleEndian,
  required bool bom,
}) {
  final bytes = <int>[];
  if (bom) {
    bytes.addAll(littleEndian ? const [0xFF, 0xFE] : const [0xFE, 0xFF]);
  }
  for (final unit in text.codeUnits) {
    if (littleEndian) {
      bytes
        ..add(unit & 0xFF)
        ..add((unit >> 8) & 0xFF);
    } else {
      bytes
        ..add((unit >> 8) & 0xFF)
        ..add(unit & 0xFF);
    }
  }
  return Uint8List.fromList(bytes);
}

/// 文本解码结果；不包含截断状态（由调用方持有）。
class DecodedText {
  const DecodedText(this.text, this.encoding, {this.hasBom = false});

  final String text;
  final String encoding;

  /// 原字节是否带 BOM。
  final bool hasBom;
}

/// 按 BOM → 严格 UTF-8 → GBK → Latin-1 的顺序解码。
///
/// GBK 依赖平台能力，在测试或无插件环境下会回退 Latin-1，保证不抛异常；
/// [truncated] 为真时允许 UTF-8 尾部存在被截断的不完整序列，但仍要求
/// 替换字符占比极低，避免把 GBK 内容误判成 UTF-8。
Future<DecodedText> decodeTextBytes(
  Uint8List bytes, {
  bool truncated = false,
}) async {
  final withBom = _decodeWithBom(bytes);
  if (withBom != null) return withBom;

  final utf8Text = _decodeUtf8(bytes, truncated: truncated);
  if (utf8Text != null) return DecodedText(utf8Text, 'UTF-8');

  try {
    final text = await CharsetConverter.decode('GBK', bytes);
    return DecodedText(text, 'GBK');
  } catch (_) {
    // 平台不支持或字节不是 GBK：回退 Latin-1，逐字节映射不丢失内容。
    return DecodedText(latin1.decode(bytes, allowInvalid: true), 'Latin-1');
  }
}

/// 识别 UTF-8 / UTF-16 字节序标记并解码；无 BOM 返回 null。
DecodedText? _decodeWithBom(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return DecodedText(
      utf8.decode(bytes.sublist(3), allowMalformed: true),
      'UTF-8',
      hasBom: true,
    );
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return DecodedText(
      _decodeUtf16(bytes.sublist(2), littleEndian: true),
      'UTF-16LE',
      hasBom: true,
    );
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return DecodedText(
      _decodeUtf16(bytes.sublist(2), littleEndian: false),
      'UTF-16BE',
      hasBom: true,
    );
  }
  return null;
}

/// 严格 UTF-8 解码；[truncated] 时容忍尾部不完整的多字节序列。
///
/// 截断只可能发生在最后一个字符上（UTF-8 单字符最多 4 字节），因此
/// 依次尝试去掉尾部 1-4 字节，只要能严格解码即视为被截断的 UTF-8；
/// 中部存在非法字节时所有尝试都会失败，交由 GBK/Latin-1 处理。
String? _decodeUtf8(Uint8List bytes, {required bool truncated}) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    if (!truncated) return null;
  }
  for (var drop = 1; drop <= 4 && drop < bytes.length; drop++) {
    try {
      return utf8.decode(bytes.sublist(0, bytes.length - drop));
    } on FormatException {
      continue;
    }
  }
  return null;
}

/// 手动解码 UTF-16 代码单元；Dart 标准库未提供 UTF-16 解码器。
String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var index = 0; index + 1 < bytes.length; index += 2) {
    final first = bytes[index];
    final second = bytes[index + 1];
    units.add(littleEndian ? (second << 8) | first : (first << 8) | second);
  }
  return String.fromCharCodes(units);
}
