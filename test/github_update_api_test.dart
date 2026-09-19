import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:filenest/app/models/update_models.dart';
import 'package:filenest/app/services/update_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/localization.dart';

void main() {
  const build = AppBuildInfo(version: '1.0.0', buildNumber: 1);

  test('请求 GitHub 最新 Release 并携带约定请求头', () async {
    late http.Request captured;
    final api = GitHubUpdateApi(
      client: MockClient((request) async {
        captured = request;
        return _json(_releaseJson(), 200);
      }),
    );

    final outcome = await api.check(build);

    expect(outcome, isA<UpdateAvailable>());
    expect(
      captured.url.toString(),
      'https://api.github.com/repos/zhao004/flutter_file_nest/releases/latest',
    );
    expect(captured.headers['Accept'], 'application/vnd.github+json');
    expect(captured.headers['X-GitHub-Api-Version'], '2022-11-28');
    expect(captured.headers['User-Agent'], 'FileNest-Android');
  });

  test('仓库尚无 Release 时视为已是最新', () async {
    final api = GitHubUpdateApi(
      client: MockClient((request) async => http.Response('', 404)),
    );

    final outcome = await api.check(build);

    expect(outcome, isA<UpToDate>());
    expect((outcome as UpToDate).currentVersion, '1.0.0');
  });

  test('服务端错误返回可展示失败', () async {
    final api = GitHubUpdateApi(
      client: MockClient((request) async => http.Response('rate limited', 403)),
    );

    final outcome = await api.check(build);

    expect(outcome, isA<UpdateCheckFailure>());
    expect((outcome as UpdateCheckFailure).message, zhL10n.updateErrorResponse);
  });

  test('响应结构异常返回可展示失败', () async {
    final api = GitHubUpdateApi(
      client: MockClient((request) async => http.Response('<html>', 200)),
    );

    final outcome = await api.check(build);

    expect(outcome, isA<UpdateCheckFailure>());
    expect((outcome as UpdateCheckFailure).message, zhL10n.updateErrorResponse);
  });

  test('网络异常返回网络错误', () async {
    final api = GitHubUpdateApi(
      client: MockClient((request) async => throw http.ClientException('boom')),
    );

    final outcome = await api.check(build);

    expect(outcome, isA<UpdateCheckFailure>());
    expect((outcome as UpdateCheckFailure).message, zhL10n.updateErrorNetwork);
  });
}

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// 构造 GitHub `releases/latest` 响应；包含 aab 与 apk 两个附件。
Map<Object?, Object?> _releaseJson() => {
  'tag_name': 'v1.2.0',
  'body': '## 新增\n- 支持多软件管理',
  'published_at': '2026-08-23T06:49:14Z',
  'assets': [
    {
      'name': 'filenest-v1.2.0.aab',
      'state': 'uploaded',
      'browser_download_url': 'https://example.com/app.aab',
      'size': 1,
    },
    {
      'name': 'filenest-v1.2.0.apk',
      'state': 'uploaded',
      'browser_download_url': 'https://example.com/app.apk',
      'size': 52428800,
      'digest': 'sha256:abcd',
    },
  ],
};
