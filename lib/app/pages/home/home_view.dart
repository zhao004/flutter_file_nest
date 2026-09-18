import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/archive_models.dart';
import '../../models/storage_entry.dart';
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
      builder: (_) =>
          FolderPickerDialog(storage: controller.storage, root: root),
    );
    if (trail == null) return;
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
    if (entry.isVideo) {
      await Get.toNamed<void>(Routes.video, arguments: entry);
      await controller.refresh();
    } else if (entry.isImage) {
      await Get.toNamed<void>(Routes.imagePreview, arguments: entry);
    } else if (entry.isPdf) {
      await Get.toNamed<void>(Routes.pdfPreview, arguments: entry);
    } else {
      await controller.openFile(entry);
    }
  }

  /// 长按文件/文件夹弹出的功能菜单；菜单关闭后按选择执行对应操作，
  /// “多选”项用于进入批量选择模式。
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
              ListTile(
                leading: const Icon(Icons.checklist),
                title: const Text('多选'),
                onTap: () => Navigator.pop(context, 'select'),
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
              if (canWrite)
                ListTile(
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: const Text('压缩为 ZIP'),
                  subtitle: const Text('输出到当前文件夹，不覆盖同名文件'),
                  enabled: !archiving,
                  onTap: () => Navigator.pop(context, 'zip'),
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
                leading: const Icon(Icons.ios_share),
                title: const Text('分享'),
                subtitle: entry.isDirectory
                    ? const Text('先生成临时 ZIP，再打开系统分享')
                    : null,
                enabled: !archiving,
                onTap: () => Navigator.pop(context, 'share'),
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
      case 'select':
        controller.beginSelection(entry);
      case 'rename':
        await _nameDialog(entry: entry);
      case 'details':
        await _showDetails(entry);
      case 'delete':
        await _delete(entry);
      case 'zip':
        await _zipWithCustomName([entry]);
      case 'extract':
        _notify((await controller.extractEntry(entry)).summary);
      case 'share':
        _notify((await controller.shareEntry(entry)).summary);
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

  /// 底部栏“添加”菜单：相册导入、PDF 导入与系统相机拍照。
  Future<void> _addContent() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择图片/视频'),
              subtitle: const Text('复制到当前文件夹'),
              onTap: () => Navigator.pop(context, 'media'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('选择 PDF 文件'),
              subtitle: const Text('复制到当前文件夹'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              subtitle: const Text('照片保存到当前文件夹'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'media':
        await controller.importFromPicker(const ['image/*', 'video/*']);
      case 'pdf':
        await controller.importFromPicker(const ['application/pdf']);
      case 'photo':
        await controller.capturePhoto();
    }
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
    return PopScope(
      canPop:
          !selectionMode && !inSearch && (!controller.canGoBack || needsRoot),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        appBar: inSearch ? _searchBar(busy) : _appBar(busy, needsRoot, current),
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
            if (inSearch)
              ListTile(
                dense: true,
                leading: const Icon(Icons.search),
                title: Text(
                  '“${controller.searchQuery.value}”的搜索结果'
                  '（${controller.searchResults.length} 项）',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: searching
                    ? const Text('正在扫描子文件夹…')
                    : controller.searchIncomplete.value
                    ? const Text('部分文件夹无法访问，结果不完整')
                    : null,
                trailing: searching
                    ? TextButton(
                        onPressed: controller.cancelSearch,
                        child: const Text('取消'),
                      )
                    : IconButton(
                        tooltip: '退出搜索',
                        onPressed: controller.exitSearch,
                        icon: const Icon(Icons.close),
                      ),
              ),
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
        bottomNavigationBar: needsRoot
            ? null
            : selectionMode
            ? _selectionBar(busy)
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
                          label: const Text('新建'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy || current?.canCreate != true
                              ? null
                              : _addContent,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('添加'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy || current?.canCreate != true
                              ? null
                              : () async {
                                  if (controller
                                      .preferences
                                      .value
                                      .systemCameraRecording) {
                                    // 系统相机录制：与拍照相同的一次调用流程。
                                    await controller.captureVideo();
                                    return;
                                  }
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

  PreferredSizeWidget _appBar(
    bool busy,
    bool needsRoot,
    StorageEntry? current,
  ) => AppBar(
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
        IconButton(
          tooltip: '搜索文件',
          onPressed: busy ? null : () => _beginSearch(),
          icon: const Icon(Icons.search),
        ),
      if (!needsRoot)
        PopupMenuButton<EntrySort>(
          tooltip: '排序',
          enabled: !busy,
          icon: const Icon(Icons.sort),
          initialValue: controller.preferences.value.sort,
          onSelected: (sort) =>
              controller.setSort(sort, controller.preferences.value.descending),
          itemBuilder: (_) => const [
            PopupMenuItem(value: EntrySort.name, child: Text('名称')),
            PopupMenuItem(value: EntrySort.modified, child: Text('修改时间')),
            PopupMenuItem(value: EntrySort.created, child: Text('创建时间')),
            PopupMenuItem(value: EntrySort.size, child: Text('文件大小')),
          ],
        ),
      if (!needsRoot)
        IconButton(
          tooltip: controller.preferences.value.descending ? '改为升序' : '改为降序',
          onPressed: busy
              ? null
              : () => controller.setSort(
                  controller.preferences.value.sort,
                  !controller.preferences.value.descending,
                ),
          icon: Icon(
            controller.preferences.value.descending ? Icons.south : Icons.north,
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
  );

  /// 搜索模式的应用栏；关闭即退出搜索（系统返回同样退出）。
  PreferredSizeWidget _searchBar(bool busy) => AppBar(
    automaticallyImplyLeading: false,
    title: TextField(
      controller: _searchText,
      autofocus: false,
      decoration: const InputDecoration(
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
          Icon(
            Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
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
        children: const [
          SizedBox(height: 100),
          Icon(Icons.search_off, size: 56, color: Colors.grey),
          SizedBox(height: 16),
          Center(child: Text('没有匹配的文件')),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
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
      leading: Icon(
        entry.isDirectory ? Icons.folder : Icons.insert_drive_file_outlined,
        color: entry.isDirectory
            ? const Color(0xffb98417)
            : Colors.grey.shade700,
      ),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('位置：${location ?? '未知'}'),
      enabled: !busy,
      onTap: () async {
        if (entry.isDirectory) {
          await controller.enter(entry);
        } else {
          await controller.openFile(entry);
        }
      },
    );
  }

  Widget _entryList(bool busy, bool selectionMode) {
    if (controller.entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.folder_open_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 16),
          Center(child: Text('文件夹为空')),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
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

  /// 浏览行：缩略图（视频与图片）；长按弹出文件功能菜单。
  Widget _browseRow(StorageEntry entry, bool busy) {
    final date = entry.modifiedAt;
    final showCreated = controller.preferences.value.sort == EntrySort.created;
    final created = controller.createdAtOf(entry);
    final detail = [
      if (!entry.isDirectory) formatBytes(entry.size),
      if (showCreated && created != null) _formatDate(created),
      if (date != null) _formatDate(date),
    ];
    return ListTile(
      leading: entry.isVideo || entry.isImage
          ? EntryThumbnail(
              load: () => controller.thumbnailFor(entry),
              fallback: _entryIcon(entry),
            )
          : _entryIcon(entry),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: detail.isEmpty ? null : Text(detail.join(' · ')),
      enabled: !busy,
      onTap: () => _open(entry),
      onLongPress: busy ? null : () => _actions(entry),
    );
  }

  /// 选择行：勾选状态直接反映在头部图标上，点击切换。
  Widget _selectionRow(StorageEntry entry) {
    final checked = controller.selected.contains(entry.uri);
    return ListTile(
      leading: Icon(
        checked ? Icons.check_box : Icons.check_box_outline_blank,
        color: checked ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: entry.isDirectory ? null : Text(formatBytes(entry.size)),
      onTap: () => controller.toggleSelect(entry),
    );
  }

  Widget _entryIcon(StorageEntry entry) => Icon(
    switch (entry) {
      _ when entry.isDirectory => Icons.folder,
      _ when entry.isVideo => Icons.movie_outlined,
      _ when entry.isImage => Icons.image_outlined,
      _ when entry.isPdf => Icons.picture_as_pdf_outlined,
      _ => Icons.insert_drive_file_outlined,
    },
    color: entry.isDirectory
        ? const Color(0xffb98417)
        : entry.isVideo
        ? Theme.of(context).colorScheme.primary
        : entry.isImage || entry.isPdf
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade700,
  );

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

String _formatDate(DateTime time) {
  return '${time.year}/'
      '${time.month.toString().padLeft(2, '0')}/'
      '${time.day.toString().padLeft(2, '0')}';
}
