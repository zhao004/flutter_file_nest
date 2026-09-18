import 'package:get/get.dart';
import 'package:flutter_lens_vault/app/models/archive_models.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/services/archive_service.dart';

import 'fakes.dart';

/// 可编程归档网关假件；覆盖成功、失败、取消与分享无接收方等状态。
class FakeArchive implements ArchiveGateway {
  @override
  final active = Rxn<ArchiveTaskState>();
  final zipCalls = <String>[];
  final zipNames = <String?>[];
  final extractCalls = <String>[];
  final shareCalls = <String>[];
  int cancels = 0;
  ArchiveOutcome zipResult = ArchiveOutcome(
    kind: ArchiveKind.zip,
    target: entry('压缩结果.zip', mime: 'application/zip'),
    items: 3,
  );
  ArchiveOutcome extractResult = ArchiveOutcome(
    kind: ArchiveKind.extract,
    target: entry('解压结果', directory: true),
    extracted: 2,
  );
  ShareOutcome shareResult = const ShareOutcome.shared();

  void emit(ArchiveTaskState task) => active.value = task;

  @override
  Future<ArchiveOutcome> zip({
    required List<StorageEntry> entries,
    required StorageEntry targetFolder,
    String? fileName,
  }) async {
    zipCalls.add(entries.map((value) => value.name).join(','));
    zipNames.add(fileName);
    return zipResult;
  }

  @override
  Future<ArchiveOutcome> extract({
    required StorageEntry archive,
    required StorageEntry targetFolder,
    String? folderName,
  }) async {
    extractCalls.add(archive.name);
    return extractResult;
  }

  @override
  Future<ShareOutcome> share(List<StorageEntry> entries) async {
    shareCalls.add(entries.map((value) => value.name).join(','));
    return shareResult;
  }

  @override
  Future<void> cancelActive() async {
    cancels++;
    active.value = null;
  }
}
