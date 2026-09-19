import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/models/update_models.dart';
import 'package:filenest/app/pages/settings/update_controller.dart';
import 'package:filenest/app/pages/settings/update_dialog.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fakes.dart';
import 'support/localization.dart';

void main() {
  testWidgets('更新弹窗下载校验后启动系统安装', (tester) async {
    // 真实文件 IO 必须在 runAsync 中执行，否则 fake async 环境下不会完成。
    final temp = await tester.runAsync(
      () => Directory.systemTemp.createTemp('filenest_update_dialog'),
    );
    if (temp == null) {
      fail('无法创建临时下载目录');
    }
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final bytes = utf8.encode('apk-payload');
    final api = FakeUpdateApi()..downloadBytes = Uint8List.fromList(bytes);
    final installer = FakeUpdateInstaller();
    final controller = UpdateController(
      api: api,
      installer: installer,
      build: const AppBuildInfo(version: '1.0.0', buildNumber: 1),
      tempDirectory: () async => temp,
    );
    final package = UpdatePackage(
      versionName: '1.2.0',
      downloadUrl: 'https://example.com/app.apk',
      sha256: sha256.convert(bytes).toString(),
      releaseNotes: '## 修复问题',
      filesize: 4096,
    );
    api.outcome = UpdateAvailable(package);
    await controller.check();

    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      UpdateDialog(controller: controller, package: package),
                ),
                child: const Text('打开弹窗'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开弹窗'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 1.2.0'), findsOneWidget);
    expect(find.text('安装包大小：4.0 KB'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);

    await tester.tap(find.text('立即更新'));
    // 下载与校验使用真实文件 IO：在 runAsync 与 pump 之间交替推进，
    // 既让真实事件循环完成 IO，也让 fake async 中的状态与界面及时刷新。
    for (var i = 0; i < 100 && installer.installs.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(installer.installs, hasLength(1));
    expect(find.text('发现新版本 1.2.0'), findsNothing);
    expect(find.text('已启动安装程序，请按系统提示完成安装'), findsOneWidget);
  });
}
