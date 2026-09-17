import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/storage_entry.dart';
import '../../routes/app_pages.dart';
import 'home_controller.dart';

/// 展示所授权目录的实时快照；重入前台或子页面返回时刷新外部文件变更。
class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  HomeController get controller => Get.find<HomeController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      controller.refresh();
    }
  }

  Future<void> _nameDialog({StorageEntry? entry}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => EntryNameDialog(
        initialName: entry?.name,
        title: entry == null ? '新建文件夹' : '重命名文件夹',
      ),
    );
    if (name == null) return;
    if (entry == null) {
      await controller.createFolder(name);
    } else {
      await controller.renameFolder(entry, name);
    }
  }

  Future<void> _delete(StorageEntry entry) async {
    try {
      controller.busy.value = true;
      final impact = await controller.storage.deletionImpact(entry);
      controller.busy.value = false;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('永久删除“${entry.name}”？'),
          content: Text(
            '${impact.files} 个文件，${impact.folders} 个子文件夹\n删除后无法恢复。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('永久删除'),
            ),
          ],
        ),
      );
      controller.busy.value = false;
      if (confirmed == true) await controller.deleteEntry(entry);
    } catch (_) {
      controller.error.value = '无法确认目录内容，未执行删除，请刷新后重试';
    } finally {
      controller.busy.value = false;
    }
  }

  Future<void> _open(StorageEntry entry) async {
    if (entry.isDirectory) {
      await controller.enter(entry);
      return;
    }
    if (entry.isVideo) {
      await Get.toNamed<void>(Routes.video, arguments: entry);
      await controller.refresh();
    } else {
      await controller.openFile(entry);
    }
  }

  Future<void> _actions(StorageEntry entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entry.isDirectory && entry.canRename)
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('重命名'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('删除'),
              enabled: entry.canDelete,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') await _nameDialog(entry: entry);
    if (action == 'delete') await _delete(entry);
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final busy = controller.busy.value;
    final needsRoot = controller.rootRequired.value;
    final current = controller.current;
    return PopScope(
      canPop: !controller.canGoBack || needsRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) controller.back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            needsRoot ? 'Lens Vault' : current?.name ?? 'Lens Vault',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: !needsRoot && controller.canGoBack
              ? IconButton(
                  tooltip: '上一级',
                  onPressed: busy ? null : controller.back,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          actions: [
            if (!needsRoot)
              PopupMenuButton<EntrySort>(
                tooltip: '排序',
                enabled: !busy,
                icon: const Icon(Icons.sort),
                initialValue: controller.preferences.value.sort,
                onSelected: (sort) => controller.setSort(
                  sort,
                  controller.preferences.value.descending,
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: EntrySort.name, child: Text('名称')),
                  PopupMenuItem(value: EntrySort.modified, child: Text('修改时间')),
                  PopupMenuItem(value: EntrySort.size, child: Text('文件大小')),
                ],
              ),
            if (!needsRoot)
              IconButton(
                tooltip: controller.preferences.value.descending
                    ? '改为升序'
                    : '改为降序',
                onPressed: busy
                    ? null
                    : () => controller.setSort(
                        controller.preferences.value.sort,
                        !controller.preferences.value.descending,
                      ),
                icon: Icon(
                  controller.preferences.value.descending
                      ? Icons.south
                      : Icons.north,
                ),
              ),
            IconButton(
              tooltip: '设置',
              icon: const Icon(Icons.settings_outlined),
              onPressed: busy
                  ? null
                  : () async {
                      await Get.toNamed<void>(Routes.settings);
                      await controller.refresh();
                    },
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 3,
              child: busy ? const LinearProgressIndicator() : null,
            ),
            if (controller.error.value != null)
              MaterialBanner(
                content: Text(controller.error.value!),
                actions: [
                  TextButton(
                    onPressed: busy ? null : controller.refresh,
                    child: const Text('刷新'),
                  ),
                  IconButton(
                    tooltip: '关闭提示',
                    onPressed: () => controller.error.value = null,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            if (controller.pending.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.save_outlined,
                  color: Colors.deepOrange,
                ),
                title: Text('${controller.pending.length} 段录像待保存'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed<void>(Routes.settings),
              ),
            if (!needsRoot && current != null)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: controller.folders.length,
                  separatorBuilder: (_, _) =>
                      const Icon(Icons.chevron_right, size: 16),
                  itemBuilder: (context, index) => TextButton(
                    onPressed: busy ? null : () => controller.goTo(index),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        controller.folders[index].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: needsRoot
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '选择存储文件夹',
                              style: TextStyle(fontSize: 22),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: busy ? null : controller.pickRoot,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('选择文件夹'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: controller.entries.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 100),
                                Icon(
                                  Icons.folder_open_outlined,
                                  size: 56,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Center(child: Text('文件夹为空')),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: controller.entries.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1, indent: 64),
                              itemBuilder: (context, index) {
                                final entry = controller.entries[index];
                                final date = entry.modifiedAt;
                                final detail = [
                                  if (!entry.isDirectory)
                                    formatBytes(entry.size),
                                  if (date != null)
                                    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                                ];
                                return ListTile(
                                  leading: Icon(
                                    entry.isDirectory
                                        ? Icons.folder
                                        : entry.isVideo
                                        ? Icons.movie_outlined
                                        : Icons.insert_drive_file_outlined,
                                    color: entry.isDirectory
                                        ? const Color(0xffb98417)
                                        : entry.isVideo
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade700,
                                  ),
                                  title: Text(
                                    entry.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: detail.isEmpty
                                      ? null
                                      : Text(detail.join(' · ')),
                                  enabled: !busy,
                                  onTap: () => _open(entry),
                                  onLongPress: () => _actions(entry),
                                  trailing: IconButton(
                                    tooltip: '文件操作',
                                    onPressed: busy
                                        ? null
                                        : () => _actions(entry),
                                    icon: const Icon(Icons.more_vert),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: needsRoot
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy || current?.canCreate != true
                              ? null
                              : _nameDialog,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('新建文件夹'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy || current?.canCreate != true
                              ? null
                              : () async {
                                  await Get.toNamed<void>(
                                    Routes.camera,
                                    arguments: current,
                                  );
                                  await controller.refresh();
                                },
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('录制'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  });
}

/// 验证名称后才返回输入，避免无效名称进入原生文件操作。
class EntryNameDialog extends StatefulWidget {
  const EntryNameDialog({required this.title, this.initialName, super.key});
  final String title;
  final String? initialName;
  @override
  State<EntryNameDialog> createState() => _EntryNameDialogState();
}

class _EntryNameDialogState extends State<EntryNameDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialName,
  );
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _text.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        autofocus: true,
        maxLength: 120,
        decoration: const InputDecoration(labelText: '文件夹名称'),
        validator: (value) => validateEntryName(value ?? ''),
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('确定')),
    ],
  );
}
