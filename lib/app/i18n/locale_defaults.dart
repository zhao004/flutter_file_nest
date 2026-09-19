import 'package:flutter/widgets.dart';

/// 语言偏好的持久化名称；system 表示跟随系统语言。
const String kDefaultLocaleName = 'system';
const String kLocaleSystemName = 'system';
const String kLocaleChineseName = 'zh';
const String kLocaleEnglishName = 'en';

/// 设置页可选的语言偏好，顺序与展示顺序一致。
const List<String> kSelectableLocaleNames = [
  kLocaleSystemName,
  kLocaleChineseName,
  kLocaleEnglishName,
];

/// 语言偏好名称转换为 MaterialApp 的 [Locale]；system 返回 null（跟随系统）。
Locale? localeForName(String name) =>
    name == kLocaleSystemName ? null : Locale(name);
