import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../di/injector.dart';
import '../../file_type/file_category.dart';
import '../../file_type/file_category_icon.dart';
import '../../file_type/file_icon_mapper.dart';
import '../../localization.dart';
import '../../models/archive_models.dart';
import '../../models/media_editor_args.dart';
import '../../models/storage_entry.dart';
import '../../preview/preview_launcher.dart';
import '../../routes/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
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
  HomeController get controller => getIt<HomeController>();

  /// 待保存外部分享的处理状态；避免重复弹窗。
  EffectCleanup? _incomingEffect;
  bool _promptingIncoming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.start();
    // 分享列表变化时立即处理；effect 创建时会先执行一次。
    _incomingEffect = effect(() {
      controller.incomingShares.value;
      _handleIncoming();
    });
    // 冷启动时可能已存在待保存项，构建完成后补处理一次。
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleIncoming());
  }

  @override
  void dispose() {
    _incomingEffect?.call();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 处理来自其他应用的文件：保存到当前打开的文件夹。
  ///
  /// 当前文件夹不可写时回退到授权根目录；完全没有可用目录（首次或授权失效）
  /// 时弹一次授权，授权后保存到根目录。
  Future<void> _handleIncoming() async {
    if (_promptingIncoming ||
        !mounted ||
        controller.incomingShares.value.isEmpty) {
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
          : controller.folders.value.firstOrNull;
      if (target == null) {
        controller.clearIncoming();
        return;
      }
      final count = controller.incomingShares.value.length;
      if (await controller.importIncoming(target)) {
        if (!mounted) return;
        _notify(context.l10n.homeSavedIncomingFiles(count, target.name));
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
        title: Text(context.l10n.homePickRootFirstTitle),
        content: Text(context.l10n.homePickRootFirstBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.homeChooseFolder),
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
            ? context.l10n.homeNewFolder
            : entry.isDirectory
            ? context.l10n.homeRenameFolder
            : context.l10n.homeRenameFile,
        fieldLabel: entry != null && !entry.isDirectory
            ? context.l10n.homeFileName
            : context.l10n.homeFolderName,
      ),
    );
    if (name == null) return;
    if (entry == null) {
      await controller.createFolder(name);
    } else {
      await controller.renameEntry(entry, name);
    }
  }

  /// 新建空文件：扩展名由用户输入决定，用于后续类型识别。
  Future<void> _createFileDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => EntryNameDialog(
        title: context.l10n.homeNewFile,
        fieldLabel: context.l10n.homeFileName,
      ),
    );
    if (name == null) return;
    await controller.createFile(name);
  }

  Future<void> _delete(StorageEntry entry) async {
    final l10n = context.l10n;
    try {
      controller.busy.value = true;
      final impact = await controller.storage.deletionImpact(entry);
      controller.busy.value = false;
      if (!mounted) return;
      final confirmed = await _confirmDelete(
        title: l10n.homeDeleteForeverTitle(entry.name),
        content: l10n.homeDeleteImpact(impact.files, impact.folders),
      );
      controller.busy.value = false;
      if (confirmed == true) await controller.deleteEntry(entry);
    } catch (_) {
      controller.error.value = l10n.homeDeleteImpactUnknown;
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
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.homeDeleteConfirm),
        ),
      ],
    ),
  );

  /// 批量删除：汇总去重后的影响数量并确认，逐项执行后展示结果。
  Future<void> _batchDelete() async {
    final l10n = context.l10n;
    try {
      controller.busy.value = true;
      final impact = await controller.selectedImpact();
      controller.busy.value = false;
      if (!mounted) return;
      final confirmed = await _confirmDelete(
        title: l10n.homeDeleteForeverCountTitle(controller.selectedCount),
        content: l10n.homeDeleteImpact(impact.files, impact.folders),
      );
      if (confirmed != true) return;
      final job = await controller.deleteSelected();
      if (job != null && mounted) showBatchResult(context, job);
    } catch (_) {
      controller.error.value = l10n.homeDeleteImpactUnknown;
    } finally {
      controller.busy.value = false;
    }
  }

  /// 批量移动：应用内目录选择器确定目标，禁止移入自身或后代。
  Future<void> _batchMove() async {
    final root = controller.folders.value.firstOrNull;
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
    final l10n = context.l10n;
    final outcome = await controller.shareSelected();
    // 打开系统分享面板本身即为反馈，成功时不再弹出提示。
    if (outcome.ok) return;
    _notify(outcome.summary(l10n));
  }

  Future<void> _showDetails(StorageEntry entry) async {
    final location = controller.folders.value
        .map((value) => value.name)
        .join(' / ');
    await showDialog<void>(
      context: context,
      builder: (_) => EntryDetailsDialog(
        controller: controller,
        entry: entry,
        location: location,
      ),
    );
  }

  /// 进入图片编辑页；保存采用另存为副本，返回后刷新以显示新文件。
  Future<void> _editImage(StorageEntry entry) async {
    final parent = controller.current;
    if (parent == null) return;
    final saved = await context.push<String>(
      Routes.imageEditor,
      extra: MediaEditorArgs(entry: entry, parent: parent),
    );
    if (saved != null && mounted) _notify(context.l10n.homeSavedCopy(saved));
    await controller.refresh();
  }

  /// 进入视频编辑页；保存采用另存为副本，返回后刷新以显示新文件。
  Future<void> _editVideo(StorageEntry entry) async {
    final parent = controller.current;
    if (parent == null) return;
    final saved = await context.push<String>(
      Routes.videoEditor,
      extra: MediaEditorArgs(entry: entry, parent: parent),
    );
    if (saved != null && mounted) _notify(context.l10n.homeSavedCopy(saved));
    await controller.refresh();
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
    final inApp = await openEntryPreview(
      context,
      entry,
      storage: controller.storage,
    );
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
                  title: Text(
                    entry.isDirectory
                        ? context.l10n.homeRenameShort
                        : context.l10n.homeRenameFile,
                  ),
                  enabled: !archiving,
                  onTap: () => Navigator.pop(context, 'rename'),
                ),
              if (entry.isImage && entry.canWrite && canWrite)
                ListTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: Text(context.l10n.homeEditImage),
                  subtitle: Text(context.l10n.homeEditImageSubtitle),
                  enabled: !archiving,
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              if (entry.isVideo && entry.canWrite && canWrite)
                ListTile(
                  leading: const Icon(Icons.movie_creation_outlined),
                  title: Text(context.l10n.homeEditVideo),
                  subtitle: Text(context.l10n.homeEditVideoSubtitle),
                  enabled: !archiving,
                  onTap: () => Navigator.pop(context, 'editVideo'),
                ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.l10n.homeDetails),
                onTap: () => Navigator.pop(context, 'details'),
              ),
              if (looksLikeZip(entry))
                ListTile(
                  leading: const Icon(Icons.unarchive_outlined),
                  title: Text(context.l10n.homeExtractToFolder),
                  subtitle: Text(context.l10n.homeExtractToFolderSubtitle),
                  enabled: canWrite && !archiving,
                  onTap: () => Navigator.pop(context, 'extract'),
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(context.l10n.commonDelete),
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
      case 'edit':
        await _editImage(entry);
      case 'editVideo':
        await _editVideo(entry);
      case 'details':
        await _showDetails(entry);
      case 'delete':
        await _delete(entry);
      case 'extract':
        final outcome = await controller.extractEntry(entry);
        if (!mounted) return;
        _notify(outcome.summary(context.l10n));
    }
  }

  /// 压缩前先确认压缩包名称；缺少 .zip 后缀时由对话框自动补齐。
  Future<void> _zipWithCustomName(List<StorageEntry> entries) async {
    if (entries.isEmpty) return;
    final l10n = context.l10n;
    final defaultName = defaultZipFileName(entries.first.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => ZipNameDialog(initialName: defaultName),
    );
    if (name == null) return;
    final outcome = await (entries.length == 1
        ? controller.zipEntry(entries.single, fileName: name)
        : controller.zipSelected(fileName: name));
    if (!mounted) return;
    _notify(outcome.summary(l10n));
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          title: Text(task.label(context.l10n)),
          trailing: task.canCancel
              ? TextButton(
                  onPressed: () async {
                    await controller.cancelArchive();
                    if (!mounted) return;
                    _notify(context.l10n.homeArchiveCancelling);
                  },
                  child: Text(context.l10n.commonCancel),
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
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
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
      final statusWidgets = searchStatus == null
          ? null
          : <Widget>[searchStatus];
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
                child: busy || searching
                    ? const LinearProgressIndicator()
                    : null,
              ),
              if (controller.archive.active.value != null)
                _archiveBanner(controller.archive.active.value!),
              if (controller.error.value != null)
                MaterialBanner(
                  content: Text(controller.error.value!),
                  actions: [
                    TextButton(
                      onPressed: busy ? null : controller.refresh,
                      child: Text(context.l10n.homeRefresh),
                    ),
                    IconButton(
                      tooltip: context.l10n.homeDismissError,
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
                    itemCount: controller.folders.value.length,
                    separatorBuilder: (_, _) =>
                        const Icon(Icons.chevron_right, size: 16),
                    itemBuilder: (context, index) => TextButton(
                      onPressed: busy ? null : () => controller.goTo(index),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          controller.folders.value[index].name,
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
                  tooltip: context.l10n.homeMoreActions,
                  actions: [
                    FabAction(
                      label: context.l10n.homeNewFolder,
                      icon: const FileCategoryIcon(
                        category: FileCategory.folder,
                        folderState: FolderIconState.create,
                      ),
                      onPressed: () => _nameDialog(),
                    ),
                    FabAction(
                      label: context.l10n.homeNewFile,
                      icon: const Icon(Icons.note_add_outlined),
                      onPressed: _createFileDialog,
                    ),
                    FabAction(
                      label: context.l10n.homeSelectFiles,
                      icon: const Icon(Icons.insert_drive_file_outlined),
                      onPressed: () =>
                          controller.importFromPicker(const ['*/*']),
                    ),
                    FabAction(
                      label: context.l10n.homeTakePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: controller.capturePhoto,
                    ),
                    FabAction(
                      label: context.l10n.homeRecordVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      onPressed: controller.captureVideo,
                    ),
                  ],
                )
              : null,
        ),
      );
    },
  );

  PreferredSizeWidget _appBar(bool busy, bool needsRoot) => AppBar(
    // 标题固定为应用名，不随目录导航变化；返回改用系统返回与路径栏。
    title: const Text('FileNest'),
    actions: [
      // 搜索与多选保留独立按钮，排序与设置收进“更多”菜单。
      // 多选模式下隐藏搜索与“更多”，避免与批量操作混淆。
      if (!needsRoot && !controller.selectionMode.value)
        IconButton(
          tooltip: context.l10n.homeSearchFiles,
          onPressed: busy ? null : _beginSearch,
          icon: const Icon(Icons.search),
        ),
      if (!needsRoot)
        IconButton(
          tooltip: controller.selectionMode.value
              ? context.l10n.homeExitSelection
              : context.l10n.homeSelection,
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
      if (!controller.selectionMode.value)
        PopupMenuButton<_HomeMenuAction>(
          tooltip: context.l10n.homeMore,
          enabled: !busy,
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            if (!needsRoot) ...[
              PopupMenuItem(
                value: _HomeMenuAction.chooseSort,
                child: _MenuRow(
                  icon: Icons.sort,
                  label: context.l10n.homeSortBy,
                ),
              ),
              const PopupMenuDivider(),
            ],
            PopupMenuItem(
              value: _HomeMenuAction.settings,
              child: _MenuRow(
                icon: Icons.settings_outlined,
                label: context.l10n.homeSettings,
              ),
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
        await context.push<void>(Routes.settings);
        await controller.refresh();
    }
  }

  /// 弹出“排序方式”弹窗；字段与升降序都需点击确定后应用，取消不改变现有排序。
  Future<void> _chooseSort() async {
    final preferences = controller.preferences.value;
    var selected = preferences.sort;
    var descending = preferences.descending;
    final sortOptions = _sortOptions(context.l10n);
    final confirmed = await showDialog<(EntrySort, bool)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.homeSortBy),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 每行两个：两行排布四个排序字段，窄屏也无需横向滚动。
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < sortOptions.length; index += 2)
                      Row(
                        children: [
                          for (var offset = 0; offset < 2; offset++)
                            Expanded(
                              child: index + offset < sortOptions.length
                                  ? _SortOptionTile(
                                      label: sortOptions[index + offset].$2,
                                      selected:
                                          selected ==
                                          sortOptions[index + offset].$1,
                                      fontSize: _sortOptionFontSize,
                                      onTap: () => setState(
                                        () => selected =
                                            sortOptions[index + offset].$1,
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
                      Text(context.l10n.homeSortDirection),
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
                              label: context.l10n.homeAscending,
                              value: false,
                              onTap: () => setState(() => descending = false),
                            ),
                            const SizedBox(width: 12),
                            _DirectionOption(
                              label: context.l10n.homeDescending,
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
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (selected, descending)),
              child: Text(context.l10n.commonConfirm),
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
        title: Text(context.l10n.homeScanning),
        trailing: TextButton(
          onPressed: controller.cancelSearch,
          child: Text(context.l10n.commonCancel),
        ),
      );
    }
    if (controller.searchIncomplete.value) {
      return ListTile(
        dense: true,
        leading: const Icon(Icons.info_outline),
        title: Text(context.l10n.homeSearchIncomplete),
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
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: context.l10n.homeSearchHint,
        border: InputBorder.none,
      ),
      onChanged: (value) => controller.beginSearch(value),
    ),
    actions: [
      IconButton(
        tooltip: context.l10n.homeSearchRecursive,
        onPressed: controller.searching.value || busy
            ? null
            : () => controller.searchAll(_searchText.text),
        icon: const Icon(Icons.account_tree_outlined),
      ),
      IconButton(
        tooltip: context.l10n.homeExitSearch,
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
          Text(
            context.l10n.homeChooseStorageFolder,
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: controller.busy.value ? null : controller.pickRoot,
            icon: const Icon(Icons.folder_open),
            label: Text(context.l10n.homeChooseFolder),
          ),
        ],
      ),
    ),
  );

  Widget _searchResults(bool busy) {
    if (controller.searchResults.value.isEmpty) {
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
          Center(child: Text(context.l10n.homeNoMatches)),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _listPadding,
      itemCount: controller.searchResults.value.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
      itemBuilder: (context, index) =>
          _searchRow(controller.searchResults.value[index], busy),
    );
  }

  /// 搜索结果行：注明结果位置；文件夹进入后搜索退出，可通过再次点击
  /// 搜索图标恢复关键词上下文。
  Widget _searchRow(StorageEntry entry, bool busy) {
    final location = controller.searchLocationOf(entry);
    return ListTile(
      leading: _entryIcon(entry),
      title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        context.l10n.homeLocation(location ?? context.l10n.commonUnknown),
      ),
      enabled: !busy,
      onTap: () async {
        if (entry.isDirectory) {
          await controller.enter(entry);
        } else {
          final inApp = await openEntryPreview(
            context,
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
    if (controller.entries.value.isEmpty) {
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
          Center(child: Text(context.l10n.homeEmptyFolder)),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listPadding,
        itemCount: controller.entries.value.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
        itemBuilder: (context, index) {
          final entry = controller.entries.value[index];
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
      if (!entry.isDirectory) formatBytes(entry.size, context.l10n),
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
    final checked = controller.selected.value.contains(entry.uri);
    final detail = _entryDetail(entry);
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: checked
                ? context.l10n.homeDeselect
                : context.l10n.homeSelect,
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
                child: Text(context.l10n.commonCancel),
              ),
              Expanded(
                child: Text(
                  context.l10n.homeSelectedCount(controller.selectedCount),
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: controller.toggleSelectAll,
                child:
                    controller.selectedCount ==
                            controller.entries.value.length &&
                        controller.entries.value.isNotEmpty
                    ? Text(context.l10n.homeDeselectAll)
                    : Text(context.l10n.homeSelectAll),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: context.l10n.commonDelete,
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchDelete,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: context.l10n.homeMoveTo,
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchMove,
              icon: const Icon(Icons.drive_file_move_outlined),
            ),
            IconButton(
              tooltip: context.l10n.homeBatchRename,
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchRename,
              icon: const Icon(Icons.drive_file_rename_outline),
            ),
            IconButton(
              tooltip: context.l10n.homeZipAsZip,
              onPressed: busy || controller.selectedCount == 0
                  ? null
                  : _batchZip,
              icon: const Icon(Icons.folder_zip_outlined),
            ),
            IconButton(
              tooltip: context.l10n.commonShare,
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
List<(EntrySort, String)> _sortOptions(AppLocalizations l10n) => [
  (EntrySort.name, l10n.sortByName),
  (EntrySort.modified, l10n.sortByModified),
  (EntrySort.created, l10n.sortByCreated),
  (EntrySort.size, l10n.sortBySize),
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
