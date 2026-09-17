import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lens_vault/app/models/archive_models.dart';
import 'package:flutter_lens_vault/app/models/storage_entry.dart';
import 'package:flutter_lens_vault/app/services/archive_service.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('lens_vault/archive');
  const events = EventChannel('lens_vault/archive_events');
  late List<MethodCall> calls;
  late MockStreamHandlerEventSink eventSink;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (arguments, sink) => eventSink = sink,
          ),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(events, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('压缩传递操作 ID 与条目标识并解析结果', () async {
    Map<Object?, Object?>? zipArgs;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'cleanupShareCache') return 0;
          if (call.method == 'zip') {
            zipArgs = call.arguments as Map<Object?, Object?>;
            return <Object?, Object?>{
              'cancelled': false,
              'items': 2,
              'target': {
                'rootUri': 'content://test/tree/root',
                'documentId': '素材.zip',
                'uri': 'content://test/tree/root/document/素材.zip',
                'name': '素材.zip',
                'isDirectory': false,
                'mimeType': 'application/zip',
              },
            };
          }
          return null;
        });

    final service = ArchiveService();
    final outcome = await service.zip(
      entries: [_entry('素材', directory: true)],
      targetFolder: _entry('root', directory: true),
    );

    expect(outcome.ok, true);
    expect(outcome.target?.name, '素材.zip');
    expect(outcome.items, 2);
    expect(zipArgs?['operationId'], isA<String>());
    expect(zipArgs?['fileName'], '素材.zip');
    final entries = zipArgs?['entries'] as List<Object?>;
    expect((entries.single as Map<Object?, Object?>)['documentId'], '素材');
    expect((entries.single as Map<Object?, Object?>?)?['isDirectory'], true);
  });

  test('进度事件更新当前任务，终态与结果一致', () async {
    final gate = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cleanupShareCache') return 0;
          if (call.method == 'zip') return gate.future;
          return null;
        });
    final service = ArchiveService();
    final pending = service.zip(
      entries: [_entry('视频.mp4', mime: 'video/mp4')],
      targetFolder: _entry('root', directory: true),
    );
    final operationId = service.active.value!.operationId;
    eventSink.success(<Object?, Object?>{
      'operationId': operationId,
      'stage': 'processing',
      'processedItems': 3,
      'totalItems': 10,
      'canCancel': true,
    });
    await Future<void>.delayed(Duration.zero);
    expect(service.active.value?.stage, ArchiveStage.processing);
    expect(service.active.value?.fraction, 0.3);
    gate.complete(<Object?, Object?>{'cancelled': true});
    final outcome = await pending;
    expect(outcome.cancelled, true);
    expect(service.active.value, isNull);
  });

  test('取消调用原生取消并保留任务直至终态', () async {
    final gate = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'cleanupShareCache') return 0;
          if (call.method == 'zip') return gate.future;
          return true;
        });
    final service = ArchiveService();
    final pending = service.zip(
      entries: [_entry('视频.mp4', mime: 'video/mp4')],
      targetFolder: _entry('root', directory: true),
    );
    await Future<void>.delayed(Duration.zero);
    await service.cancelActive();
    final cancelCall = calls.firstWhere((call) => call.method == 'cancel');
    expect(
      (cancelCall.arguments as Map<Object?, Object?>)['operationId'],
      isNotNull,
    );
    gate.complete(<Object?, Object?>{'cancelled': true});
    await pending;
    expect(service.active.value, isNull);
  });

  test('平台错误转换为结构化失败结果', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cleanupShareCache') return 0;
          throw PlatformException(
            code: 'unsafe_archive',
            message: '归档包含不安全的条目名称',
          );
        });
    final service = ArchiveService();
    final outcome = await service.extract(
      archive: _entry('素材.zip', mime: 'application/zip'),
      targetFolder: _entry('root', directory: true),
    );
    expect(outcome.ok, false);
    expect(outcome.code, 'unsafe_archive');
    expect(outcome.summary, contains('不安全'));
    expect(service.active.value, isNull);
  });

  test('分享无接收方时返回可恢复结果', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cleanupShareCache') return 0;
          if (call.method == 'share') {
            return <Object?, Object?>{'result': 'no_app'};
          }
          return null;
        });
    final service = ArchiveService();
    final outcome = await service.share([_entry('视频.mp4', mime: 'video/mp4')]);
    expect(outcome.ok, false);
    expect(outcome.code, 'no_app');
    expect(outcome.summary, contains('未找到'));
  });
}
