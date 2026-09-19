import 'package:signals_flutter/signals_flutter.dart';

import '../../preview/preview_defaults.dart';
import '../../services/vault_store.dart';

/// 预览与编辑器偏好：字号、自动换行、Markdown 模式与编辑器行为。
///
/// 偏好持久化到 [VaultStore]；保存失败只影响下次启动的默认值，不阻断
/// 当前展示。控制器在应用启动时注册为常驻实例并加载一次，预览页与编辑器
/// 只读取其响应式值。
class PreviewSettingsController {
  PreviewSettingsController(this._store);

  final VaultStore _store;

  /// 文本/代码预览与编辑器字号（逻辑像素）。
  final fontSize = signal(kDefaultTextFontSize);

  /// 文本/代码预览与编辑器是否自动换行。
  final wrap = signal(kDefaultTextWrap);

  /// Markdown 展示模式：read（阅读）或 source（源码）。
  final markdownMode = signal(kDefaultMarkdownMode);

  /// 代码预览与编辑器是否显示行号。
  final lineNumbers = signal(kDefaultShowLineNumbers);

  /// 编辑器 Tab 缩进宽度（空格数）。
  final tabWidth = signal(kDefaultEditorTabWidth);

  /// 编辑器是否启用自动缩进。
  final autoIndent = signal(kDefaultEditorAutoIndent);

  /// 从存储读取偏好；失败时保留当前值。
  Future<void> load() async {
    try {
      final preferences = await _store.loadPreferences();
      fontSize.value = preferences.textFontSize;
      wrap.value = preferences.textWrap;
      markdownMode.value = preferences.markdownMode;
      lineNumbers.value = preferences.showLineNumbers;
      tabWidth.value = preferences.editorTabWidth;
      autoIndent.value = preferences.editorAutoIndent;
    } catch (_) {
      /* 读取失败保留默认值。 */
    }
  }

  Future<void> setFontSize(double value) async {
    final clamped = value.clamp(minTextFontSize, maxTextFontSize).toDouble();
    if (clamped == fontSize.value) return;
    fontSize.value = clamped;
    await _save((preferences) => preferences.copyWith(textFontSize: clamped));
  }

  Future<void> stepFontSize(double delta) =>
      setFontSize(fontSize.value + delta);

  Future<void> setWrap(bool value) async {
    if (value == wrap.value) return;
    wrap.value = value;
    await _save((preferences) => preferences.copyWith(textWrap: value));
  }

  Future<void> setMarkdownMode(String value) async {
    if (value == markdownMode.value) return;
    markdownMode.value = value;
    await _save((preferences) => preferences.copyWith(markdownMode: value));
  }

  Future<void> setLineNumbers(bool value) async {
    if (value == lineNumbers.value) return;
    lineNumbers.value = value;
    await _save((preferences) => preferences.copyWith(showLineNumbers: value));
  }

  Future<void> setTabWidth(int value) async {
    if (value == tabWidth.value) return;
    tabWidth.value = value;
    await _save((preferences) => preferences.copyWith(editorTabWidth: value));
  }

  Future<void> setAutoIndent(bool value) async {
    if (value == autoIndent.value) return;
    autoIndent.value = value;
    await _save((preferences) => preferences.copyWith(editorAutoIndent: value));
  }

  /// 在最新偏好的基础上应用单项修改，避免覆盖排序、根目录等其他设置。
  Future<void> _save(VaultPreferences Function(VaultPreferences) update) async {
    try {
      final current = await _store.loadPreferences();
      await _store.savePreferences(update(current));
    } catch (_) {
      /* 偏好保存失败不影响当前展示。 */
    }
  }
}
