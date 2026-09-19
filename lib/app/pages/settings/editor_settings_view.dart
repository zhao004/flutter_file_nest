import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../preview/preview_defaults.dart';
import '../preview/preview_settings_controller.dart';

/// 编辑器与文本/代码预览的显示偏好设置。
///
/// 所有选项即时生效并持久化到 [PreviewSettingsController]；字号、自动换行、
/// 行号同时作用于文本/代码预览与编辑器，Tab 缩进与自动缩进仅编辑器使用。
class EditorSettingsView extends GetView<PreviewSettingsController> {
  const EditorSettingsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('编辑器配置')),
    body: Obx(
      () => ListView(
        children: [
          const _SectionHeader('文本与代码'),
          _fontSizeTile(context),
          SwitchListTile(
            secondary: const Icon(Icons.wrap_text),
            title: const Text('自动换行'),
            subtitle: const Text('关闭后长行改为横向滚动'),
            value: controller.wrap.value,
            onChanged: controller.setWrap,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_list_numbered),
            title: const Text('显示行号'),
            value: controller.lineNumbers.value,
            onChanged: controller.setLineNumbers,
          ),
          const Divider(height: 1),
          const _SectionHeader('编辑器'),
          ListTile(
            leading: const Icon(Icons.keyboard_tab),
            title: const Text('Tab 缩进'),
            subtitle: Text('${controller.tabWidth.value} 个空格'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTabWidth(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_indent_increase),
            title: const Text('自动缩进'),
            subtitle: const Text('换行时保持当前行的缩进'),
            value: controller.autoIndent.value,
            onChanged: controller.setAutoIndent,
          ),
          const Divider(height: 1),
          const _SectionHeader('Markdown'),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('展示模式'),
            subtitle: Text(
              controller.markdownMode.value == kMarkdownModeSource
                  ? '源码'
                  : '阅读',
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
    title: const Text('字号'),
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
        title: const Text('Tab 缩进'),
        children: [
          for (final width in kEditorTabWidthOptions)
            ListTile(
              title: Text('$width 个空格'),
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
        title: const Text('展示模式'),
        children: [
          for (final option in const [
            (kDefaultMarkdownMode, '阅读'),
            (kMarkdownModeSource, '源码'),
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
