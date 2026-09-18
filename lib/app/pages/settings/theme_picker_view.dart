import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';

/// 选择应用配色方案；列出全部内置方案并即时预览。
///
/// 每个方案左侧以浅/深双色块预览主、次、三级色，选中项以勾选标识；
/// 选择后立即生效并持久化。
class ThemePickerView extends GetView<ThemeController> {
  const ThemePickerView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('主题配色')),
    body: Obx(() {
      // 在 Obx 构建期读取可观察值，避免依赖懒加载 itemBuilder 触发订阅。
      final selectedScheme = controller.scheme.value;
      return ListView.separated(
        itemCount: selectableFlexSchemes.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final scheme = selectableFlexSchemes[index];
          final selected = scheme == selectedScheme;
          return ListTile(
            leading: _SchemeSwatch(scheme: scheme),
            title: Text(scheme.data.name),
            subtitle: Text(
              scheme.data.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: selected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            selected: selected,
            onTap: () => controller.setScheme(scheme),
          );
        },
      );
    }),
  );
}

/// 配色预览色块：左半为浅色方案、右半为深色方案，各展示主/次/三级色。
class _SchemeSwatch extends StatelessWidget {
  const _SchemeSwatch({required this.scheme});

  final FlexScheme scheme;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _ModePreview(colors: scheme.data.light)),
        Expanded(child: _ModePreview(colors: scheme.data.dark)),
      ],
    ),
  );
}

/// 单一模式（浅色或深色）的色带：主色占上，次色与三级色并排在下。
class _ModePreview extends StatelessWidget {
  const _ModePreview({required this.colors});

  final FlexSchemeColor colors;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(flex: 3, child: ColoredBox(color: colors.primary)),
      Expanded(
        flex: 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ColoredBox(color: colors.secondary)),
            Expanded(child: ColoredBox(color: colors.tertiary)),
          ],
        ),
      ),
    ],
  );
}
