// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonShare => 'Share';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonPreview => 'Preview';

  @override
  String get commonBack => 'Back';

  @override
  String get commonPrevious => 'Up';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonCloseSearch => 'Close search';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUnsavedChangesTitle => 'Discard unsaved changes?';

  @override
  String get commonOpenExternal => 'Open with another app';

  @override
  String get commonOpenExternalShort => 'Other app';

  @override
  String commonLink(String href) {
    return 'Link: $href';
  }

  @override
  String get commonName => 'Name';

  @override
  String get commonType => 'Type';

  @override
  String get commonSize => 'Size';

  @override
  String get commonLocation => 'Location';

  @override
  String get commonModifiedTime => 'Modified';

  @override
  String get commonDuration => 'Duration';

  @override
  String get commonDimensions => 'Dimensions';

  @override
  String get categoryFolder => 'Folder';

  @override
  String get categoryImage => 'Image';

  @override
  String get categoryVideo => 'Video';

  @override
  String get categoryAudio => 'Audio';

  @override
  String get categoryPdf => 'PDF';

  @override
  String get categoryDocument => 'Document';

  @override
  String get categorySpreadsheet => 'Spreadsheet';

  @override
  String get categoryPresentation => 'Presentation';

  @override
  String get categoryArchive => 'Archive';

  @override
  String get categoryApk => 'App package';

  @override
  String get categoryText => 'Text';

  @override
  String get categoryCode => 'Code';

  @override
  String get categoryDatabase => 'Database';

  @override
  String get categoryFont => 'Font';

  @override
  String get categoryEbook => 'E-book';

  @override
  String get categorySubtitle => 'Subtitle';

  @override
  String get categoryUnknown => 'Unknown file';

  @override
  String get sizeUnknown => 'Size unknown';

  @override
  String get entryNameEmpty => 'Enter a valid name';

  @override
  String get entryNameTooLong => 'Name cannot exceed 120 characters';

  @override
  String get entryNameInvalidChars =>
      'Name cannot contain path or control characters';

  @override
  String renameDuplicate(String name) {
    return 'Duplicate of $name';
  }

  @override
  String get renameExists =>
      'An item with this name already exists in this folder';

  @override
  String get incomingShareFallbackName => 'File to save';

  @override
  String get storageEmptyResponse => 'Empty storage response';

  @override
  String get storageMoveEmptyResponse => 'Empty move response';

  @override
  String get storageCacheExportEmptyResponse => 'Empty cache export response';

  @override
  String get storageReadEmptyResponse => 'Empty read response';

  @override
  String get storageWriteEmptyResponse => 'Empty write response';

  @override
  String get storageOperationFailed => 'File operation failed';

  @override
  String get storageOperationIncomplete => 'Operation incomplete, please retry';

  @override
  String get errorReadOnly => 'Current folder is read-only';

  @override
  String homeSavedIncomingFiles(int count, String folder) {
    return 'Saved $count file(s) to “$folder”';
  }

  @override
  String get homePickRootFirstTitle => 'Choose a storage folder first';

  @override
  String get homePickRootFirstBody =>
      'Files from other apps are waiting to be saved. Authorize a folder as the destination first.';

  @override
  String get homeChooseFolder => 'Choose folder';

  @override
  String get homeNewFolder => 'New folder';

  @override
  String get homeNewFile => 'New file';

  @override
  String get homeRenameFolder => 'Rename folder';

  @override
  String get homeRenameFile => 'Rename file';

  @override
  String get homeRenameShort => 'Rename';

  @override
  String get homeFileName => 'File name';

  @override
  String get homeFolderName => 'Folder name';

  @override
  String homeDeleteForeverTitle(String name) {
    return 'Permanently delete “$name”?';
  }

  @override
  String homeDeleteForeverCountTitle(int count) {
    return 'Permanently delete $count item(s)?';
  }

  @override
  String homeDeleteImpact(int files, int folders) {
    return '$files file(s), $folders subfolder(s)\nThis cannot be undone.';
  }

  @override
  String get homeDeleteImpactUnknown =>
      'Could not verify folder contents; nothing was deleted. Refresh and retry';

  @override
  String get homeDeleteConfirm => 'Delete permanently';

  @override
  String homeSavedCopy(String name) {
    return 'Copy saved: $name';
  }

  @override
  String get homeEditImage => 'Edit image';

  @override
  String get homeEditImageSubtitle =>
      'Save as a new file; the original is kept';

  @override
  String get homeEditVideo => 'Edit video';

  @override
  String get homeEditVideoSubtitle =>
      'Save as a new file; the original is kept';

  @override
  String get homeDetails => 'Details';

  @override
  String get homeExtractToFolder => 'Extract to new folder';

  @override
  String get homeExtractToFolderSubtitle =>
      'Uses a new name if a folder with the same name exists';

  @override
  String get homeArchiveCancelling => 'Cancelling the archive task…';

  @override
  String get homeRefresh => 'Refresh';

  @override
  String get homeDismissError => 'Dismiss';

  @override
  String get homeSelectFiles => 'Choose files';

  @override
  String get homeTakePhoto => 'Take photo';

  @override
  String get homeRecordVideo => 'Record video';

  @override
  String get homeSearchFiles => 'Search files';

  @override
  String get homeExitSelection => 'Exit selection';

  @override
  String get homeSelection => 'Select';

  @override
  String get homeMore => 'More';

  @override
  String get homeSortBy => 'Sort by';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeSortDirection => 'Sort direction';

  @override
  String get homeAscending => 'Ascending';

  @override
  String get homeDescending => 'Descending';

  @override
  String get homeScanning => 'Scanning subfolders…';

  @override
  String get homeSearchIncomplete =>
      'Some folders are unavailable; results are incomplete';

  @override
  String get homeSearchHint => 'Search file names';

  @override
  String get homeSearchRecursive => 'Search subfolders recursively';

  @override
  String get homeExitSearch => 'Exit search';

  @override
  String get homeChooseStorageFolder => 'Choose storage folder';

  @override
  String get homeNoMatches => 'No matching files';

  @override
  String homeLocation(String location) {
    return 'Location: $location';
  }

  @override
  String get homeEmptyFolder => 'Folder is empty';

  @override
  String get homeDeselect => 'Deselect';

  @override
  String get homeSelect => 'Select';

  @override
  String homeSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get homeDeselectAll => 'Deselect all';

  @override
  String get homeSelectAll => 'Select all';

  @override
  String get homeMoveTo => 'Move to…';

  @override
  String get homeBatchRename => 'Batch rename';

  @override
  String get homeZipAsZip => 'Compress to ZIP';

  @override
  String get homeMoreActions => 'More actions';

  @override
  String get sortByName => 'By name';

  @override
  String get sortByModified => 'By modified time';

  @override
  String get sortByCreated => 'By created time';

  @override
  String get sortBySize => 'By size';

  @override
  String get moveCurrentUnavailable => 'Current folder is unavailable';

  @override
  String get moveInvalidTarget => 'Invalid destination';

  @override
  String get moveSameTarget => 'Destination is the same as the source';

  @override
  String moveInsideFolder(String name) {
    return 'Destination is inside the selected folder $name';
  }

  @override
  String get moveSourceKept => 'Copied; source was not deleted';

  @override
  String get batchRenameInvalidPlan =>
      'Invalid names found; batch rename cancelled';

  @override
  String get zipDialogTitle => 'Compress to ZIP';

  @override
  String get zipNameLabel => 'Archive name';

  @override
  String get zipStart => 'Compress';

  @override
  String get folderPickerMoveHere => 'Move here';

  @override
  String folderPickerWillMoveTo(String path) {
    return 'Will move to: $path';
  }

  @override
  String get folderPickerNoSubfolders => 'No subfolders';

  @override
  String get folderPickerBlocked => 'Selected item cannot be the destination';

  @override
  String get batchRenameTitle => 'Batch rename';

  @override
  String get renamePrefix => 'Prefix';

  @override
  String get renameSuffix => 'Suffix';

  @override
  String get renameFind => 'Find text';

  @override
  String get renameReplace => 'Replace with';

  @override
  String get renameNumbering => 'Use numbering (replace names)';

  @override
  String get renameStartNumber => 'Start number';

  @override
  String get renamePreviewHeader => 'Preview';

  @override
  String get renamePreviewEmpty => 'Enter rename rules';

  @override
  String get renameExecute => 'Rename';

  @override
  String get batchKindDelete => 'Batch delete';

  @override
  String get batchKindMove => 'Batch move';

  @override
  String get batchKindRename => 'Batch rename';

  @override
  String batchProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String batchSummarySuccess(int count) {
    return '$count succeeded';
  }

  @override
  String batchSummaryFailed(int count) {
    return '$count failed';
  }

  @override
  String batchSummaryKeptSource(int count) {
    return '$count source kept';
  }

  @override
  String get detailsTitle => 'File details';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsStorageFolder => 'Storage folder';

  @override
  String get settingsNotSelected => 'Not selected';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsColorScheme => 'Color scheme';

  @override
  String get settingsEditor => 'Editor settings';

  @override
  String settingsFontSizeValue(int size) {
    return 'Font size $size';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeSystem => 'System default';

  @override
  String get editorSectionTextCode => 'Text & code';

  @override
  String get editorSectionEditor => 'Editor';

  @override
  String get editorWrap => 'Word wrap';

  @override
  String get editorWrapSubtitle => 'Turn off to scroll long lines horizontally';

  @override
  String get editorLineNumbers => 'Show line numbers';

  @override
  String get editorTabWidth => 'Tab size';

  @override
  String editorTabWidthValue(int width) {
    return '$width spaces';
  }

  @override
  String get editorAutoIndent => 'Auto indent';

  @override
  String get editorAutoIndentSubtitle =>
      'Keep current indentation on new lines';

  @override
  String get editorMarkdownMode => 'View mode';

  @override
  String get editorMarkdownRead => 'Reading';

  @override
  String get editorMarkdownSource => 'Source';

  @override
  String get editorFontSize => 'Font size';

  @override
  String get editorSectionMarkdown => 'Markdown';

  @override
  String get previewErrorFallback => 'Unable to read this file';

  @override
  String get previewErrorNotFound => 'File or storage device unavailable';

  @override
  String get previewErrorPermission =>
      'Folder access has expired; choose the storage folder again';

  @override
  String get previewErrorRead => 'Failed to read file';

  @override
  String get previewTruncated => 'File is large; showing the first part only';

  @override
  String get textOptions => 'Text options';

  @override
  String get codeOptions => 'Code options';

  @override
  String get textZoomIn => 'Increase font size';

  @override
  String get textZoomOut => 'Decrease font size';

  @override
  String get textCopyAll => 'Copy all';

  @override
  String get textCopiedAll => 'Copied all content';

  @override
  String textDecodedAs(String encoding) {
    return 'Decoded as $encoding';
  }

  @override
  String get textSearchHint => 'Find in file';

  @override
  String get codeSearchHint => 'Find in code';

  @override
  String get markdownViewSource => 'View source';

  @override
  String get markdownReadingMode => 'Reading mode';

  @override
  String get markdownEditSource => 'Edit source';

  @override
  String get editorSaved => 'Saved';

  @override
  String get editorSaveFailed => 'Save failed, please retry';

  @override
  String get editorDiscardBody => 'Leaving will discard your edits.';

  @override
  String get editorKeepEditing => 'Keep editing';

  @override
  String get editorDiscard => 'Discard';

  @override
  String get editorUndo => 'Undo';

  @override
  String get editorRedo => 'Redo';

  @override
  String get editorSave => 'Save';

  @override
  String get editorOptions => 'Editor options';

  @override
  String get editorRevert => 'Revert changes';

  @override
  String get editorTooLarge => 'File is too large to edit in the app';

  @override
  String editorPreserveEncoding(String details) {
    return 'Will preserve: $details';
  }

  @override
  String get textEncodeGbkFailed =>
      'Can\'t save using GBK encoding; edit with another app';

  @override
  String get textEncodeLatin1Failed =>
      'Content contains characters that can\'t be saved as Latin-1';

  @override
  String get imageInfo => 'Image info';

  @override
  String get imageUnsupported =>
      'Can\'t preview this image in the app; the format may be unsupported (e.g. HEIC)';

  @override
  String get imageEditUnsupported =>
      'Can\'t edit this image in the app; the format may be unsupported';

  @override
  String get audioCannotPlay =>
      'Can\'t play this audio; the file may have moved or the format is unsupported';

  @override
  String get audioPlayFailed => 'Audio playback failed';

  @override
  String get audioSpeed => 'Playback speed';

  @override
  String get audioMute => 'Mute';

  @override
  String get audioUnmute => 'Unmute';

  @override
  String get audioBack10 => 'Back 10 seconds';

  @override
  String get audioForward10 => 'Forward 10 seconds';

  @override
  String get audioPause => 'Pause';

  @override
  String get audioPlay => 'Play';

  @override
  String get videoCannotPlay =>
      'Can\'t play this video; the file may have moved or the format is unsupported';

  @override
  String get videoPlayFailed => 'Video playback failed';

  @override
  String videoVolume(int value) {
    return 'Volume $value%';
  }

  @override
  String videoBrightness(int value) {
    return 'Brightness $value%';
  }

  @override
  String get videoSpeed => 'Playback speed';

  @override
  String get videoEditorExporting => 'Exporting video…';

  @override
  String get videoEditorOpenFailed => 'Can\'t open this video for editing';

  @override
  String get videoEditorExportFailed => 'Video export failed, please retry';

  @override
  String get videoEditorHostUnsupported =>
      'Can\'t start editing this video; the format may be unsupported';

  @override
  String get pdfNoPages => 'This PDF has no displayable pages';

  @override
  String pdfPageIndicator(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get pdfPasswordProtected =>
      'This PDF is password-protected and can\'t be previewed in the app';

  @override
  String get pdfInvalid => 'Can\'t read this PDF; the file may be damaged';

  @override
  String get pdfReadFailed => 'Can\'t read this PDF, please try again later';

  @override
  String get pdfPageUnrenderable => 'This page can\'t be rendered';

  @override
  String get archiveParseFailed => 'Can\'t parse this archive';

  @override
  String get archiveEmpty => 'Archive is empty';

  @override
  String get archiveEntryReadFailed => 'Can\'t read this entry';

  @override
  String get archiveImagePreviewFailed => 'Can\'t preview this image';

  @override
  String get archiveEmbeddedUnsupported =>
      'Inline preview isn\'t supported for this type';

  @override
  String get csvEmpty => 'No table content to display';

  @override
  String csvTruncated(int rows) {
    return 'Table is large; showing the first $rows rows';
  }

  @override
  String get subtitleEmpty => 'No subtitles to display';

  @override
  String get subtitleEmptyCue => '(empty cue)';

  @override
  String get fontLoadFailed =>
      'Can\'t load this font file; it may be damaged or unsupported';

  @override
  String get fontSample =>
      'The quick brown fox jumps over the lazy dog. 0123456789';

  @override
  String get imageEditorPickFromDevice => 'Choose from device';

  @override
  String get epubParseFailed => 'Can\'\'t parse this EPUB file';

  @override
  String get epubInvalid => 'Can\'t parse the EPUB file';

  @override
  String get epubMissingContainer => 'EPUB is missing container.xml';

  @override
  String get epubMissingOpf => 'EPUB is missing the OPF manifest';

  @override
  String get epubUnreadableManifest => 'Can\'t read the EPUB manifest';

  @override
  String get epubNoSpine => 'EPUB has no displayable chapters';

  @override
  String get epubEmptyChapters => 'EPUB chapter content is empty';

  @override
  String get epubInvalidManifest => 'EPUB manifest format is invalid';

  @override
  String get epubUntitled => 'Untitled';

  @override
  String epubChapterTitle(int index) {
    return 'Chapter $index';
  }

  @override
  String get epubToc => 'Contents';

  @override
  String epubChapterIndicator(int current, int total, String title) {
    return 'Chapter $current of $total · $title';
  }

  @override
  String get unsupportedPreview => 'Preview isn\'t supported for this file';

  @override
  String get archiveTaskScanningZip => 'Preparing compression…';

  @override
  String get archiveTaskScanningExtract => 'Checking archive…';

  @override
  String get archiveTaskScanningShare => 'Preparing share…';

  @override
  String archiveTaskProcessingZip(int count) {
    return 'Compressing: $count item(s) processed';
  }

  @override
  String archiveTaskProcessingExtract(int count) {
    return 'Extracting: $count item(s) done';
  }

  @override
  String archiveTaskProcessingShare(int count) {
    return 'Preparing share: $count item(s) processed';
  }

  @override
  String get archiveTaskCompleted => 'Completed';

  @override
  String get archiveTaskCancelled => 'Cancelled';

  @override
  String get archiveTaskFailed => 'Task failed';

  @override
  String get archiveZipCancelled => 'Compression cancelled';

  @override
  String get archiveExtractCancelled => 'Extraction cancelled';

  @override
  String archiveZipDone(String name, int count) {
    return 'Archive created: $name ($count item(s))';
  }

  @override
  String get archiveZipDefaultName => 'Archive';

  @override
  String archiveExtractSkipped(int extracted, int skipped) {
    return 'Extracted $extracted item(s), skipped $skipped';
  }

  @override
  String archiveExtractDone(int count, String name) {
    return 'Extracted $count item(s) to $name';
  }

  @override
  String get archiveExtractDefaultFolder => 'New folder';

  @override
  String get archiveExtractResultFallbackName => 'Extracted files';

  @override
  String get archiveShareReady => 'Share content is ready';

  @override
  String get archiveOutcomeFailed => 'Archive task failed';

  @override
  String get archiveNoEntries => 'Nothing to compress';

  @override
  String get archiveBusyZip =>
      'An archive task is already running; wait or cancel it';

  @override
  String get archiveBusyShare =>
      'An archive task is already running; try sharing later';

  @override
  String get archiveEmptyResponse => 'Empty archive response';

  @override
  String get archiveZipFailed => 'Compression failed, please retry';

  @override
  String get archiveExtractEmptyResponse => 'Empty extraction response';

  @override
  String get archiveExtractFailed =>
      'Extraction failed; check that the archive is intact';

  @override
  String get shareCancelled => 'Share cancelled';

  @override
  String get shareNoApp => 'No app can receive the share';

  @override
  String get shareOpened => 'System share opened';

  @override
  String get shareFailed => 'Share failed, please retry';

  @override
  String get shareNoContent => 'No content to share';

  @override
  String get shareCacheFailed => 'Failed to prepare share cache';

  @override
  String get shareEmptyResponse => 'Empty share response';

  @override
  String shareTitle(String name) {
    return 'Share $name';
  }
}
