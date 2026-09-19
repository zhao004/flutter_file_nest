import 'package:filenest/app/models/media_editor_args.dart';
import 'package:filenest/app/pages/preview/image_editor_view.dart';
import 'package:filenest/app/routes/app_pages.dart';
import 'package:filenest/app/services/saf_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/fakes.dart';

void main() {
  late FakeStorage storage;

  setUp(() {
    Get.testMode = true;
    storage = FakeStorage()..readDocumentResult = null;
    Get.put<StorageGateway>(storage);
  });

  tearDown(Get.reset);

  /// 回归：GetX 的 `onGenerateRoute` 始终重建为 `GetPageRoute<dynamic>`，若用
  /// `Get.toNamed<String>` 会在 Navigator 内抛 `Route<String?>` 转换异常。
  /// 编辑路由必须能以 `Get.toNamed<void>` 正常进入。
  testWidgets('图片编辑路由经 Get.toNamed<void> 可正常进入', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        getPages: [
          GetPage(
            name: '/',
            page: () => const Scaffold(body: Text('root')),
          ),
          ...AppPages.routes.where((page) => page.name == Routes.imageEditor),
        ],
      ),
    );
    expect(find.text('root'), findsOneWidget);

    Get.toNamed<void>(
      Routes.imageEditor,
      arguments: MediaEditorArgs(entry: entry('photo.jpg'), parent: root),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ImageEditorView), findsOneWidget);
    expect(find.text('编辑视频'), findsNothing);
  });
}
