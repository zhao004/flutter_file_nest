import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../i18n/app_l10n.dart';
import '../models/update_models.dart';

/// GitHub Releases 检查与安装包下载配置。
abstract class UpdateApiConfig {
  UpdateApiConfig._();

  /// 发布仓库；与 `.github/workflows/android-release.yml` 的发布目标一致。
  static const githubOwner = 'zhao004';
  static const githubRepo = 'flutter_file_nest';
  static const githubApiBase = 'https://api.github.com';

  /// 显式声明 API 版本与 User-Agent；固定版本保证附件返回 `digest` 摘要。
  static const apiVersion = '2022-11-28';
  static const userAgent = 'FileNest-Android';

  /// 检查请求超时；下载仅限制建连阶段，流式传输由用户取消或网络错误终止。
  static const checkTimeout = Duration(seconds: 15);
  static const downloadConnectTimeout = Duration(seconds: 15);

  /// 安装包在应用缓存中的子目录与固定文件名。
  ///
  /// Android 安装器按同一约定校验路径，只允许安装该目录下的 APK。
  static const downloadDirectoryName = 'updates';
  static const downloadFileName = 'filenest-update.apk';
}

/// 下载进度；服务端未提供 Content-Length 时 [total] 为 null。
class UpdateDownloadProgress {
  const UpdateDownloadProgress({required this.received, this.total});

  final int received;
  final int? total;

  /// 0~1 的完成度；总大小未知时为 null（界面显示不确定进度）。
  double? get fraction {
    final total = this.total;
    if (total == null || total <= 0) return null;
    return (received / total).clamp(0, 1).toDouble();
  }
}

/// 正在进行的下载；取消会中止请求并由实现删除半成品文件。
class UpdateDownload {
  UpdateDownload({
    required this.progress,
    required this.file,
    required this._onCancel,
  });

  /// 下载进度事件流；下载结束时关闭。
  final Stream<UpdateDownloadProgress> progress;

  /// 完成后的本地安装包文件；失败时以异常结束。
  final Future<File> file;

  final void Function() _onCancel;

  void cancel() => _onCancel();
}

/// 下载失败；[message] 可直接展示。
class UpdateDownloadFailure implements Exception {
  const UpdateDownloadFailure(this.message);

  final String message;

  @override
  String toString() => 'UpdateDownloadFailure($message)';
}

/// 用户主动取消下载；不作为错误展示。
class UpdateDownloadCancelled implements Exception {
  const UpdateDownloadCancelled();

  @override
  String toString() => 'UpdateDownloadCancelled';
}

/// 更新接口；测试通过替代实现注入。
abstract interface class UpdateApi {
  /// 检查更新；网络或响应异常返回 [UpdateCheckFailure]，不抛异常。
  Future<UpdateCheckOutcome> check(AppBuildInfo build);

  /// 开始下载安装包到 [directory] 下；调用方监听进度并等待 [UpdateDownload.file]。
  UpdateDownload download(UpdatePackage package, Directory directory);
}

/// GitHub Releases 检查与应用内下载的 HTTP 实现。
class GitHubUpdateApi implements UpdateApi {
  GitHubUpdateApi({
    http.Client? client,
    http.Client Function()? downloadClient,
    this._owner = UpdateApiConfig.githubOwner,
    this._repo = UpdateApiConfig.githubRepo,
    this._apiBase = UpdateApiConfig.githubApiBase,
  }) : _client = client ?? http.Client(),
       _downloadClient = downloadClient ?? http.Client.new;

  final http.Client _client;

  /// 每次下载使用独立连接，取消时关闭它不会影响检查请求。
  final http.Client Function() _downloadClient;
  final String _owner;
  final String _repo;
  final String _apiBase;

  @override
  Future<UpdateCheckOutcome> check(AppBuildInfo build) async {
    final uri = Uri.parse('$_apiBase/repos/$_owner/$_repo/releases/latest');
    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': UpdateApiConfig.apiVersion,
              'User-Agent': UpdateApiConfig.userAgent,
            },
          )
          .timeout(UpdateApiConfig.checkTimeout);
      // 仓库尚未发布任何 Release：视为暂无可更新版本。
      if (response.statusCode == HttpStatus.notFound) {
        return UpToDate(build.version);
      }
      if (response.statusCode != HttpStatus.ok) {
        return UpdateCheckFailure(AppL10n.current.updateErrorResponse);
      }
      return UpdateCheckOutcome.parseGithubRelease(
        jsonDecode(utf8.decode(response.bodyBytes)),
        currentVersion: build.version,
      );
    } on FormatException {
      return UpdateCheckFailure(AppL10n.current.updateErrorResponse);
    } on Exception {
      return UpdateCheckFailure(AppL10n.current.updateErrorNetwork);
    }
  }

  @override
  UpdateDownload download(UpdatePackage package, Directory directory) {
    final progress = StreamController<UpdateDownloadProgress>();
    final client = _downloadClient();
    var cancelled = false;
    final target = File(
      '${directory.path}${Platform.pathSeparator}${UpdateApiConfig.downloadFileName}',
    );
    final partial = File('${target.path}.part');

    Future<File> run() async {
      try {
        final request = http.Request('GET', Uri.parse(package.downloadUrl));
        final response = await client
            .send(request)
            .timeout(UpdateApiConfig.downloadConnectTimeout);
        if (response.statusCode != HttpStatus.ok) {
          throw UpdateDownloadFailure(AppL10n.current.updateErrorDownload);
        }
        await directory.create(recursive: true);
        final total = response.contentLength;
        var received = 0;
        final sink = partial.openWrite();
        try {
          await for (final chunk in response.stream) {
            if (cancelled) throw const UpdateDownloadCancelled();
            sink.add(chunk);
            received += chunk.length;
            if (!progress.isClosed) {
              progress.add(
                UpdateDownloadProgress(received: received, total: total),
              );
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (cancelled) throw const UpdateDownloadCancelled();
        if (await target.exists()) await target.delete();
        return await partial.rename(target.path);
      } on UpdateDownloadCancelled {
        await _deleteQuietly(partial);
        rethrow;
      } on Exception catch (failure) {
        await _deleteQuietly(partial);
        if (cancelled) throw const UpdateDownloadCancelled();
        if (failure is UpdateDownloadFailure) rethrow;
        throw UpdateDownloadFailure(AppL10n.current.updateErrorDownload);
      } finally {
        client.close();
        await progress.close();
      }
    }

    return UpdateDownload(
      progress: progress.stream,
      file: run(),
      onCancel: () {
        cancelled = true;
        client.close();
      },
    );
  }

  /// 清理半成品；失败不影响结果上报。
  Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      /* 文件可能尚未创建。 */
    }
  }
}
