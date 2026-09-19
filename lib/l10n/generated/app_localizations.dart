import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get commonShare;

  /// No description provided for @commonEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get commonEdit;

  /// No description provided for @commonPreview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get commonPreview;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonPrevious.
  ///
  /// In zh, this message translates to:
  /// **'上一级'**
  String get commonPrevious;

  /// No description provided for @commonSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get commonSearch;

  /// No description provided for @commonCloseSearch.
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get commonCloseSearch;

  /// No description provided for @commonUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get commonUnknown;

  /// No description provided for @commonUnsavedChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃未保存的修改？'**
  String get commonUnsavedChangesTitle;

  /// No description provided for @commonOpenExternal.
  ///
  /// In zh, this message translates to:
  /// **'用其他应用打开'**
  String get commonOpenExternal;

  /// No description provided for @commonOpenExternalShort.
  ///
  /// In zh, this message translates to:
  /// **'其他应用'**
  String get commonOpenExternalShort;

  /// No description provided for @commonLink.
  ///
  /// In zh, this message translates to:
  /// **'链接：{href}'**
  String commonLink(String href);

  /// No description provided for @commonName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get commonName;

  /// No description provided for @commonType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get commonType;

  /// No description provided for @commonSize.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get commonSize;

  /// No description provided for @commonLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get commonLocation;

  /// No description provided for @commonModifiedTime.
  ///
  /// In zh, this message translates to:
  /// **'修改时间'**
  String get commonModifiedTime;

  /// No description provided for @commonDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get commonDuration;

  /// No description provided for @commonDimensions.
  ///
  /// In zh, this message translates to:
  /// **'尺寸'**
  String get commonDimensions;

  /// No description provided for @categoryFolder.
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get categoryFolder;

  /// No description provided for @categoryImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get categoryImage;

  /// No description provided for @categoryVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get categoryVideo;

  /// No description provided for @categoryAudio.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get categoryAudio;

  /// No description provided for @categoryPdf.
  ///
  /// In zh, this message translates to:
  /// **'PDF'**
  String get categoryPdf;

  /// No description provided for @categoryDocument.
  ///
  /// In zh, this message translates to:
  /// **'文档'**
  String get categoryDocument;

  /// No description provided for @categorySpreadsheet.
  ///
  /// In zh, this message translates to:
  /// **'表格'**
  String get categorySpreadsheet;

  /// No description provided for @categoryPresentation.
  ///
  /// In zh, this message translates to:
  /// **'演示文稿'**
  String get categoryPresentation;

  /// No description provided for @categoryArchive.
  ///
  /// In zh, this message translates to:
  /// **'压缩包'**
  String get categoryArchive;

  /// No description provided for @categoryApk.
  ///
  /// In zh, this message translates to:
  /// **'安装包'**
  String get categoryApk;

  /// No description provided for @categoryText.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get categoryText;

  /// No description provided for @categoryCode.
  ///
  /// In zh, this message translates to:
  /// **'代码'**
  String get categoryCode;

  /// No description provided for @categoryDatabase.
  ///
  /// In zh, this message translates to:
  /// **'数据库'**
  String get categoryDatabase;

  /// No description provided for @categoryFont.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get categoryFont;

  /// No description provided for @categoryEbook.
  ///
  /// In zh, this message translates to:
  /// **'电子书'**
  String get categoryEbook;

  /// No description provided for @categorySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get categorySubtitle;

  /// No description provided for @categoryUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知文件'**
  String get categoryUnknown;

  /// No description provided for @sizeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'大小未知'**
  String get sizeUnknown;

  /// No description provided for @entryNameEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效名称'**
  String get entryNameEmpty;

  /// No description provided for @entryNameTooLong.
  ///
  /// In zh, this message translates to:
  /// **'名称不能超过 120 个字符'**
  String get entryNameTooLong;

  /// No description provided for @entryNameInvalidChars.
  ///
  /// In zh, this message translates to:
  /// **'名称不能含路径或控制字符'**
  String get entryNameInvalidChars;

  /// No description provided for @renameDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'与 {name} 重名'**
  String renameDuplicate(String name);

  /// No description provided for @renameExists.
  ///
  /// In zh, this message translates to:
  /// **'当前目录已存在同名项目'**
  String get renameExists;

  /// No description provided for @incomingShareFallbackName.
  ///
  /// In zh, this message translates to:
  /// **'待保存文件'**
  String get incomingShareFallbackName;

  /// No description provided for @storageEmptyResponse.
  ///
  /// In zh, this message translates to:
  /// **'存储响应为空'**
  String get storageEmptyResponse;

  /// No description provided for @storageMoveEmptyResponse.
  ///
  /// In zh, this message translates to:
  /// **'移动响应为空'**
  String get storageMoveEmptyResponse;

  /// No description provided for @storageCacheExportEmptyResponse.
  ///
  /// In zh, this message translates to:
  /// **'缓存导出响应为空'**
  String get storageCacheExportEmptyResponse;

  /// No description provided for @storageReadEmptyResponse.
  ///
  /// In zh, this message translates to:
  /// **'读取响应为空'**
  String get storageReadEmptyResponse;

  /// No description provided for @storageWriteEmptyResponse.
  ///
  /// In zh, this message translates to:
  /// **'写入响应为空'**
  String get storageWriteEmptyResponse;

  /// No description provided for @storageOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'文件操作失败'**
  String get storageOperationFailed;

  /// No description provided for @storageOperationIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'操作未完成，请重试'**
  String get storageOperationIncomplete;

  /// No description provided for @errorReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'当前目录不可写入'**
  String get errorReadOnly;

  /// No description provided for @homeSavedIncomingFiles.
  ///
  /// In zh, this message translates to:
  /// **'已保存 {count} 个文件到「{folder}」'**
  String homeSavedIncomingFiles(int count, String folder);

  /// No description provided for @homePickRootFirstTitle.
  ///
  /// In zh, this message translates to:
  /// **'请先选择存储文件夹'**
  String get homePickRootFirstTitle;

  /// No description provided for @homePickRootFirstBody.
  ///
  /// In zh, this message translates to:
  /// **'有其他应用的文件待保存，请先授权一个文件夹作为保存位置。'**
  String get homePickRootFirstBody;

  /// No description provided for @homeChooseFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择文件夹'**
  String get homeChooseFolder;

  /// No description provided for @homeNewFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get homeNewFolder;

  /// No description provided for @homeNewFile.
  ///
  /// In zh, this message translates to:
  /// **'新建文件'**
  String get homeNewFile;

  /// No description provided for @homeRenameFolder.
  ///
  /// In zh, this message translates to:
  /// **'重命名文件夹'**
  String get homeRenameFolder;

  /// No description provided for @homeRenameFile.
  ///
  /// In zh, this message translates to:
  /// **'重命名文件'**
  String get homeRenameFile;

  /// No description provided for @homeRenameShort.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get homeRenameShort;

  /// No description provided for @homeFileName.
  ///
  /// In zh, this message translates to:
  /// **'文件名称'**
  String get homeFileName;

  /// No description provided for @homeFolderName.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称'**
  String get homeFolderName;

  /// No description provided for @homeDeleteForeverTitle.
  ///
  /// In zh, this message translates to:
  /// **'永久删除“{name}”？'**
  String homeDeleteForeverTitle(String name);

  /// No description provided for @homeDeleteForeverCountTitle.
  ///
  /// In zh, this message translates to:
  /// **'永久删除 {count} 项？'**
  String homeDeleteForeverCountTitle(int count);

  /// No description provided for @homeDeleteImpact.
  ///
  /// In zh, this message translates to:
  /// **'{files} 个文件，{folders} 个子文件夹\n删除后无法恢复。'**
  String homeDeleteImpact(int files, int folders);

  /// No description provided for @homeDeleteImpactUnknown.
  ///
  /// In zh, this message translates to:
  /// **'无法确认目录内容，未执行删除，请刷新后重试'**
  String get homeDeleteImpactUnknown;

  /// No description provided for @homeDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get homeDeleteConfirm;

  /// No description provided for @homeSavedCopy.
  ///
  /// In zh, this message translates to:
  /// **'已保存副本：{name}'**
  String homeSavedCopy(String name);

  /// No description provided for @homeEditImage.
  ///
  /// In zh, this message translates to:
  /// **'编辑图片'**
  String get homeEditImage;

  /// No description provided for @homeEditImageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'另存为新文件，原图保留'**
  String get homeEditImageSubtitle;

  /// No description provided for @homeEditVideo.
  ///
  /// In zh, this message translates to:
  /// **'编辑视频'**
  String get homeEditVideo;

  /// No description provided for @homeEditVideoSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'另存为新文件，原视频保留'**
  String get homeEditVideoSubtitle;

  /// No description provided for @homeDetails.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get homeDetails;

  /// No description provided for @homeExtractToFolder.
  ///
  /// In zh, this message translates to:
  /// **'解压到新文件夹'**
  String get homeExtractToFolder;

  /// No description provided for @homeExtractToFolderSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'同名文件夹存在时自动使用新名称'**
  String get homeExtractToFolderSubtitle;

  /// No description provided for @homeArchiveCancelling.
  ///
  /// In zh, this message translates to:
  /// **'正在取消归档任务…'**
  String get homeArchiveCancelling;

  /// No description provided for @homeRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get homeRefresh;

  /// No description provided for @homeDismissError.
  ///
  /// In zh, this message translates to:
  /// **'关闭提示'**
  String get homeDismissError;

  /// No description provided for @homeSelectFiles.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get homeSelectFiles;

  /// No description provided for @homeTakePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get homeTakePhoto;

  /// No description provided for @homeRecordVideo.
  ///
  /// In zh, this message translates to:
  /// **'录制'**
  String get homeRecordVideo;

  /// No description provided for @homeSearchFiles.
  ///
  /// In zh, this message translates to:
  /// **'搜索文件'**
  String get homeSearchFiles;

  /// No description provided for @homeExitSelection.
  ///
  /// In zh, this message translates to:
  /// **'退出多选'**
  String get homeExitSelection;

  /// No description provided for @homeSelection.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get homeSelection;

  /// No description provided for @homeMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get homeMore;

  /// No description provided for @homeSortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get homeSortBy;

  /// No description provided for @homeSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get homeSettings;

  /// No description provided for @homeSortDirection.
  ///
  /// In zh, this message translates to:
  /// **'排序方向'**
  String get homeSortDirection;

  /// No description provided for @homeAscending.
  ///
  /// In zh, this message translates to:
  /// **'升序'**
  String get homeAscending;

  /// No description provided for @homeDescending.
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get homeDescending;

  /// No description provided for @homeScanning.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描子文件夹…'**
  String get homeScanning;

  /// No description provided for @homeSearchIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'部分文件夹无法访问，结果不完整'**
  String get homeSearchIncomplete;

  /// No description provided for @homeSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索文件名'**
  String get homeSearchHint;

  /// No description provided for @homeSearchRecursive.
  ///
  /// In zh, this message translates to:
  /// **'递归搜索子文件夹'**
  String get homeSearchRecursive;

  /// No description provided for @homeExitSearch.
  ///
  /// In zh, this message translates to:
  /// **'退出搜索'**
  String get homeExitSearch;

  /// No description provided for @homeChooseStorageFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择存储文件夹'**
  String get homeChooseStorageFolder;

  /// No description provided for @homeNoMatches.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的文件'**
  String get homeNoMatches;

  /// No description provided for @homeLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置：{location}'**
  String homeLocation(String location);

  /// No description provided for @homeEmptyFolder.
  ///
  /// In zh, this message translates to:
  /// **'文件夹为空'**
  String get homeEmptyFolder;

  /// No description provided for @homeDeselect.
  ///
  /// In zh, this message translates to:
  /// **'取消选择'**
  String get homeDeselect;

  /// No description provided for @homeSelect.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get homeSelect;

  /// No description provided for @homeSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String homeSelectedCount(int count);

  /// No description provided for @homeDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get homeDeselectAll;

  /// No description provided for @homeSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get homeSelectAll;

  /// No description provided for @homeMoveTo.
  ///
  /// In zh, this message translates to:
  /// **'移动到…'**
  String get homeMoveTo;

  /// No description provided for @homeBatchRename.
  ///
  /// In zh, this message translates to:
  /// **'批量重命名'**
  String get homeBatchRename;

  /// No description provided for @homeZipAsZip.
  ///
  /// In zh, this message translates to:
  /// **'压缩为 ZIP'**
  String get homeZipAsZip;

  /// No description provided for @homeMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get homeMoreActions;

  /// No description provided for @sortByName.
  ///
  /// In zh, this message translates to:
  /// **'按名称'**
  String get sortByName;

  /// No description provided for @sortByModified.
  ///
  /// In zh, this message translates to:
  /// **'按修改时间'**
  String get sortByModified;

  /// No description provided for @sortByCreated.
  ///
  /// In zh, this message translates to:
  /// **'按创建时间'**
  String get sortByCreated;

  /// No description provided for @sortBySize.
  ///
  /// In zh, this message translates to:
  /// **'按文件大小'**
  String get sortBySize;

  /// No description provided for @moveCurrentUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前目录不可用'**
  String get moveCurrentUnavailable;

  /// No description provided for @moveInvalidTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标位置无效'**
  String get moveInvalidTarget;

  /// No description provided for @moveSameTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标位置与来源相同'**
  String get moveSameTarget;

  /// No description provided for @moveInsideFolder.
  ///
  /// In zh, this message translates to:
  /// **'目标位于所选文件夹 {name} 内部'**
  String moveInsideFolder(String name);

  /// No description provided for @moveSourceKept.
  ///
  /// In zh, this message translates to:
  /// **'复制完成，源未删除'**
  String get moveSourceKept;

  /// No description provided for @batchRenameInvalidPlan.
  ///
  /// In zh, this message translates to:
  /// **'存在无效名称，已取消批量重命名'**
  String get batchRenameInvalidPlan;

  /// No description provided for @zipDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'压缩为 ZIP'**
  String get zipDialogTitle;

  /// No description provided for @zipNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'压缩包名称'**
  String get zipNameLabel;

  /// No description provided for @zipStart.
  ///
  /// In zh, this message translates to:
  /// **'开始压缩'**
  String get zipStart;

  /// No description provided for @folderPickerMoveHere.
  ///
  /// In zh, this message translates to:
  /// **'移动到此文件夹'**
  String get folderPickerMoveHere;

  /// No description provided for @folderPickerWillMoveTo.
  ///
  /// In zh, this message translates to:
  /// **'将移动到：{path}'**
  String folderPickerWillMoveTo(String path);

  /// No description provided for @folderPickerNoSubfolders.
  ///
  /// In zh, this message translates to:
  /// **'没有子文件夹'**
  String get folderPickerNoSubfolders;

  /// No description provided for @folderPickerBlocked.
  ///
  /// In zh, this message translates to:
  /// **'所选项目，不能作为目标'**
  String get folderPickerBlocked;

  /// No description provided for @batchRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量重命名'**
  String get batchRenameTitle;

  /// No description provided for @renamePrefix.
  ///
  /// In zh, this message translates to:
  /// **'前缀'**
  String get renamePrefix;

  /// No description provided for @renameSuffix.
  ///
  /// In zh, this message translates to:
  /// **'后缀'**
  String get renameSuffix;

  /// No description provided for @renameFind.
  ///
  /// In zh, this message translates to:
  /// **'查找文本'**
  String get renameFind;

  /// No description provided for @renameReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换为'**
  String get renameReplace;

  /// No description provided for @renameNumbering.
  ///
  /// In zh, this message translates to:
  /// **'使用序号（替换原名称）'**
  String get renameNumbering;

  /// No description provided for @renameStartNumber.
  ///
  /// In zh, this message translates to:
  /// **'起始序号'**
  String get renameStartNumber;

  /// No description provided for @renamePreviewHeader.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get renamePreviewHeader;

  /// No description provided for @renamePreviewEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请输入重命名规则'**
  String get renamePreviewEmpty;

  /// No description provided for @renameExecute.
  ///
  /// In zh, this message translates to:
  /// **'执行重命名'**
  String get renameExecute;

  /// No description provided for @batchKindDelete.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get batchKindDelete;

  /// No description provided for @batchKindMove.
  ///
  /// In zh, this message translates to:
  /// **'批量移动'**
  String get batchKindMove;

  /// No description provided for @batchKindRename.
  ///
  /// In zh, this message translates to:
  /// **'批量重命名'**
  String get batchKindRename;

  /// No description provided for @batchProgress.
  ///
  /// In zh, this message translates to:
  /// **'{done}/{total}'**
  String batchProgress(int done, int total);

  /// No description provided for @batchSummarySuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功 {count}'**
  String batchSummarySuccess(int count);

  /// No description provided for @batchSummaryFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败 {count}'**
  String batchSummaryFailed(int count);

  /// No description provided for @batchSummaryKeptSource.
  ///
  /// In zh, this message translates to:
  /// **'源未删除 {count}'**
  String batchSummaryKeptSource(int count);

  /// No description provided for @detailsTitle.
  ///
  /// In zh, this message translates to:
  /// **'文件详情'**
  String get detailsTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsStorageFolder.
  ///
  /// In zh, this message translates to:
  /// **'存储文件夹'**
  String get settingsStorageFolder;

  /// No description provided for @settingsNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'尚未选择'**
  String get settingsNotSelected;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观模式'**
  String get settingsAppearance;

  /// No description provided for @settingsColorScheme.
  ///
  /// In zh, this message translates to:
  /// **'主题配色'**
  String get settingsColorScheme;

  /// No description provided for @settingsEditor.
  ///
  /// In zh, this message translates to:
  /// **'编辑器配置'**
  String get settingsEditor;

  /// No description provided for @settingsFontSizeValue.
  ///
  /// In zh, this message translates to:
  /// **'字号 {size}'**
  String settingsFontSizeValue(int size);

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// No description provided for @editorSectionTextCode.
  ///
  /// In zh, this message translates to:
  /// **'文本与代码'**
  String get editorSectionTextCode;

  /// No description provided for @editorSectionEditor.
  ///
  /// In zh, this message translates to:
  /// **'编辑器'**
  String get editorSectionEditor;

  /// No description provided for @editorWrap.
  ///
  /// In zh, this message translates to:
  /// **'自动换行'**
  String get editorWrap;

  /// No description provided for @editorWrapSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后长行改为横向滚动'**
  String get editorWrapSubtitle;

  /// No description provided for @editorLineNumbers.
  ///
  /// In zh, this message translates to:
  /// **'显示行号'**
  String get editorLineNumbers;

  /// No description provided for @editorTabWidth.
  ///
  /// In zh, this message translates to:
  /// **'Tab 缩进'**
  String get editorTabWidth;

  /// No description provided for @editorTabWidthValue.
  ///
  /// In zh, this message translates to:
  /// **'{width} 个空格'**
  String editorTabWidthValue(int width);

  /// No description provided for @editorAutoIndent.
  ///
  /// In zh, this message translates to:
  /// **'自动缩进'**
  String get editorAutoIndent;

  /// No description provided for @editorAutoIndentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'换行时保持当前行的缩进'**
  String get editorAutoIndentSubtitle;

  /// No description provided for @editorMarkdownMode.
  ///
  /// In zh, this message translates to:
  /// **'展示模式'**
  String get editorMarkdownMode;

  /// No description provided for @editorMarkdownRead.
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get editorMarkdownRead;

  /// No description provided for @editorMarkdownSource.
  ///
  /// In zh, this message translates to:
  /// **'源码'**
  String get editorMarkdownSource;

  /// No description provided for @editorFontSize.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get editorFontSize;

  /// No description provided for @editorSectionMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'Markdown'**
  String get editorSectionMarkdown;

  /// No description provided for @previewErrorFallback.
  ///
  /// In zh, this message translates to:
  /// **'无法读取此文件'**
  String get previewErrorFallback;

  /// No description provided for @previewErrorNotFound.
  ///
  /// In zh, this message translates to:
  /// **'文件或存储设备不可用'**
  String get previewErrorNotFound;

  /// No description provided for @previewErrorPermission.
  ///
  /// In zh, this message translates to:
  /// **'目录访问权限已失效，请重新选择存储文件夹'**
  String get previewErrorPermission;

  /// No description provided for @previewErrorRead.
  ///
  /// In zh, this message translates to:
  /// **'文件读取失败'**
  String get previewErrorRead;

  /// No description provided for @previewTruncated.
  ///
  /// In zh, this message translates to:
  /// **'文件较大，仅显示前一部分内容'**
  String get previewTruncated;

  /// No description provided for @textOptions.
  ///
  /// In zh, this message translates to:
  /// **'文本选项'**
  String get textOptions;

  /// No description provided for @codeOptions.
  ///
  /// In zh, this message translates to:
  /// **'代码选项'**
  String get codeOptions;

  /// No description provided for @textZoomIn.
  ///
  /// In zh, this message translates to:
  /// **'增大字号'**
  String get textZoomIn;

  /// No description provided for @textZoomOut.
  ///
  /// In zh, this message translates to:
  /// **'减小字号'**
  String get textZoomOut;

  /// No description provided for @textCopyAll.
  ///
  /// In zh, this message translates to:
  /// **'复制全部'**
  String get textCopyAll;

  /// No description provided for @textCopiedAll.
  ///
  /// In zh, this message translates to:
  /// **'已复制全部内容'**
  String get textCopiedAll;

  /// No description provided for @textDecodedAs.
  ///
  /// In zh, this message translates to:
  /// **'已按 {encoding} 解码'**
  String textDecodedAs(String encoding);

  /// No description provided for @textSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'在文件中查找'**
  String get textSearchHint;

  /// No description provided for @codeSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'在代码中查找'**
  String get codeSearchHint;

  /// No description provided for @markdownViewSource.
  ///
  /// In zh, this message translates to:
  /// **'查看源码'**
  String get markdownViewSource;

  /// No description provided for @markdownReadingMode.
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get markdownReadingMode;

  /// No description provided for @markdownEditSource.
  ///
  /// In zh, this message translates to:
  /// **'编辑源码'**
  String get markdownEditSource;

  /// No description provided for @editorSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get editorSaved;

  /// No description provided for @editorSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get editorSaveFailed;

  /// No description provided for @editorDiscardBody.
  ///
  /// In zh, this message translates to:
  /// **'离开将丢失本次编辑内容。'**
  String get editorDiscardBody;

  /// No description provided for @editorKeepEditing.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get editorKeepEditing;

  /// No description provided for @editorDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改'**
  String get editorDiscard;

  /// No description provided for @editorUndo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get editorUndo;

  /// No description provided for @editorRedo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get editorRedo;

  /// No description provided for @editorSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get editorSave;

  /// No description provided for @editorOptions.
  ///
  /// In zh, this message translates to:
  /// **'编辑选项'**
  String get editorOptions;

  /// No description provided for @editorRevert.
  ///
  /// In zh, this message translates to:
  /// **'还原修改'**
  String get editorRevert;

  /// No description provided for @editorTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'文件过大，无法在应用内编辑'**
  String get editorTooLarge;

  /// No description provided for @editorPreserveEncoding.
  ///
  /// In zh, this message translates to:
  /// **'保存时保持：{details}'**
  String editorPreserveEncoding(String details);

  /// No description provided for @textEncodeGbkFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法按 GBK 编码保存，请使用其他应用编辑'**
  String get textEncodeGbkFailed;

  /// No description provided for @textEncodeLatin1Failed.
  ///
  /// In zh, this message translates to:
  /// **'内容含无法以 Latin-1 保存的字符'**
  String get textEncodeLatin1Failed;

  /// No description provided for @imageInfo.
  ///
  /// In zh, this message translates to:
  /// **'图片信息'**
  String get imageInfo;

  /// No description provided for @imageUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'无法在应用内预览此图片，可能是不受支持的格式（如 HEIC）'**
  String get imageUnsupported;

  /// No description provided for @imageEditUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'无法在应用内编辑此图片，可能是不受支持的格式'**
  String get imageEditUnsupported;

  /// No description provided for @audioCannotPlay.
  ///
  /// In zh, this message translates to:
  /// **'无法播放此音频，文件可能已移动或格式不受支持'**
  String get audioCannotPlay;

  /// No description provided for @audioPlayFailed.
  ///
  /// In zh, this message translates to:
  /// **'音频播放失败'**
  String get audioPlayFailed;

  /// No description provided for @audioSpeed.
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get audioSpeed;

  /// No description provided for @audioMute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get audioMute;

  /// No description provided for @audioUnmute.
  ///
  /// In zh, this message translates to:
  /// **'取消静音'**
  String get audioUnmute;

  /// No description provided for @audioBack10.
  ///
  /// In zh, this message translates to:
  /// **'后退 10 秒'**
  String get audioBack10;

  /// No description provided for @audioForward10.
  ///
  /// In zh, this message translates to:
  /// **'前进 10 秒'**
  String get audioForward10;

  /// No description provided for @audioPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get audioPause;

  /// No description provided for @audioPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get audioPlay;

  /// No description provided for @videoCannotPlay.
  ///
  /// In zh, this message translates to:
  /// **'无法播放此视频，文件可能已移动或格式不受支持'**
  String get videoCannotPlay;

  /// No description provided for @videoPlayFailed.
  ///
  /// In zh, this message translates to:
  /// **'视频播放失败'**
  String get videoPlayFailed;

  /// No description provided for @videoVolume.
  ///
  /// In zh, this message translates to:
  /// **'音量 {value}%'**
  String videoVolume(int value);

  /// No description provided for @videoBrightness.
  ///
  /// In zh, this message translates to:
  /// **'亮度 {value}%'**
  String videoBrightness(int value);

  /// No description provided for @videoSpeed.
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get videoSpeed;

  /// No description provided for @videoEditorAddMusicTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加背景音乐？'**
  String get videoEditorAddMusicTitle;

  /// No description provided for @videoEditorAddMusicBody.
  ///
  /// In zh, this message translates to:
  /// **'可从设备选择音频文件，在编辑器中叠加到视频上。'**
  String get videoEditorAddMusicBody;

  /// No description provided for @videoEditorSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get videoEditorSkip;

  /// No description provided for @videoEditorChooseAudio.
  ///
  /// In zh, this message translates to:
  /// **'选择音频'**
  String get videoEditorChooseAudio;

  /// No description provided for @videoEditorExporting.
  ///
  /// In zh, this message translates to:
  /// **'正在导出视频…'**
  String get videoEditorExporting;

  /// No description provided for @videoEditorOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开视频进行编辑'**
  String get videoEditorOpenFailed;

  /// No description provided for @videoEditorExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'视频导出失败，请重试'**
  String get videoEditorExportFailed;

  /// No description provided for @videoEditorHostUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'无法在此视频上启动编辑，可能是格式不受支持'**
  String get videoEditorHostUnsupported;

  /// No description provided for @pdfNoPages.
  ///
  /// In zh, this message translates to:
  /// **'此 PDF 没有可显示的页面'**
  String get pdfNoPages;

  /// No description provided for @pdfPageIndicator.
  ///
  /// In zh, this message translates to:
  /// **'第 {current} / {total} 页'**
  String pdfPageIndicator(int current, int total);

  /// No description provided for @pdfPasswordProtected.
  ///
  /// In zh, this message translates to:
  /// **'此 PDF 受密码保护，无法在应用内预览'**
  String get pdfPasswordProtected;

  /// No description provided for @pdfInvalid.
  ///
  /// In zh, this message translates to:
  /// **'无法读取此 PDF，文件可能已损坏'**
  String get pdfInvalid;

  /// No description provided for @pdfReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取此 PDF，请稍后重试'**
  String get pdfReadFailed;

  /// No description provided for @pdfPageUnrenderable.
  ///
  /// In zh, this message translates to:
  /// **'此页无法渲染'**
  String get pdfPageUnrenderable;

  /// No description provided for @archiveParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法解析此压缩包'**
  String get archiveParseFailed;

  /// No description provided for @archiveEmpty.
  ///
  /// In zh, this message translates to:
  /// **'压缩包为空'**
  String get archiveEmpty;

  /// No description provided for @archiveEntryReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取该条目'**
  String get archiveEntryReadFailed;

  /// No description provided for @archiveImagePreviewFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法预览此图片'**
  String get archiveImagePreviewFailed;

  /// No description provided for @archiveEmbeddedUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'此类型不支持内嵌预览'**
  String get archiveEmbeddedUnsupported;

  /// No description provided for @csvEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可显示的表格内容'**
  String get csvEmpty;

  /// No description provided for @csvTruncated.
  ///
  /// In zh, this message translates to:
  /// **'表格较大，仅显示前 {rows} 行数据'**
  String csvTruncated(int rows);

  /// No description provided for @subtitleEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可显示的字幕内容'**
  String get subtitleEmpty;

  /// No description provided for @subtitleEmptyCue.
  ///
  /// In zh, this message translates to:
  /// **'（空对白）'**
  String get subtitleEmptyCue;

  /// No description provided for @fontLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法加载此字体文件，可能已损坏或格式不受支持'**
  String get fontLoadFailed;

  /// No description provided for @fontSample.
  ///
  /// In zh, this message translates to:
  /// **'天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。'**
  String get fontSample;

  /// No description provided for @imageEditorPickFromDevice.
  ///
  /// In zh, this message translates to:
  /// **'从设备选择'**
  String get imageEditorPickFromDevice;

  /// No description provided for @epubParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法解析此 EPUB 文件'**
  String get epubParseFailed;

  /// No description provided for @epubInvalid.
  ///
  /// In zh, this message translates to:
  /// **'无法解析 EPUB 文件'**
  String get epubInvalid;

  /// No description provided for @epubMissingContainer.
  ///
  /// In zh, this message translates to:
  /// **'EPUB 缺少 container.xml'**
  String get epubMissingContainer;

  /// No description provided for @epubMissingOpf.
  ///
  /// In zh, this message translates to:
  /// **'EPUB 缺少 OPF 清单'**
  String get epubMissingOpf;

  /// No description provided for @epubUnreadableManifest.
  ///
  /// In zh, this message translates to:
  /// **'无法读取 EPUB 清单'**
  String get epubUnreadableManifest;

  /// No description provided for @epubNoSpine.
  ///
  /// In zh, this message translates to:
  /// **'EPUB 没有可显示的章节'**
  String get epubNoSpine;

  /// No description provided for @epubEmptyChapters.
  ///
  /// In zh, this message translates to:
  /// **'EPUB 章节内容为空'**
  String get epubEmptyChapters;

  /// No description provided for @epubInvalidManifest.
  ///
  /// In zh, this message translates to:
  /// **'EPUB 清单格式无效'**
  String get epubInvalidManifest;

  /// No description provided for @epubUntitled.
  ///
  /// In zh, this message translates to:
  /// **'未命名'**
  String get epubUntitled;

  /// No description provided for @epubChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 章'**
  String epubChapterTitle(int index);

  /// No description provided for @epubToc.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get epubToc;

  /// No description provided for @epubChapterIndicator.
  ///
  /// In zh, this message translates to:
  /// **'第 {current} / {total} 章 · {title}'**
  String epubChapterIndicator(int current, int total, String title);

  /// No description provided for @unsupportedPreview.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持在应用内预览此文件'**
  String get unsupportedPreview;

  /// No description provided for @archiveTaskScanningZip.
  ///
  /// In zh, this message translates to:
  /// **'正在准备压缩…'**
  String get archiveTaskScanningZip;

  /// No description provided for @archiveTaskScanningExtract.
  ///
  /// In zh, this message translates to:
  /// **'正在检查压缩包…'**
  String get archiveTaskScanningExtract;

  /// No description provided for @archiveTaskScanningShare.
  ///
  /// In zh, this message translates to:
  /// **'正在准备分享…'**
  String get archiveTaskScanningShare;

  /// No description provided for @archiveTaskProcessingZip.
  ///
  /// In zh, this message translates to:
  /// **'正在压缩：已处理 {count} 项'**
  String archiveTaskProcessingZip(int count);

  /// No description provided for @archiveTaskProcessingExtract.
  ///
  /// In zh, this message translates to:
  /// **'正在解压：已完成 {count} 项'**
  String archiveTaskProcessingExtract(int count);

  /// No description provided for @archiveTaskProcessingShare.
  ///
  /// In zh, this message translates to:
  /// **'正在准备分享：已处理 {count} 项'**
  String archiveTaskProcessingShare(int count);

  /// No description provided for @archiveTaskCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get archiveTaskCompleted;

  /// No description provided for @archiveTaskCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get archiveTaskCancelled;

  /// No description provided for @archiveTaskFailed.
  ///
  /// In zh, this message translates to:
  /// **'任务失败'**
  String get archiveTaskFailed;

  /// No description provided for @archiveZipCancelled.
  ///
  /// In zh, this message translates to:
  /// **'压缩已取消'**
  String get archiveZipCancelled;

  /// No description provided for @archiveExtractCancelled.
  ///
  /// In zh, this message translates to:
  /// **'解压已取消'**
  String get archiveExtractCancelled;

  /// No description provided for @archiveZipDone.
  ///
  /// In zh, this message translates to:
  /// **'已生成压缩包：{name}（{count} 项）'**
  String archiveZipDone(String name, int count);

  /// No description provided for @archiveZipDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'压缩包'**
  String get archiveZipDefaultName;

  /// No description provided for @archiveExtractSkipped.
  ///
  /// In zh, this message translates to:
  /// **'已解压 {extracted} 项，跳过 {skipped} 项'**
  String archiveExtractSkipped(int extracted, int skipped);

  /// No description provided for @archiveExtractDone.
  ///
  /// In zh, this message translates to:
  /// **'已解压 {count} 项到 {name}'**
  String archiveExtractDone(int count, String name);

  /// No description provided for @archiveExtractDefaultFolder.
  ///
  /// In zh, this message translates to:
  /// **'新文件夹'**
  String get archiveExtractDefaultFolder;

  /// No description provided for @archiveExtractResultFallbackName.
  ///
  /// In zh, this message translates to:
  /// **'解压结果'**
  String get archiveExtractResultFallbackName;

  /// No description provided for @archiveShareReady.
  ///
  /// In zh, this message translates to:
  /// **'分享内容已准备'**
  String get archiveShareReady;

  /// No description provided for @archiveOutcomeFailed.
  ///
  /// In zh, this message translates to:
  /// **'归档任务失败'**
  String get archiveOutcomeFailed;

  /// No description provided for @archiveNoEntries.
  ///
  /// In zh, this message translates to:
  /// **'没有可压缩的条目'**
  String get archiveNoEntries;

  /// No description provided for @archiveBusyZip.
  ///
  /// In zh, this message translates to:
  /// **'已有归档任务在进行，请等待完成或取消'**
  String get archiveBusyZip;

  /// No description provided for @archiveBusyShare.
  ///
  /// In zh, this message translates to:
  /// **'已有归档任务在进行，请稍后再分享'**
  String get archiveBusyShare;

  /// No description provided for @archiveEmptyResponse.
  ///
  /// In zh, this message translates to:
  /// **'归档响应为空'**
  String get archiveEmptyResponse;

  /// No description provided for @archiveZipFailed.
  ///
  /// In zh, this message translates to:
  /// **'压缩失败，请重试'**
  String get archiveZipFailed;

  /// No description provided for @archiveExtractEmptyResponse.
  ///
  /// In zh, this message translates to:
  /// **'解压响应为空'**
  String get archiveExtractEmptyResponse;

  /// No description provided for @archiveExtractFailed.
  ///
  /// In zh, this message translates to:
  /// **'解压失败，请检查压缩包是否完整'**
  String get archiveExtractFailed;

  /// No description provided for @shareCancelled.
  ///
  /// In zh, this message translates to:
  /// **'分享已取消'**
  String get shareCancelled;

  /// No description provided for @shareNoApp.
  ///
  /// In zh, this message translates to:
  /// **'未找到可接收分享的应用'**
  String get shareNoApp;

  /// No description provided for @shareOpened.
  ///
  /// In zh, this message translates to:
  /// **'已打开系统分享'**
  String get shareOpened;

  /// No description provided for @shareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享失败，请重试'**
  String get shareFailed;

  /// No description provided for @shareNoContent.
  ///
  /// In zh, this message translates to:
  /// **'没有可分享的内容'**
  String get shareNoContent;

  /// No description provided for @shareCacheFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享缓存准备失败'**
  String get shareCacheFailed;

  /// No description provided for @shareEmptyResponse.
  ///
  /// In zh, this message translates to:
  /// **'分享响应为空'**
  String get shareEmptyResponse;

  /// No description provided for @shareTitle.
  ///
  /// In zh, this message translates to:
  /// **'分享 {name}'**
  String shareTitle(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
