import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/models/update_models.dart';

import 'support/localization.dart';

void main() {
  group('isNewerVersion', () {
    test('按 major/minor/patch 数值比较', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('预发布版本低于同号正式版', () {
      expect(isNewerVersion('1.0.0', '1.0.0-beta.1'), isTrue);
      expect(isNewerVersion('1.0.0-beta.2', '1.0.0-beta.1'), isTrue);
      expect(isNewerVersion('1.0.0-beta.1', '1.0.0'), isFalse);
    });

    test('忽略 v 前缀与构建号，缺失段按 0 处理', () {
      expect(isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.0', '0.9.9'), isTrue);
      expect(isNewerVersion('1.0.0+8', '1.0.0+7'), isFalse);
    });

    test('当前版本缺失或非法时视为 0.0.0', () {
      expect(isNewerVersion('1.0.0', ''), isTrue);
      expect(isNewerVersion('1.0.0', 'unknown'), isTrue);
    });
  });

  group('parseGithubRelease', () {
    test('解析可用更新并读取全部字段', () {
      final outcome = UpdateCheckOutcome.parseGithubRelease(
        _releaseJson(),
        currentVersion: '1.0.0',
      );

      expect(outcome, isA<UpdateAvailable>());
      final package = (outcome as UpdateAvailable).package;
      expect(package.versionName, '1.2.0');
      expect(
        package.downloadUrl,
        'https://github.com/zhao004/flutter_file_nest/releases/download/'
        'v1.2.0/filenest-v1.2.0.apk',
      );
      expect(package.filename, 'filenest-v1.2.0.apk');
      expect(package.filesize, 52428800);
      expect(package.sha256, 'abcd');
      expect(package.hasChecksum, isTrue);
      expect(package.releaseNotes, contains('支持多软件管理'));
      expect(package.forceUpdate, isFalse);
      expect(
        package.releaseTime?.toUtc(),
        DateTime.utc(2026, 8, 23, 6, 49, 14),
      );
    });

    test('版本不高于当前时视为已是最新', () {
      final outcome = UpdateCheckOutcome.parseGithubRelease(
        _releaseJson(tag: 'v1.0.0'),
        currentVersion: '1.0.0',
      );

      expect(outcome, isA<UpToDate>());
      expect((outcome as UpToDate).currentVersion, '1.0.0');
    });

    test('Release 正文包含 [force] 标记时强制更新', () {
      final outcome = UpdateCheckOutcome.parseGithubRelease(
        _releaseJson(body: '紧急修复\n[force]'),
        currentVersion: '1.0.0',
      );

      expect((outcome as UpdateAvailable).package.forceUpdate, isTrue);
    });

    test('缺少 apk 附件时返回可展示失败', () {
      final outcome = UpdateCheckOutcome.parseGithubRelease(
        _releaseJson(
          assets: const [
            {
              'name': 'filenest-v1.2.0.aab',
              'state': 'uploaded',
              'browser_download_url': 'https://example.com/app.aab',
            },
          ],
        ),
        currentVersion: '1.0.0',
      );

      expect(outcome, isA<UpdateCheckFailure>());
      expect(
        (outcome as UpdateCheckFailure).message,
        zhL10n.updateErrorNoPackage,
      );
    });

    test('未上传完成的附件不参与匹配', () {
      final outcome = UpdateCheckOutcome.parseGithubRelease(
        _releaseJson(
          assets: const [
            {
              'name': 'filenest-v1.2.0.apk',
              'state': 'new',
              'browser_download_url': 'https://example.com/app.apk',
            },
          ],
        ),
        currentVersion: '1.0.0',
      );

      expect(outcome, isA<UpdateCheckFailure>());
    });

    test('digest 缺失时跳过摘要校验', () {
      final outcome = UpdateCheckOutcome.parseGithubRelease(
        _releaseJson(digest: null),
        currentVersion: '1.0.0',
      );

      final package = (outcome as UpdateAvailable).package;
      expect(package.sha256, isEmpty);
      expect(package.hasChecksum, isFalse);
    });

    test('下载地址缺协议时抛出解析异常', () {
      expect(
        () => UpdateCheckOutcome.parseGithubRelease(
          _releaseJson(downloadUrl: 'example.com/app.apk'),
          currentVersion: '1.0.0',
        ),
        throwsFormatException,
      );
    });

    test('响应缺少 tag_name 时抛出解析异常', () {
      expect(
        () => UpdateCheckOutcome.parseGithubRelease(
          _releaseJson(tag: ''),
          currentVersion: '1.0.0',
        ),
        throwsFormatException,
      );
    });

    test('响应不是 JSON 对象时抛出解析异常', () {
      expect(
        () => UpdateCheckOutcome.parseGithubRelease(
          const [],
          currentVersion: '1.0.0',
        ),
        throwsFormatException,
      );
    });
  });
}

/// 构造 GitHub `releases/latest` 响应；默认包含 aab 与 apk 两个附件。
Map<Object?, Object?> _releaseJson({
  String tag = 'v1.2.0',
  String body = '## 新增\n- 支持多软件管理',
  String downloadUrl =
      'https://github.com/zhao004/flutter_file_nest/releases/download/'
      'v1.2.0/filenest-v1.2.0.apk',
  String? digest = 'sha256:abcd',
  List<Map<Object?, Object?>>? assets,
}) => {
  'tag_name': tag,
  'body': body,
  'published_at': '2026-08-23T06:49:14Z',
  'assets':
      assets ??
      [
        {
          'name': 'filenest-v1.2.0.aab',
          'state': 'uploaded',
          'browser_download_url': 'https://example.com/app.aab',
          'size': 1,
        },
        {
          'name': 'filenest-v1.2.0.apk',
          'state': 'uploaded',
          'browser_download_url': downloadUrl,
          'size': 52428800,
          'digest': digest,
        },
      ],
};
