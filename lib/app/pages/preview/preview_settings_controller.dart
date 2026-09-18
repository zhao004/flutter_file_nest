import 'package:get/get.dart';

import '../../preview/preview_defaults.dart';
import '../../services/vault_store.dart';

/// 预览显示偏好：文本字号、自动换行与 Markdown 模式。
///
/// 偏好持久化到 [VaultStore]；保存失败只影响下次启动的默认值，不阻断
/// 当前展示。控制器在应用启动时注册为常驻实例，预览页只读取其响应式值。
class PreviewSettingsController extends GetxController {
  PreviewSettingsController(this._store);

  final VaultStore _store;

  /// 文本/代码预览字号（逻辑像素）。
  final fontSize = kDefaultTextFontSize.obs;

  /// 文本预览是否自动换行。
  final wrap = kDefaultTextWrap.obs;

  /// Markdown 展示模式：read（阅读）或 source（源码）。
  final markdownMode = kDefaultMarkdownMode.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// 从存储读取偏好；失败时保留当前值。
  Future<void> load() async {
    try {
      final preferences = await _store.loadPreferences();
      fontSize.value = preferences.textFontSize;
      wrap.value = preferences.textWrap;
      markdownMode.value = preferences.markdownMode;
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
