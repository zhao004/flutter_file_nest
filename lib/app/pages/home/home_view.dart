import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../file_type/file_category.dart';
import '../../file_type/file_category_icon.dart';
import '../../file_type/file_icon_mapper.dart';
import '../../models/archive_models.dart';
import '../../models/storage_entry.dart';
import '../../preview/preview_launcher.dart';
import '../../routes/app_pages.dart';
import 'home_controller.dart';
import 'home_widgets.dart';

/// 展示所授权目录的实时快照；重入前台或子页面返回时刷新外部文件变更。
///
/// 支持三种模式：浏览（默认）、批量选择（长按进入）、文件名搜索。
/// 系统返回优先退出选择模式，其次退出搜索，最后返回上级目录。
class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  HomeController get controller => Get.find<HomeController>();

  /// 待保存外部分享的处理状态；避免重复弹窗。
  Worker? _incomingWorker;
  bool _promptingIncoming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _incomingWorker = ever(controller.incomingShares, (_) => _handleIncoming());
    // 冷启动时可能已存在待保存项，构建完成后补处理一次。
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleIncoming());
  }

  @override
  void dispose() {
    _incomingWorker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 处理来自其他应用的文件：保存到当前打开的文件夹。
  ///
  /// 当前文件夹不可写时回退到授权根目录；完全没有可用目录（首次或授权失效）
  /// 时弹一次授权，授权后保存到根目录。
  Future<void> _handleIncoming() async {
    if (_promptingIncoming || !mounted || controller.incomingShares.isEmpty) {
      return;
    }
    _promptingIncoming = true;
    try {
      if (controller.rootRequired.value &&
          await _pickRootForIncoming() != true) {
        controller.clearIncoming();
        return;
      }
      final target = controller.current?.canCreate == true
          ? controller.current
          : controller.folders.firstOrNull;
      if (target == null) {
        controller.clearIncoming();
        return;
      }
      final count = controller.incomingShares.length;
      if (await controller.importIncoming(target)) {
        _notify('已保存 $count 个文件到「${target.name}」');
      }
    } finally {
      _promptingIncoming = false;
    }
  }

  /// 未授权根目录时提示先选择存储文件夹；确认选择返回 true。
  ///
  /// SAF 写权限只能通过用户授权获得，因此首次仍必须由用户选择一次目录。
  Future<bool?> _pickRootForIncoming() async {
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('请先选择存储文件夹'),
        content: const Text('有其他应用的文件待保存，请先授权一个文件夹作为保存位置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('选择文件夹'),
          ),
        ],
      ),
    );
    if (proceed != true) return false;
    await controller.pickRoot();
    return !controller.rootRequired.value;
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
        title: entry == null
            ? '新建文件夹'
            : entry.isDirectory
            ? '重命名文件夹'
            : '重命名文件',
        fieldLabel: entry != null && !entry.isDirectory ? '文件名称' : '文件夹名称',
      ),
    );
    if (name == null) return;
    if (entry == null) {
      await controller.createFolder(name);
    } else {
      await controller.renameEntry(entry, name);
    }
  }

  Future<void> _delete(StorageEntry entry) async {
    try {
      controller.busy.value = true;
      final impact = await controller.storage.deletionImpact(entry);
      controller.busy.value = false;
      if (!mounted) return;
      final confirmed = await _confirmDelete(
        title: '永久删除“${entry.name}”？',
        content: '${impact.files} 个文件，${impact.folders} 个子文件夹\n删除后无法恢复。',
      );
      controller.busy.value = false;
      if (confirmed == true) await controller.deleteEntry(entry);
    } catch (_) {
      controller.error.value = '无法确认目录内容，未执行删除，请刷新后重试';
    } finally {
      controller.busy.value = false;
    }
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String content,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
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

  /// 批量删除：汇总去重后的影响数量并确认，逐项执行后展示结果。
  Future<void> _batchDelete() async {
    try {
      controller.busy.value = true;
      final impact = await controller.selectedImpact();
      controller.busy.value = false;
      if (!mounted) return;
      final confirmed = await _confirmDelete(
        title: '永久删除 ${controller.selectedCount} 项？',
        content: '${impact.files} 个文件，${impact.folders} 个子文件夹\n删除后无法恢复。',
      );
      if (confirmed != true) return;
      final job = await controller.deleteSelected();
      if (job != null && mounted) showBatchResult(context, job);
    } catch (_) {
      controller.error.value = '无法确认目录内容，未执行删除，请刷新后重试';
    } finally {
      controller.busy.value = false;
    }
  }

  /// 批量移动：应用内目录选择器确定目标，禁止移入自身或后代。
  Future<void> _batchMove() async {
    final root = controller.folders.firstOrNull;
    if (root == null) return;
    final trail = await showDialog<List<StorageEntry>>(
      context: context,
      builder: (_) => FolderPickerDialog(
        storage: controller.storage,
        root: root,
        selectedCount: controller.selectedCount,
        validate: controller.moveTargetIssue,
        // 所选文件夹禁止进入，避免把目标选到自身或其后代。
        blockedDocumentIds: {
          for (final entry in controller.selectedEntries())
            if (entry.isDirectory) entry.documentId,
        },
      ),
    );
    if (trail == null) return;
    // 弹窗已实时校验，这里仅作兜底。
    final issue = controller.moveTargetIssue(trail);
    if (issue != null) {
      controller.error.value = issue;
      return;
    }
    final job = await controller.moveSelected(trail);
    if (job != null && mounted) showBatchResult(context, job);
  }

  Future<void> _batchRename() async {
    await showDialog<void>(
      context: context,
      builder: (_) => BatchRenameDialog(controller: controller),
    );
  }

  Future<void> _batchZip() => _zipWithCustomName(controller.selectedEntries());

  Future<void> _batchShare() async {
    final outcome = await controller.shareSelected();
    // 打开系统分享面板本身即为反馈，成功时不再弹出提示。
    if (outcome.ok) return;
    _notify(outcome.summary);
  }

  Future<void> _showDetails(StorageEntry entry) async {
    final location = controller.folders.map((value) => value.name).join(' / ');
    await showDialog<void>(
      context: context,
      builder: (_) => EntryDetailsDialog(
        controller: controller,
        entry: entry,
        location: location,
      ),
    );
  }

  Future<void> _open(StorageEntry entry) async {
    if (controller.selectionMode.value) {
      controller.toggleSelect(entry);
      return;
    }
    if (entry.isDirectory) {
      await controller.enter(entry);
      return;
    }
    // 外部类型由启动器直接交给系统；应用内预览返回后刷新，反映预览页
    // 可能产生的改动（例如归档解压产生的新文件）。
    final inApp = await openEntryPreview(entry, storage: controller.storage);
    if (inApp) await controller.refresh();
  }

  /// 长按文件/文件夹弹出的功能菜单；菜单关闭后按选择执行对应操作。
  Future<void> _actions(StorageEntry entry) async {
    final canWrite = controller.current?.canCreate == true;
    final archiving = controller.archive.active.value != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
              if (entry.canRename)
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: Text(entry.isDirectory ? '重命名' : '重命名文件'),
                  enabled: !archiving,
                  onTap: () => Navigator.pop(context, 'rename'),
                ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('详情'),
                onTap: () => Navigator.pop(context, 'details'),
              ),
              if (looksLikeZip(entry))
                ListTile(
                  leading: const Icon(Icons.unarchive_outlined),
                  title: const Text('解压到新文件夹'),
                  subtitle: const Text('同名文件夹存在时自动使用新名称'),
                  enabled: canWrite && !archiving,
                  onTap: () => Navigator.pop(context, 'extract'),
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('删除'),
                enabled: entry.canDelete && !archiving,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (action) {
      case 'rename':
        await _nameDialog(entry: entry);
      case 'details':
        await _showDetails(entry);
      case 'delete':
        await _delete(entry);
      case 'extract':
        _notify((await controller.extractEntry(entry)).summary);
    }
  }

  /// 压缩前先确认压缩包名称；缺少 .zip 后缀时由对话框自动补齐。
  Future<void> _zipWithCustomName(List<StorageEntry> entries) async {
    if (entries.isEmpty) return;
    final defaultName = defaultZipFileName(entries.first.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => ZipNameDialog(initialName: defaultName),
    );
    if (name == null) return;
    final outcome = await (entries.length == 1
        ? controller.zipEntry(entries.single, fileName: name)
        : controller.zipSelected(fileName: name));
    _notify(outcome.summary);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 前台归档任务进度条；总量未知时使用不定进度，始终提供取消入口。
  Widget _archiveBanner(ArchiveTaskState task) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(value: task.fraction),
        ListTile(
          dense: true,
          leading: const Icon(Icons.folder_zip_outlined),
          title: Text(task.label),
          trailing: task.canCancel
              ? TextButton(
                  onPressed: () async {
                    await controller.cancelArchive();
                    _notify('正在取消归档任务…');
                  },
                  child: const Text('取消'),
                )
              : null,
        ),
      ],
    ),
  );

  /// 系统返回的层级处理：选择模式 → 搜索 → 目录导航。
  Future<bool> _handlePop() async {
    if (controller.selectionMode.value) {
      controller.exitSelection();
      return true;
    }
    if (controller.searchQuery.value != null) {
      controller.exitSearch();
      return true;
    }
    if (controller.canGoBack && !controller.busy.value) {
      await controller.back();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final busy = controller.busy.value;
    final needsRoot = controller.rootRequired.value;
    final current = controller.current;
    final selectionMode = controller.selectionMode.value;
    final searching = controller.searching.value;
    final inSearch = controller.searchQuery.value != null;
    // 搜索状态行仅在扫描中或结果不完整时出现，不再常驻结果数量提示。
    final searchStatus = inSearch ? _searchStatus() : null;
    // 项目固定的 build_runner/analyzer 无法解析 `?element` 空安全元素新语法，
    // 用可空列表配合展开运算符达到同等效果。
    final statusWidgets = searchStatus == null ? null : <Widget>[searchStatus];
    return PopScope(
      canPop:
          !selectionMode && !inSearch && (!controller.canGoBack || needsRoot),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        appBar: inSearch ? _searchBar(busy) : _appBar(busy, needsRoot),
        body: Column(
          children: [
            SizedBox(
              height: 3,
              child: busy || searching ? const LinearProgressIndicator() : null,
            ),
            if (controller.archive.active.value != null)
              _archiveBanner(controller.archive.active.value!),
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
            ...?statusWidgets,
            if (!needsRoot && current != null && !inSearch)
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
                  ? _rootPrompt()
                  : inSearch
                  ? _searchResults(busy)
                  : _entryList(busy, selectionMode),
            ),
          ],
        ),
        // 多选模式保留批量操作栏；浏览模式改用可展开悬浮按钮。
        bottomNavigationBar: !needsRoot && selectionMode
            ? _selectionBar(busy)
            : null,
        floatingActionButton:
            !needsRoot &&
                !selectionMode &&
                !inSearch &&
                current?.canCreate == true
            ? ExpandableActionFab(
                enabled: !busy,
                actions: [
                  FabAction(
                    label: '新建文件夹',
                    icon: const FileCategoryIcon(
                      category: FileCategory.folder,
                      folderState: FolderIconState.create,
                    ),
                    onPressed: () => _nameDialog(),
                  ),
                  FabAction(
                    label: '选择文件',
                    icon: const Icon(Icons.insert_drive_file_outlined),
                    onPressed: () => controller.importFromPicker(const ['*/*']),
                  ),
                  FabAction(
                    label: '拍照',
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed: controller.capturePhoto,
                  ),
                  FabAction(
                    label: '录制',
                    icon: const Icon(Icons.videocam_outlined),
                    onPressed: controller.captureVideo,
                  ),
                ],
              )
            : null,
      ),
    );
  });

  PreferredSizeWidget _appBar(bool busy, bool needsRoot) => AppBar(
    // 标题固定为应用名，不随目录导航变化；返回改用系统返回与路径栏。
    title: const Text('LensVault'),
    actions: [
      // 搜索与多选保留独立按钮，排序与设置收进“更多”菜单。
      if (!needsRoot)
        IconButton(
          tooltip: '搜索文件',
          onPressed: busy ? null : _beginSearch,
          icon: const Icon(Icons.search),
        ),
      if (!needsRoot)
        IconButton(
          tooltip: controller.selectionMode.value ? '退出多选' : '多选',
          onPressed: busy
              ? null
              : controller.selectionMode.value
              ? controller.exitSelection
              : controller.startSelection,
          icon: Icon(
            controller.selectionMode.value ? Icons.check_box : Icons.checklist,
            color: controller.selectionMode.value
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      PopupMenuButton<_HomeMenuAction>(
        tooltip: '更多',
        enabled: !busy,
        icon: const Icon(Icons.more_vert),
        onSelected: _handleMenuAction,
        itemBuilder: (context) => [
          if (!needsRoot) ...[
            const PopupMenuItem(
              value: _HomeMenuAction.chooseSort,
              child: _MenuRow(icon: Icons.sort, label: '排序方式'),
            ),
            const PopupMenuDivider(),
          ],
          const PopupMenuItem(
            value: _HomeMenuAction.settings,
            child: _MenuRow(icon: Icons.settings_outlined, label: '设置'),
          ),
        ],
      ),
    ],
  );

  /// 处理“更多”菜单选择；排序方式与方向都经弹窗确认。
  Future<void> _handleMenuAction(_HomeMenuAction action) async {
    switch (action) {
      case _HomeMenuAction.chooseSort:
        await _chooseSort();
      case _HomeMenuAction.settings:
        await Get.toNamed<void>(Routes.settings);
        await controller.refresh();
    }
  }

  /// 弹出“排序方式”弹窗；字段与升降序都需点击确定后应用，取消不改变现有排序。
  Future<void> _chooseSort() async {
    final preferences = controller.preferences.value;
    var selected = preferences.sort;
    var descending = preferences.descending;
    final confirmed = await showDialog<(EntrySort, bool)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('排序方式'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 每行两个：两行排布四个排序字段，窄屏也无需横向滚动。
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < _sortOptions.length; index += 2)
                      Row(
                        children: [
                          for (var offset = 0; offset < 2; offset++)
                            Expanded(
                              child: index + offset < _sortOptions.length
                                  ? _SortOptionTile(
                                      label: _sortOptions[index + offset].$2,
                                      selected:
                                          selected ==
                                          _sortOptions[index + offset].$1,
                                      fontSize: _sortOptionFontSize,
                                      onTap: () => setState(
                                        () => selected =
                                            _sortOptions[index + offset].$1,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                  ],
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('排序方向'),
                      const SizedBox(height: 4),
                      // 两个单选按钮横排；整块区域可点，避免只能点中圆圈。
                      RadioGroup<bool>(
                        groupValue: descending,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => descending = value);
                          }
                        },
                        child: Row(
                          children: [
                            _DirectionOption(
                              label: '升序',
                              value: false,
                              onTap: () => setState(() => descending = false),
                            ),
                            const SizedBox(width: 12),
                            _DirectionOption(
                              label: '降序',
                              value: true,
                              onTap: () => setState(() => descending = true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (selected, descending)),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != null) {
      await controller.setSort(confirmed.$1, confirmed.$2);
    }
  }

  /// 搜索状态行：扫描中显示可取消，结果不完整时给出原因；其余情况不显示。
  Widget? _searchStatus() {
    if (controller.searching.value) {
      return ListTile(
        dense: true,
        title: const Text('正在扫描子文件夹…'),
        trailing: TextButton(
          onPressed: controller.cancelSearch,
          child: const Text('取消'),
        ),
      );
    }
    if (controller.searchIncomplete.value) {
      return const ListTile(
        dense: true,
        leading: Icon(Icons.info_outline),
        title: Text('部分文件夹无法访问，结果不完整'),
      );
    }
    return null;
  }

  /// 搜索模式的应用栏；放大镜作为输入框前缀，关闭即退出搜索。
  PreferredSizeWidget _searchBar(bool busy) => AppBar(
    automaticallyImplyLeading: false,
    title: TextField(
      controller: _searchText,
      autofocus: false,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: '搜索文件名',
        border: InputBorder.none,
      ),
      onChanged: (value) => controller.beginSearch(value),
    ),
    actions: [
      IconButton(
        tooltip: '递归搜索子文件夹',
        onPressed: controller.searching.value || busy
            ? null
            : () => controller.searchAll(_searchText.text),
        icon: const Icon(Icons.account_tree_outlined),
      ),
      IconButton(
        tooltip: '退出搜索',
        onPressed: controller.exitSearch,
        icon: const Icon(Icons.close),
      ),
    ],
  );

  final TextEditingController _searchText = TextEditingController();

  /// 从应用栏进入搜索；退出搜索时保留关键词便于快速恢复上下文。
  void _beginSearch() {
    controller.beginSearch(_searchText.text);
  }

  Widget _rootPrompt() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FileCategoryIcon(
            category: FileCategory.folder,
            folderState: FolderIconState.open,
            size: 64,
            color: fileCategoryColor(context, FileCategory.folder),
          ),
          const SizedBox(height: 20),
          const Text('选择存储文件夹', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: controller.busy.value ? null : controller.pickRoot,
            icon: const Icon(Icons.folder_open),
            label: const Text('选择文件夹'),
          ),
        ],
      ),
    ),
  );

  Widget _searchResults(bool busy) {
    if (controller.searchResults.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listPadding,
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.search_off,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Center(child: Text('没有匹配的文件')),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _listPadding,
      itemCount: controller.searchResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
      itemBuilder: (context, index) =>
          _searchRow(controller.searchResults[index], busy),
    );
  }

  /// 搜索结果行：注明结果位置；文件夹进入后搜索退出，可通过再次点击
  /// 搜索图标恢复关键词上下文。
  Widget _searchRow(StorageEntry entry, bool busy) {
    final location = controller.searchLocationOf(entry);
    return ListTile(
      leading: _entryIcon(entry),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('位置：${location ?? '未知'}'),
      enabled: !busy,
      onTap: () async {
        if (entry.isDirectory) {
          await controller.enter(entry);
        } else {
          final inApp = await openEntryPreview(
            entry,
            storage: controller.storage,
          );
          if (inApp) await controller.refresh();
        }
      },
    );
  }

  /// 列表底部内边距：为悬浮按钮与系统底部安全区留出空间。
  EdgeInsets get _listPadding =>
      EdgeInsets.only(bottom: 96 + MediaQuery.paddingOf(context).bottom);

  Widget _entryList(bool busy, bool selectionMode) {
    if (controller.entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listPadding,
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.folder_open_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Center(child: Text('文件夹为空')),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listPadding,
        itemCount: controller.entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
        itemBuilder: (context, index) {
          final entry = controller.entries[index];
          if (selectionMode) return _selectionRow(entry);
          return _browseRow(entry, busy);
        },
      ),
    );
  }

  /// 文件行详情：大小、创建时间（仅按创建时间排序时）与修改时间；无数据显示 null。
  String? _entryDetail(StorageEntry entry) {
    final date = entry.modifiedAt;
    final showCreated = controller.preferences.value.sort == EntrySort.created;
    final created = controller.createdAtOf(entry);
    final detail = [
      if (!entry.isDirectory) formatBytes(entry.size),
      if (showCreated && created != null) _formatDateTime(created),
      if (date != null) _formatDateTime(date),
    ];
    return detail.isEmpty ? null : detail.join(' · ');
  }

  /// 行字幕：视频异步补充分辨率并置于文件信息左侧；其余条目直接显示详情。
  Widget? _entrySubtitle(StorageEntry entry, String? detail) {
    if (detail == null) return null;
    if (!entry.isVideo) return Text(detail);
    return EntryVideoDetail(
      detail: detail,
      identity: _thumbnailIdentity(entry),
      load: () => controller.videoDetails(entry),
    );
  }

  /// 视频与图片使用惰性缩略图，其余类型回退为类型图标。
  Widget _entryThumbnail(StorageEntry entry) => entry.isVideo || entry.isImage
      ? EntryThumbnail(
          identity: _thumbnailIdentity(entry),
          load: () => controller.thumbnailFor(entry),
          onCancel: () => controller.cancelThumbnail(entry),
          fallback: _entryIcon(entry),
        )
      : _entryIcon(entry);

  /// 缩略图重载标识：URI 加修改时间指纹，条目变化即重新加载。
  String _thumbnailIdentity(StorageEntry entry) =>
      '${entry.uri}|${entry.modifiedAt?.millisecondsSinceEpoch ?? 0}';

  /// 浏览行：缩略图（视频与图片）；长按弹出文件功能菜单。
  Widget _browseRow(StorageEntry entry, bool busy) {
    final detail = _entryDetail(entry);
    return ListTile(
      leading: _entryThumbnail(entry),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: _entrySubtitle(entry, detail),
      enabled: !busy,
      onTap: () => _open(entry),
      onLongPress: busy ? null : () => _actions(entry),
    );
  }

  /// 选择行：缩略图左侧是选择按钮，文件信息与浏览行一致，点击整行切换选中。
  Widget _selectionRow(StorageEntry entry) {
    final checked = controller.selected.contains(entry.uri);
    final detail = _entryDetail(entry);
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: checked ? '取消选择' : '选择',
            visualDensity: VisualDensity.compact,
            onPressed: () => controller.toggleSelect(entry),
            icon: Icon(
              checked ? Icons.check_circle : Icons.radio_button_unchecked,
              color: checked ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          _entryThumbnail(entry),
        ],
      ),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: _entrySubtitle(entry, detail),
      onTap: () => controller.toggleSelect(entry),
    );
  }

  /// 目录在缺少写入能力时显示受保护图标；其余分类使用统一映射。
  FolderIconState _folderState(StorageEntry entry) =>
      entry.isDirectory && !entry.canCreate && !entry.canDelete
      ? FolderIconState.locked
      : FolderIconState.closed;

  Widget _entryIcon(StorageEntry entry) {
    final category = entry.fileCategory;
    final folderState = _folderState(entry);
    return FileCategoryIcon(
      category: category,
      folderState: folderState,
      color: fileCategoryColor(context, category, folderState: folderState),
    );
  }

  /// 选择模式底部操作栏：退出、全选、删除、移动、重命名、压缩与分享。
  Widget _selectionBar(bool busy) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              TextButton(
                onPressed: controller.exitSelection,
                child: const Text('取消'),
              ),
              Expanded(
                child: Text(
                  '已选 ${controller.selectedCount} 项',
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: controller.toggleSelectAll,
                child:
                    controller.selectedCount == controller.entries.length &&
                        controller.entries.isNotEmpty
                    ? const Text('取消全选')
                    : const Text('全选'),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: '删除',
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchDelete,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: '移动到…',
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchMove,
              icon: const Icon(Icons.drive_file_move_outlined),
            ),
            IconButton(
              tooltip: '批量重命名',
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchRename,
              icon: const Icon(Icons.drive_file_rename_outline),
            ),
            IconButton(
              tooltip: '压缩为 ZIP',
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchZip,
              icon: const Icon(Icons.folder_zip_outlined),
            ),
            IconButton(
              tooltip: '分享',
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchShare,
              icon: const Icon(Icons.ios_share),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 时间显示格式：年-月-日 时:分。
String _formatDateTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

/// “排序方式”弹窗的可选项，顺序与展示名称。
const _sortOptions = <(EntrySort, String)>[
  (EntrySort.name, '按名称'),
  (EntrySort.modified, '按修改时间'),
  (EntrySort.created, '按创建时间'),
  (EntrySort.size, '按文件大小'),
];

/// “排序方式”字段选项的字号；需要调整四项文本大小时集中改这里。
const double _sortOptionFontSize = 13;

/// “更多”菜单项；搜索为独立按钮，排序字段与升降序在“排序方式”弹窗中完成。
enum _HomeMenuAction { chooseSort, settings }

/// “排序方式”字段选项：选中图标 + 文本，字号由外部传入以便统一调整。
class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: fontSize + 7,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    ),
  );
}

/// “排序方向”横排单选：整块区域可点，Radio 仅作为选中指示。
class _DirectionOption extends StatelessWidget {
  const _DirectionOption({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool>(
            value: value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    ),
  );
}

/// 菜单项统一布局：固定宽度的前置图标槽保证各项文本对齐。
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 20, child: icon == null ? null : Icon(icon, size: 18)),
      const SizedBox(width: 12),
      Text(label),
    ],
  );
}
