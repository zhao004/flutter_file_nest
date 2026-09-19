import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/models/storage_entry.dart';

import 'support/localization.dart';

import 'support/fakes.dart';

void main() {
  test('目录始终在前，未知元数据在升降序中均在末尾', () {
    final items = [
      entry('未知'),
      entry('大', size: 1024),
      entry('文件夹', directory: true),
      entry('小', size: 2),
    ];
    expect(sortEntries(items, EntrySort.size, false).map((e) => e.name), [
      '文件夹',
      '小',
      '大',
      '未知',
    ]);
    expect(sortEntries(items, EntrySort.size, true).map((e) => e.name), [
      '文件夹',
      '大',
      '小',
      '未知',
    ]);
  });
  test('按登记创建时间排序，未知值在末尾且不使用修改时间', () {
    final base = DateTime(2026);
    final items = [
      entry('无登记', modified: DateTime(2027)),
      entry('晚', size: 1),
      entry('早', size: 2),
    ];
    final created = {
      items[1].uri: base.add(const Duration(days: 2)),
      items[2].uri: base,
    };
    expect(
      sortEntries(
        items,
        EntrySort.created,
        false,
        createdAt: created,
      ).map((e) => e.name),
      ['早', '晚', '无登记'],
    );
    expect(
      sortEntries(
        items,
        EntrySort.created,
        true,
        createdAt: created,
      ).map((e) => e.name),
      ['晚', '早', '无登记'],
    );
  });
  test('名称拒绝空白、路径穿越、控制字符和过长名称', () {
    for (final name in [
      '',
      '  ',
      '.',
      '..',
      '../视频',
      'a/b',
      'a\\b',
      'a\u0000b',
      'x' * 121,
    ]) {
      expect(validateEntryName(name, zhL10n), isNotNull, reason: name);
    }
    expect(validateEntryName('现场 1', zhL10n), isNull);
  });
  test('时间戳和大小使用明确格式', () {
    expect(
      recordingFileName(DateTime(2026, 9, 17, 8, 3, 2)),
      '2026-09-17_08-03-02.mp4',
    );
    expect(formatBytes(null, zhL10n), '大小未知');
    expect(formatBytes(1024, zhL10n), '1.0 KB');
    expect(formatDuration(const Duration(seconds: 65)), '01:05');
  });

  test('播放时间格式区分小时，负值按 0 处理', () {
    expect(formatPlaybackTime(Duration.zero), '00:00');
    expect(formatPlaybackTime(const Duration(seconds: 65)), '01:05');
    expect(
      formatPlaybackTime(const Duration(hours: 1, minutes: 1, seconds: 1)),
      '1:01:01',
    );
    expect(formatPlaybackTime(const Duration(seconds: -5)), '00:00');
  });
}
