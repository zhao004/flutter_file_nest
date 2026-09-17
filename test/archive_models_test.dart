import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/models/archive_models.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';

StorageEntry _entry(String name, {bool directory = false, String? mime}) =>
    StorageEntry(
      rootUri: 'content://test/tree/root',
      documentId: name,
      uri: 'content://test/tree/root/document/$name',
      name: name,
      isDirectory: directory,
      mimeType: mime,
    );

void main() {
  test('进度事件按字段解析并区分终态', () {
    final task = ArchiveTaskState.fromEvent('op-1', ArchiveKind.zip, {
      'stage': 'processing',
      'processedItems': 4,
      'totalItems': 10,
      'processedBytes': 1024,
      'canCancel': true,
    });
    expect(task.stage, ArchiveStage.processing);
    expect(task.fraction, 0.4);
    expect(task.terminal, false);
    expect(task.label, contains('已处理 4 项'));
    final done = ArchiveTaskState.fromEvent('op-1', ArchiveKind.extract, {
      'stage': 'completed',
    });
    expect(done.terminal, true);
    expect(done.fraction, isNull);
  });

  test('总量未知时使用不定进度，未知阶段按处理中处理', () {
    final task = ArchiveTaskState.fromEvent('op-2', ArchiveKind.share, {
      'stage': 'weird',
      'processedItems': 2,
    });
    expect(task.stage, ArchiveStage.processing);
    expect(task.fraction, isNull);
    expect(task.canCancel, false);
  });

  test('压缩结果摘要包含目标名称与项数', () {
    final outcome = ArchiveOutcome(
      kind: ArchiveKind.zip,
      target: _entry('现场.zip', mime: 'application/zip'),
      items: 3,
    );
    expect(outcome.ok, true);
    expect(outcome.summary, contains('现场.zip'));
    expect(outcome.summary, contains('3 项'));
  });

  test('解压存在跳过项时必须显式说明部分结果', () {
    final outcome = ArchiveOutcome(
      kind: ArchiveKind.extract,
      target: _entry('解压结果', directory: true),
      extracted: 5,
      skipped: 2,
    );
    expect(outcome.summary, contains('已解压 5 项'));
    expect(outcome.summary, contains('跳过 2 项'));
  });

  test('取消与失败结果区分展示', () {
    const cancelled = ArchiveOutcome.cancelled(ArchiveKind.extract, 'op-1');
    expect(cancelled.cancelled, true);
    expect(cancelled.summary, '解压已取消');
    const failure = ArchiveOutcome.failure(
      ArchiveKind.extract,
      'unsafe_archive',
      '归档包含不安全的条目名称',
    );
    expect(failure.ok, false);
    expect(failure.summary, '归档包含不安全的条目名称');
  });

  test('分享结果区分无接收方与打开分享面板', () {
    expect(const ShareOutcome.shared().summary, contains('系统分享'));
    expect(const ShareOutcome.noApp().summary, contains('未找到'));
    expect(const ShareOutcome.cancelled().summary, '分享已取消');
  });

  test('压缩与解压默认名称遵循原生规则', () {
    expect(defaultZipFileName('video.mp4'), 'video.zip');
    expect(defaultZipFileName('素材'), '素材.zip');
    expect(defaultExtractFolderName('现场 1.zip'), '现场 1');
    expect(defaultExtractFolderName('.zip'), '解压结果');
  });

  test('仅 ZIP 文件提供解压入口', () {
    expect(looksLikeZip(_entry('a.zip')), true);
    expect(looksLikeZip(_entry('a.ZIP', mime: 'application/zip')), true);
    expect(looksLikeZip(_entry('a.mp4', mime: 'video/mp4')), false);
    expect(looksLikeZip(_entry('文件夹', directory: true)), false);
  });
}
