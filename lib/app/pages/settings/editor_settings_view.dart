import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../di/injector.dart';
import '../../localization.dart';
import '../../preview/preview_defaults.dart';
import '../preview/preview_settings_controller.dart';

/// 编辑器与文本/代码预览的显示偏好设置。
///
/// 所有选项即时生效并持久化到 [PreviewSettingsController]；字号、自动换行、
/// 行号同时作用于文本/代码预览与编辑器，Tab 缩进与自动缩进仅编辑器使用。
class EditorSettingsView extends StatelessWidget {
  const EditorSettingsView({super.key});

  PreviewSettingsController get controller =>
      getIt<PreviewSettingsController>();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.settingsEditor)),
    body: SignalBuilder(
      builder: (context) => ListView(
        children: [
          _SectionHeader(context.l10n.editorSectionTextCode),
          _fontSizeTile(context),
          SwitchListTile(
            secondary: const Icon(Icons.wrap_text),
            title: Text(context.l10n.editorWrap),
            subtitle: Text(context.l10n.editorWrapSubtitle),
            value: controller.wrap.value,
            onChanged: controller.setWrap,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_list_numbered),
            title: Text(context.l10n.editorLineNumbers),
            value: controller.lineNumbers.value,
            onChanged: controller.setLineNumbers,
          ),
          const Divider(height: 1),
          _SectionHeader(context.l10n.editorSectionEditor),
          ListTile(
            leading: const Icon(Icons.keyboard_tab),
            title: Text(context.l10n.editorTabWidth),
            subtitle: Text(
              context.l10n.editorTabWidthValue(controller.tabWidth.value),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTabWidth(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_indent_increase),
            title: Text(context.l10n.editorAutoIndent),
            subtitle: Text(context.l10n.editorAutoIndentSubtitle),
            value: controller.autoIndent.value,
            onChanged: controller.setAutoIndent,
          ),
          const Divider(height: 1),
          _SectionHeader(context.l10n.editorSectionMarkdown),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(context.l10n.editorMarkdownMode),
            subtitle: Text(
              controller.markdownMode.value == kMarkdownModeSource
                  ? context.l10n.editorMarkdownSource
                  : context.l10n.editorMarkdownRead,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickMarkdownMode(context),
          ),
        ],
      ),
    ),
  );

  /// 字号滑杆；取值限制在允许范围内并实时持久化。
  Widget _fontSizeTile(BuildContext context) => ListTile(
    leading: const Icon(Icons.format_size),
    title: Text(context.l10n.editorFontSize),
    subtitle: Slider(
      min: minTextFontSize,
      max: maxTextFontSize,
      divisions: (maxTextFontSize - minTextFontSize).round(),
      value: controller.fontSize.value,
      label: controller.fontSize.value.round().toString(),
      onChanged: controller.setFontSize,
    ),
    trailing: Text('${controller.fontSize.value.round()}'),
  );

  /// 选择 Tab 缩进宽度；取消不改变当前值。
  Future<void> _pickTabWidth(BuildContext context) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.l10n.editorTabWidth),
        children: [
          for (final width in kEditorTabWidthOptions)
            ListTile(
              title: Text(context.l10n.editorTabWidthValue(width)),
              trailing: width == controller.tabWidth.value
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(dialogContext, width),
            ),
        ],
      ),
    );
    if (selected != null) await controller.setTabWidth(selected);
  }

  /// 选择 Markdown 展示模式；取消不改变当前值。
  Future<void> _pickMarkdownMode(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.l10n.editorMarkdownMode),
        children: [
          for (final option in [
            (kDefaultMarkdownMode, context.l10n.editorMarkdownRead),
            (kMarkdownModeSource, context.l10n.editorMarkdownSource),
          ])
            ListTile(
              title: Text(option.$2),
              trailing: option.$1 == controller.markdownMode.value
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(dialogContext, option.$1),
            ),
        ],
      ),
    );
    if (selected != null) await controller.setMarkdownMode(selected);
  }
}

/// 设置分组标题：与主题配色页保持一致的视觉层级。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
