// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonClose => '关闭';

  @override
  String get commonRetry => '重试';

  @override
  String get commonDelete => '删除';

  @override
  String get commonShare => '分享';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonPreview => '预览';

  @override
  String get commonBack => '返回';

  @override
  String get commonPrevious => '上一级';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonCloseSearch => '关闭搜索';

  @override
  String get commonUnknown => '未知';

  @override
  String get commonUnsavedChangesTitle => '放弃未保存的修改？';

  @override
  String get commonOpenExternal => '用其他应用打开';

  @override
  String get commonOpenExternalShort => '其他应用';

  @override
  String commonLink(String href) {
    return '链接：$href';
  }

  @override
  String get commonName => '名称';

  @override
  String get commonType => '类型';

  @override
  String get commonSize => '大小';

  @override
  String get commonLocation => '位置';

  @override
  String get commonModifiedTime => '修改时间';

  @override
  String get commonDuration => '时长';

  @override
  String get commonDimensions => '尺寸';

  @override
  String get categoryFolder => '文件夹';

  @override
  String get categoryImage => '图片';

  @override
  String get categoryVideo => '视频';

  @override
  String get categoryAudio => '音频';

  @override
  String get categoryPdf => 'PDF';

  @override
  String get categoryDocument => '文档';

  @override
  String get categorySpreadsheet => '表格';

  @override
  String get categoryPresentation => '演示文稿';

  @override
  String get categoryArchive => '压缩包';

  @override
  String get categoryApk => '安装包';

  @override
  String get categoryText => '文本';

  @override
  String get categoryCode => '代码';

  @override
  String get categoryDatabase => '数据库';

  @override
  String get categoryFont => '字体';

  @override
  String get categoryEbook => '电子书';

  @override
  String get categorySubtitle => '字幕';

  @override
  String get categoryUnknown => '未知文件';

  @override
  String get sizeUnknown => '大小未知';

  @override
  String get entryNameEmpty => '请输入有效名称';

  @override
  String get entryNameTooLong => '名称不能超过 120 个字符';

  @override
  String get entryNameInvalidChars => '名称不能含路径或控制字符';

  @override
  String renameDuplicate(String name) {
    return '与 $name 重名';
  }

  @override
  String get renameExists => '当前目录已存在同名项目';

  @override
  String get incomingShareFallbackName => '待保存文件';

  @override
  String get storageEmptyResponse => '存储响应为空';

  @override
  String get storageMoveEmptyResponse => '移动响应为空';

  @override
  String get storageCacheExportEmptyResponse => '缓存导出响应为空';

  @override
  String get storageReadEmptyResponse => '读取响应为空';

  @override
  String get storageWriteEmptyResponse => '写入响应为空';

  @override
  String get storageOperationFailed => '文件操作失败';

  @override
  String get storageOperationIncomplete => '操作未完成，请重试';

  @override
  String get errorReadOnly => '当前目录不可写入';

  @override
  String homeSavedIncomingFiles(int count, String folder) {
    return '已保存 $count 个文件到「$folder」';
  }

  @override
  String get homePickRootFirstTitle => '请先选择存储文件夹';

  @override
  String get homePickRootFirstBody => '有其他应用的文件待保存，请先授权一个文件夹作为保存位置。';

  @override
  String get homeChooseFolder => '选择文件夹';

  @override
  String get homeNewFolder => '新建文件夹';

  @override
  String get homeNewFile => '新建文件';

  @override
  String get homeRenameFolder => '重命名文件夹';

  @override
  String get homeRenameFile => '重命名文件';

  @override
  String get homeRenameShort => '重命名';

  @override
  String get homeFileName => '文件名称';

  @override
  String get homeFolderName => '文件夹名称';

  @override
  String homeDeleteForeverTitle(String name) {
    return '永久删除“$name”？';
  }

  @override
  String homeDeleteForeverCountTitle(int count) {
    return '永久删除 $count 项？';
  }

  @override
  String homeDeleteImpact(int files, int folders) {
    return '$files 个文件，$folders 个子文件夹\n删除后无法恢复。';
  }

  @override
  String get homeDeleteImpactUnknown => '无法确认目录内容，未执行删除，请刷新后重试';

  @override
  String get homeDeleteConfirm => '永久删除';

  @override
  String homeSavedCopy(String name) {
    return '已保存副本：$name';
  }

  @override
  String get homeEditImage => '编辑图片';

  @override
  String get homeEditVideo => '编辑视频';

  @override
  String get homeDetails => '详情';

  @override
  String get homeExtractToFolder => '解压到新文件夹';

  @override
  String get homeExtractToFolderSubtitle => '同名文件夹存在时自动使用新名称';

  @override
  String get homeArchiveCancelling => '正在取消归档任务…';

  @override
  String get homeRefresh => '刷新';

  @override
  String get homeDismissError => '关闭提示';

  @override
  String get homeSelectFiles => '选择文件';

  @override
  String get homeTakePhoto => '拍照';

  @override
  String get homeRecordVideo => '录制';

  @override
  String get homeSearchFiles => '搜索文件';

  @override
  String get homeExitSelection => '退出多选';

  @override
  String get homeSelection => '多选';

  @override
  String get homeMore => '更多';

  @override
  String get homeSortBy => '排序方式';

  @override
  String get homeSettings => '设置';

  @override
  String get homeSortDirection => '排序方向';

  @override
  String get homeAscending => '升序';

  @override
  String get homeDescending => '降序';

  @override
  String get homeScanning => '正在扫描子文件夹…';

  @override
  String get homeSearchIncomplete => '部分文件夹无法访问，结果不完整';

  @override
  String get homeSearchHint => '搜索文件名';

  @override
  String get homeSearchRecursive => '递归搜索子文件夹';

  @override
  String get homeExitSearch => '退出搜索';

  @override
  String get homeChooseStorageFolder => '选择存储文件夹';

  @override
  String get homeNoMatches => '没有匹配的文件';

  @override
  String homeLocation(String location) {
    return '位置：$location';
  }

  @override
  String get homeEmptyFolder => '文件夹为空';

  @override
  String get homeDeselect => '取消选择';

  @override
  String get homeSelect => '选择';

  @override
  String homeSelectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get homeDeselectAll => '取消全选';

  @override
  String get homeSelectAll => '全选';

  @override
  String get homeMoveTo => '移动到…';

  @override
  String get homeBatchRename => '批量重命名';

  @override
  String get homeZipAsZip => '压缩为 ZIP';

  @override
  String get homeMoreActions => '更多操作';

  @override
  String get sortByName => '按名称';

  @override
  String get sortByModified => '按修改时间';

  @override
  String get sortByCreated => '按创建时间';

  @override
  String get sortBySize => '按文件大小';

  @override
  String get moveCurrentUnavailable => '当前目录不可用';

  @override
  String get moveInvalidTarget => '目标位置无效';

  @override
  String get moveSameTarget => '目标位置与来源相同';

  @override
  String moveInsideFolder(String name) {
    return '目标位于所选文件夹 $name 内部';
  }

  @override
  String get moveSourceKept => '复制完成，源未删除';

  @override
  String get batchRenameInvalidPlan => '存在无效名称，已取消批量重命名';

  @override
  String get zipDialogTitle => '压缩为 ZIP';

  @override
  String get zipNameLabel => '压缩包名称';

  @override
  String get zipStart => '开始压缩';

  @override
  String get folderPickerMoveHere => '移动到此文件夹';

  @override
  String folderPickerWillMoveTo(String path) {
    return '将移动到：$path';
  }

  @override
  String get folderPickerNoSubfolders => '没有子文件夹';

  @override
  String get folderPickerBlocked => '所选项目，不能作为目标';

  @override
  String get batchRenameTitle => '批量重命名';

  @override
  String get renamePrefix => '前缀';

  @override
  String get renameSuffix => '后缀';

  @override
  String get renameFind => '查找文本';

  @override
  String get renameReplace => '替换为';

  @override
  String get renameNumbering => '使用序号（替换原名称）';

  @override
  String get renameStartNumber => '起始序号';

  @override
  String get renamePreviewHeader => '预览';

  @override
  String get renamePreviewEmpty => '请输入重命名规则';

  @override
  String get renameExecute => '执行重命名';

  @override
  String get batchKindDelete => '批量删除';

  @override
  String get batchKindMove => '批量移动';

  @override
  String get batchKindRename => '批量重命名';

  @override
  String batchProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String batchSummarySuccess(int count) {
    return '成功 $count';
  }

  @override
  String batchSummaryFailed(int count) {
    return '失败 $count';
  }

  @override
  String batchSummaryKeptSource(int count) {
    return '源未删除 $count';
  }

  @override
  String get detailsTitle => '文件详情';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsStorageFolder => '存储文件夹';

  @override
  String get settingsNotSelected => '尚未选择';

  @override
  String get settingsAppearance => '外观模式';

  @override
  String get settingsColorScheme => '主题配色';

  @override
  String get settingsEditor => '编辑器配置';

  @override
  String settingsFontSizeValue(int size) {
    return '字号 $size';
  }

  @override
  String get settingsLanguage => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get settingsCheckUpdate => '检查更新';

  @override
  String settingsVersionValue(String version) {
    return '当前版本 $version';
  }

  @override
  String get updateUpToDateTitle => '检查更新';

  @override
  String updateUpToDate(String version) {
    return '已是最新版本（$version）';
  }

  @override
  String updateAvailableTitle(String version) {
    return '发现新版本 $version';
  }

  @override
  String get updateForceHint => '此版本为强制更新，需完成后才能继续使用';

  @override
  String get updateReleaseNotes => '更新内容';

  @override
  String updatePackageSize(String size) {
    return '安装包大小：$size';
  }

  @override
  String get updateNow => '立即更新';

  @override
  String get updateLater => '稍后再说';

  @override
  String get updateCancelDownload => '取消下载';

  @override
  String updateDownloading(int percent) {
    return '正在下载 $percent%';
  }

  @override
  String get updatePrepareDownload => '正在准备下载…';

  @override
  String get updateVerifying => '正在校验安装包…';

  @override
  String get updateInstalling => '正在启动安装程序…';

  @override
  String get updateInstallLaunched => '已启动安装程序，请按系统提示完成安装';

  @override
  String get updatePermissionRequired => '请允许「FileNest」安装未知应用，然后重试';

  @override
  String get updateOpenSettings => '去设置';

  @override
  String get updateRetryInstall => '重试安装';

  @override
  String get updateCancelled => '已取消更新';

  @override
  String get updateErrorNetwork => '网络不可用，请检查网络后重试';

  @override
  String get updateErrorResponse => '服务器响应异常，请稍后重试';

  @override
  String get updateErrorNoPackage => '未找到可用的安装包，请稍后重试';

  @override
  String get updateErrorDownload => '下载失败，请重试';

  @override
  String get updateErrorHash => '安装包校验失败，请重新下载';

  @override
  String get updateErrorInstall => '无法启动安装程序，请重试';

  @override
  String get editorSectionTextCode => '文本与代码';

  @override
  String get editorSectionEditor => '编辑器';

  @override
  String get editorWrap => '自动换行';

  @override
  String get editorWrapSubtitle => '关闭后长行改为横向滚动';

  @override
  String get editorLineNumbers => '显示行号';

  @override
  String get editorTabWidth => 'Tab 缩进';

  @override
  String editorTabWidthValue(int width) {
    return '$width 个空格';
  }

  @override
  String get editorAutoIndent => '自动缩进';

  @override
  String get editorAutoIndentSubtitle => '换行时保持当前行的缩进';

  @override
  String get editorMarkdownMode => '展示模式';

  @override
  String get editorMarkdownRead => '阅读';

  @override
  String get editorMarkdownSource => '源码';

  @override
  String get editorFontSize => '字号';

  @override
  String get editorSectionMarkdown => 'Markdown';

  @override
  String get previewErrorFallback => '无法读取此文件';

  @override
  String get previewErrorNotFound => '文件或存储设备不可用';

  @override
  String get previewErrorPermission => '目录访问权限已失效，请重新选择存储文件夹';

  @override
  String get previewErrorRead => '文件读取失败';

  @override
  String get previewTruncated => '文件较大，仅显示前一部分内容';

  @override
  String get textOptions => '文本选项';

  @override
  String get codeOptions => '代码选项';

  @override
  String get textZoomIn => '增大字号';

  @override
  String get textZoomOut => '减小字号';

  @override
  String get textCopyAll => '复制全部';

  @override
  String get textCopiedAll => '已复制全部内容';

  @override
  String textDecodedAs(String encoding) {
    return '已按 $encoding 解码';
  }

  @override
  String get textSearchHint => '在文件中查找';

  @override
  String get codeSearchHint => '在代码中查找';

  @override
  String get markdownViewSource => '查看源码';

  @override
  String get markdownReadingMode => '阅读模式';

  @override
  String get markdownEditSource => '编辑源码';

  @override
  String get editorSaved => '已保存';

  @override
  String get editorSaveFailed => '保存失败，请重试';

  @override
  String get editorDiscardBody => '离开将丢失本次编辑内容。';

  @override
  String get editorKeepEditing => '继续编辑';

  @override
  String get editorDiscard => '放弃修改';

  @override
  String get editorUndo => '撤销';

  @override
  String get editorRedo => '重做';

  @override
  String get editorSave => '保存';

  @override
  String get editorOptions => '编辑选项';

  @override
  String get editorRevert => '还原修改';

  @override
  String get editorTooLarge => '文件过大，无法在应用内编辑';

  @override
  String editorPreserveEncoding(String details) {
    return '保存时保持：$details';
  }

  @override
  String get textEncodeGbkFailed => '无法按 GBK 编码保存，请使用其他应用编辑';

  @override
  String get textEncodeLatin1Failed => '内容含无法以 Latin-1 保存的字符';

  @override
  String get imageInfo => '图片信息';

  @override
  String get imageUnsupported => '无法在应用内预览此图片，可能是不受支持的格式（如 HEIC）';

  @override
  String get imageEditUnsupported => '无法在应用内编辑此图片，可能是不受支持的格式';

  @override
  String get audioCannotPlay => '无法播放此音频，文件可能已移动或格式不受支持';

  @override
  String get audioPlayFailed => '音频播放失败';

  @override
  String get audioSpeed => '播放速度';

  @override
  String get audioMute => '静音';

  @override
  String get audioUnmute => '取消静音';

  @override
  String get audioBack10 => '后退 10 秒';

  @override
  String get audioForward10 => '前进 10 秒';

  @override
  String get audioPause => '暂停';

  @override
  String get audioPlay => '播放';

  @override
  String get videoCannotPlay => '无法播放此视频，文件可能已移动或格式不受支持';

  @override
  String get videoPlayFailed => '视频播放失败';

  @override
  String videoVolume(int value) {
    return '音量 $value%';
  }

  @override
  String videoBrightness(int value) {
    return '亮度 $value%';
  }

  @override
  String get videoSpeed => '播放速度';

  @override
  String get videoEditorExporting => '正在导出视频…';

  @override
  String get videoEditorOpenFailed => '无法打开视频进行编辑';

  @override
  String get videoEditorExportFailed => '视频导出失败，请重试';

  @override
  String get videoEditorHostUnsupported => '无法在此视频上启动编辑，可能是格式不受支持';

  @override
  String get pdfNoPages => '此 PDF 没有可显示的页面';

  @override
  String pdfPageIndicator(int current, int total) {
    return '第 $current / $total 页';
  }

  @override
  String get pdfPasswordProtected => '此 PDF 受密码保护，无法在应用内预览';

  @override
  String get pdfInvalid => '无法读取此 PDF，文件可能已损坏';

  @override
  String get pdfReadFailed => '无法读取此 PDF，请稍后重试';

  @override
  String get pdfPageUnrenderable => '此页无法渲染';

  @override
  String get archiveParseFailed => '无法解析此压缩包';

  @override
  String get archiveEmpty => '压缩包为空';

  @override
  String get archiveEntryReadFailed => '无法读取该条目';

  @override
  String get archiveImagePreviewFailed => '无法预览此图片';

  @override
  String get archiveEmbeddedUnsupported => '此类型不支持内嵌预览';

  @override
  String get csvEmpty => '没有可显示的表格内容';

  @override
  String csvTruncated(int rows) {
    return '表格较大，仅显示前 $rows 行数据';
  }

  @override
  String get subtitleEmpty => '没有可显示的字幕内容';

  @override
  String get subtitleEmptyCue => '（空对白）';

  @override
  String get fontLoadFailed => '无法加载此字体文件，可能已损坏或格式不受支持';

  @override
  String get fontSample => '天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。';

  @override
  String get imageEditorPickFromDevice => '从设备选择';

  @override
  String get epubParseFailed => '无法解析此 EPUB 文件';

  @override
  String get epubInvalid => '无法解析 EPUB 文件';

  @override
  String get epubMissingContainer => 'EPUB 缺少 container.xml';

  @override
  String get epubMissingOpf => 'EPUB 缺少 OPF 清单';

  @override
  String get epubUnreadableManifest => '无法读取 EPUB 清单';

  @override
  String get epubNoSpine => 'EPUB 没有可显示的章节';

  @override
  String get epubEmptyChapters => 'EPUB 章节内容为空';

  @override
  String get epubInvalidManifest => 'EPUB 清单格式无效';

  @override
  String get epubUntitled => '未命名';

  @override
  String epubChapterTitle(int index) {
    return '第 $index 章';
  }

  @override
  String get epubToc => '目录';

  @override
  String epubChapterIndicator(int current, int total, String title) {
    return '第 $current / $total 章 · $title';
  }

  @override
  String get unsupportedPreview => '暂不支持在应用内预览此文件';

  @override
  String get archiveTaskScanningZip => '正在准备压缩…';

  @override
  String get archiveTaskScanningExtract => '正在检查压缩包…';

  @override
  String get archiveTaskScanningShare => '正在准备分享…';

  @override
  String archiveTaskProcessingZip(int count) {
    return '正在压缩：已处理 $count 项';
  }

  @override
  String archiveTaskProcessingExtract(int count) {
    return '正在解压：已完成 $count 项';
  }

  @override
  String archiveTaskProcessingShare(int count) {
    return '正在准备分享：已处理 $count 项';
  }

  @override
  String get archiveTaskCompleted => '已完成';

  @override
  String get archiveTaskCancelled => '已取消';

  @override
  String get archiveTaskFailed => '任务失败';

  @override
  String get archiveZipCancelled => '压缩已取消';

  @override
  String get archiveExtractCancelled => '解压已取消';

  @override
  String archiveZipDone(String name, int count) {
    return '已生成压缩包：$name（$count 项）';
  }

  @override
  String get archiveZipDefaultName => '压缩包';

  @override
  String archiveExtractSkipped(int extracted, int skipped) {
    return '已解压 $extracted 项，跳过 $skipped 项';
  }

  @override
  String archiveExtractDone(int count, String name) {
    return '已解压 $count 项到 $name';
  }

  @override
  String get archiveExtractDefaultFolder => '新文件夹';

  @override
  String get archiveExtractResultFallbackName => '解压结果';

  @override
  String get archiveShareReady => '分享内容已准备';

  @override
  String get archiveOutcomeFailed => '归档任务失败';

  @override
  String get archiveNoEntries => '没有可压缩的条目';

  @override
  String get archiveBusyZip => '已有归档任务在进行，请等待完成或取消';

  @override
  String get archiveBusyShare => '已有归档任务在进行，请稍后再分享';

  @override
  String get archiveEmptyResponse => '归档响应为空';

  @override
  String get archiveZipFailed => '压缩失败，请重试';

  @override
  String get archiveExtractEmptyResponse => '解压响应为空';

  @override
  String get archiveExtractFailed => '解压失败，请检查压缩包是否完整';

  @override
  String get shareCancelled => '分享已取消';

  @override
  String get shareNoApp => '未找到可接收分享的应用';

  @override
  String get shareOpened => '已打开系统分享';

  @override
  String get shareFailed => '分享失败，请重试';

  @override
  String get shareNoContent => '没有可分享的内容';

  @override
  String get shareCacheFailed => '分享缓存准备失败';

  @override
  String get shareEmptyResponse => '分享响应为空';

  @override
  String shareTitle(String name) {
    return '分享 $name';
  }
}
