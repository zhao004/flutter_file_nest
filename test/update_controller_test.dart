import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/models/update_models.dart';
import 'package:filenest/app/pages/settings/update_controller.dart';
import 'package:filenest/app/services/update_api.dart';
import 'package:filenest/app/services/update_installer.dart';

import 'support/fakes.dart';
import 'support/localization.dart';

void main() {
  const build = AppBuildInfo(version: '1.0.0', buildNumber: 1);

  UpdatePackage packageWith({String? sha256, String versionName = '1.2.0'}) =>
      UpdatePackage(
        versionName: versionName,
        downloadUrl: 'https://example.com/app.apk',
        sha256: sha256 ?? '',
      );

  /// 注册带临时下载目录的控制器；返回下载根目录供断言。
  Future<(UpdateController, FakeUpdateApi, FakeUpdateInstaller, Directory)>
  setup() async {
    final temp = await Directory.systemTemp.createTemp('filenest_update_test');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final api = FakeUpdateApi();
    final installer = FakeUpdateInstaller();
    final controller = UpdateController(
      api: api,
      installer: installer,
      build: build,
      tempDirectory: () async => temp,
    );
    return (controller, api, installer, temp);
  }

  test('检查到新版本时写入待更新信息', () async {
    final (controller, api, _, _) = await setup();
    api.outcome = UpdateAvailable(packageWith());

    final outcome = await controller.check();

    expect(outcome, isA<UpdateAvailable>());
    expect(controller.pending.value?.versionName, '1.2.0');
    expect(controller.checking.value, isFalse);
    expect(api.checks, 1);
    expect(api.lastBuild?.buildNumber, 1);
  });

  test('已是最新时不保留待更新信息', () async {
    final (controller, api, _, _) = await setup();
    api.outcome = const UpToDate('1.0.0');

    final outcome = await controller.check();

    expect(outcome, isA<UpToDate>());
    expect(controller.pending.value, isNull);
  });

  test('检查中重复调用复用同一请求', () async {
    final (controller, api, _, _) = await setup();

    final first = controller.check();
    final second = controller.check();

    expect(identical(first, second), isTrue);
    await first;
    expect(api.checks, 1);
  });

  test('下载通过摘要校验后启动安装并保留安装包', () async {
    final (controller, api, installer, temp) = await setup();
    final bytes = utf8.encode('apk-payload');
    api
      ..downloadBytes = Uint8List.fromList(bytes)
      ..outcome = UpdateAvailable(
        packageWith(sha256: sha256.convert(bytes).toString()),
      );
    await controller.check();

    expect(await controller.startUpdate(), isTrue);

    expect(installer.installs, hasLength(1));
    expect(controller.error.value, isNull);
    final apk = File(
      '${temp.path}${Platform.pathSeparator}updates'
      '${Platform.pathSeparator}filenest-update.apk',
    );
    expect(await apk.exists(), isTrue);
  });

  test('摘要不匹配时删除安装包且不启动安装', () async {
    final (controller, api, installer, temp) = await setup();
    api
      ..downloadBytes = Uint8List.fromList(utf8.encode('apk-payload'))
      ..outcome = UpdateAvailable(packageWith(sha256: 'deadbeef'));
    await controller.check();

    expect(await controller.startUpdate(), isFalse);

    expect(installer.installs, isEmpty);
    expect(controller.error.value, zhL10n.updateErrorHash);
    final apk = File(
      '${temp.path}${Platform.pathSeparator}updates'
      '${Platform.pathSeparator}filenest-update.apk',
    );
    expect(await apk.exists(), isFalse);
  });

  test('下载失败展示可重试错误', () async {
    final (controller, api, installer, _) = await setup();
    api
      ..downloadFailure = const UpdateDownloadFailure('下载失败，请重试')
      ..outcome = UpdateAvailable(packageWith());
    await controller.check();

    expect(await controller.startUpdate(), isFalse);

    expect(controller.error.value, '下载失败，请重试');
    expect(installer.installs, isEmpty);
    expect(controller.downloading.value, isFalse);
  });

  test('缺少安装权限时提示授权并支持重试安装', () async {
    final (controller, api, installer, _) = await setup();
    api
      ..downloadBytes = Uint8List.fromList(utf8.encode('apk-payload'))
      ..outcome = UpdateAvailable(packageWith());
    installer.failure = const UpdateInstallFailure(
      UpdateInstallerService.permissionRequiredCode,
      '需要允许安装未知应用',
    );
    await controller.check();

    expect(await controller.startUpdate(), isFalse);
    expect(controller.needsInstallPermission.value, isTrue);
    expect(controller.error.value, zhL10n.updatePermissionRequired);

    installer.failure = null;
    expect(await controller.retryInstall(), isTrue);
    expect(installer.installs, hasLength(1));
    expect(controller.needsInstallPermission.value, isFalse);
  });

  test('用户取消下载不视为错误', () async {
    final (controller, api, installer, _) = await setup();
    api
      ..downloadGate = Completer<void>()
      ..outcome = UpdateAvailable(packageWith());
    await controller.check();

    final future = controller.startUpdate();
    await Future<void>.delayed(Duration.zero);
    expect(controller.downloading.value, isTrue);

    controller.cancelDownload();
    expect(await future, isFalse);

    expect(api.cancelCalled, isTrue);
    expect(controller.error.value, isNull);
    expect(controller.downloading.value, isFalse);
    expect(installer.installs, isEmpty);
  });

  test('关闭弹窗清理错误状态', () async {
    final (controller, api, _, _) = await setup();
    api
      ..downloadFailure = const UpdateDownloadFailure('下载失败，请重试')
      ..outcome = UpdateAvailable(packageWith());
    await controller.check();
    await controller.startUpdate();
    expect(controller.error.value, isNotNull);

    controller.reset();

    expect(controller.error.value, isNull);
    expect(controller.needsInstallPermission.value, isFalse);
  });

  test('启动静默检查仅在发现新版本时返回结果', () async {
    final (controller, api, _, _) = await setup();
    api.outcome = UpdateAvailable(packageWith());

    final available = await controller.checkOnStartup();

    expect(available?.package.versionName, '1.2.0');
    expect(api.checks, 1);
  });

  test('启动静默检查只执行一次且失败静默', () async {
    final (controller, api, _, _) = await setup();
    api.outcome = const UpdateCheckFailure('网络不可用');

    expect(await controller.checkOnStartup(), isNull);
    expect(await controller.checkOnStartup(), isNull);
    expect(api.checks, 1);
  });

  test('启动静默检查已是最新时不返回结果', () async {
    final (controller, api, _, _) = await setup();
    api.outcome = const UpToDate('1.0.0');

    expect(await controller.checkOnStartup(), isNull);
    expect(api.checks, 1);
  });
}
