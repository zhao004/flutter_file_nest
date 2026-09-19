import '../i18n/app_l10n.dart';

/// 来自其他应用（微信/QQ 等）的待保存文件；uri 为不透明的内容标识。
class IncomingShare {
  const IncomingShare({required this.uri, this.name, this.size});

  factory IncomingShare.fromMap(Map<Object?, Object?> map) => IncomingShare(
    uri: map['uri'] as String,
    name: map['name'] as String?,
    size: (map['size'] as num?)?.toInt(),
  );

  final String uri;
  final String? name;
  final int? size;

  /// 展示用名称；提供方未给出名称时回退为通用文案。
  String get displayName {
    final value = name;
    return (value == null || value.isEmpty)
        ? AppL10n.current.incomingShareFallbackName
        : value;
  }
}
