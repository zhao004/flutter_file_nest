import '../i18n/app_l10n.dart';

/// GitHub Release 正文包含该标记时视为强制更新。
const updateForceMarker = '[force]';

/// 版本号前缀 `v`；GitHub tag 约定带 `v`，比较与展示前统一去除。
final RegExp _leadingV = RegExp('^v', caseSensitive: false);

/// 应用当前构建版本；更新检查的版本比较与设置页展示来源。
class AppBuildInfo {
  const AppBuildInfo({required this.version, this.buildNumber});

  /// 语义化版本名（如 1.0.0）；平台读取失败时为空字符串。
  final String version;

  /// 构建号（Android versionCode）；读取失败时为 null，仅用于设置页展示。
  final int? buildNumber;

  /// 设置页与提示使用的展示文本。
  String get label => buildNumber == null ? version : '$version ($buildNumber)';
}

/// 从 Release tag 提取版本名；去掉可选的 `v` 前缀。
String parseReleaseVersion(String? tag) =>
    (tag ?? '').trim().replaceFirst(_leadingV, '');

/// 判断 [latest] 是否高于 [current]。
///
/// 解析 `X.Y.Z` 与可选 `-预发布` 后缀，缺省段按 0 处理；同号正式版高于
/// 预发布版；[current] 无法解析时按 0.0.0 处理，版本读取失败时仍能提示更新。
bool isNewerVersion(String latest, String current) {
  final left = _Version.parse(latest);
  final right = _Version.parse(current);
  for (var index = 0; index < _Version.segmentCount; index++) {
    if (left.segments[index] != right.segments[index]) {
      return left.segments[index] > right.segments[index];
    }
  }
  if (left.preRelease.isEmpty || right.preRelease.isEmpty) {
    // 同号版本：正式版高于预发布版。
    return left.preRelease.isEmpty && right.preRelease.isNotEmpty;
  }
  return _comparePreRelease(left.preRelease, right.preRelease) > 0;
}

/// 已解析版本号；[segments] 固定 major/minor/patch 三段。
class _Version {
  const _Version(this.segments, this.preRelease);

  static const segmentCount = 3;

  /// 构建元数据（`+` 之后）不参与比较，非数字段按 0 处理。
  factory _Version.parse(String version) {
    final withoutBuild = version
        .trim()
        .replaceFirst(_leadingV, '')
        .split('+')
        .first;
    final sections = withoutBuild.split('-');
    final core = sections.first.split('.');
    final segments = List<int>.generate(
      segmentCount,
      (index) => index < core.length ? int.tryParse(core[index]) ?? 0 : 0,
    );
    final preRelease = sections.length > 1
        ? sections.sublist(1).join('-').split('.')
        : const <String>[];
    return _Version(segments, preRelease);
  }

  final List<int> segments;
  final List<String> preRelease;
}

/// 比较预发布标识；数字标识符低于字母标识符，逐段比较后短序列更小。
int _comparePreRelease(List<String> left, List<String> right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final result = _compareIdentifier(left[index], right[index]);
    if (result != 0) return result;
  }
  return left.length.compareTo(right.length);
}

int _compareIdentifier(String left, String right) {
  final leftNumber = int.tryParse(left);
  final rightNumber = int.tryParse(right);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  if (leftNumber != null) return -1;
  if (rightNumber != null) return 1;
  return left.compareTo(right);
}

/// GitHub Release 中的可用更新及其 APK 附件描述。
class UpdatePackage {
  const UpdatePackage({
    required this.versionName,
    required this.downloadUrl,
    this.filename = '',
    this.filesize,
    this.sha256 = '',
    this.forceUpdate = false,
    this.releaseTime,
    this.releaseNotes = '',
  });

  /// 从 `releases/latest` 响应与已匹配的 APK 附件解析。
  ///
  /// 版本名或 http(s) 下载地址缺失时抛出 [FormatException]；校验失败由调用方
  /// 转为可展示的错误，避免把不可信地址交给下载器。
  factory UpdatePackage.fromGithubRelease(
    Map<Object?, Object?> release,
    Map<Object?, Object?> apkAsset,
  ) {
    final versionName = parseReleaseVersion(release['tag_name'] as String?);
    final downloadUrl =
        (apkAsset['browser_download_url'] as String?)?.trim() ?? '';
    final uri = Uri.tryParse(downloadUrl);
    final schemeAllowed =
        uri != null && (uri.isScheme('http') || uri.isScheme('https'));
    if (versionName.isEmpty || !schemeAllowed) {
      throw const FormatException('更新响应缺少有效版本名或下载地址');
    }
    final publishedAt = DateTime.tryParse(
      (release['published_at'] as String?)?.trim() ?? '',
    );
    return UpdatePackage(
      versionName: versionName,
      downloadUrl: downloadUrl,
      filename: apkAsset['name'] as String? ?? '',
      filesize: (apkAsset['size'] as num?)?.toInt(),
      sha256: _parseSha256Digest(apkAsset['digest']),
      forceUpdate: (release['body'] as String? ?? '').contains(
        updateForceMarker,
      ),
      releaseTime: publishedAt?.toLocal(),
      releaseNotes: release['body'] as String? ?? '',
    );
  }

  final String versionName;
  final String downloadUrl;

  /// APK 附件名称；GitHub 未提供时为空字符串。
  final String filename;

  /// 安装包字节数；GitHub 未提供时为 null。
  final int? filesize;

  /// GitHub asset digest（已去除 `sha256:` 前缀）；缺失时为空字符串。
  final String sha256;

  /// Release 正文含 [updateForceMarker] 时为 true，强制更新时弹窗不可关闭。
  final bool forceUpdate;
  final DateTime? releaseTime;

  /// Release 正文；GitHub 固定为 Markdown。
  final String releaseNotes;

  /// 是否提供了可用于完整性校验的摘要。
  bool get hasChecksum => sha256.isNotEmpty;
}

/// 解析 asset `digest` 字段（如 `sha256:abcd`）；非 sha256 格式按缺失处理。
String _parseSha256Digest(Object? digest) {
  final value = (digest as String? ?? '').trim().toLowerCase();
  const prefix = 'sha256:';
  if (!value.startsWith(prefix)) return '';
  return value.substring(prefix.length);
}

/// 检查更新的业务结果；失败原因可直接展示（GitHub 异常或本地化文案）。
sealed class UpdateCheckOutcome {
  const UpdateCheckOutcome();

  /// 解析 GitHub `releases/latest` 响应。
  ///
  /// tag 有效且高于 [currentVersion]、同时存在已上传的 `.apk` 附件时返回可用
  /// 更新；无更高版本视为已是最新；有新版本但缺少安装包返回可展示失败；
  /// 结构异常抛出 [FormatException] 由调用方转为错误结果。
  static UpdateCheckOutcome parseGithubRelease(
    Object? decoded, {
    required String currentVersion,
  }) {
    if (decoded is! Map) throw const FormatException('响应不是 JSON 对象');
    final version = parseReleaseVersion(decoded['tag_name'] as String?);
    if (version.isEmpty) throw const FormatException('响应缺少 tag_name');
    if (!isNewerVersion(version, currentVersion)) {
      return UpToDate(currentVersion);
    }
    final asset = _findApkAsset(decoded['assets']);
    if (asset == null) {
      return UpdateCheckFailure(AppL10n.current.updateErrorNoPackage);
    }
    return UpdateAvailable(UpdatePackage.fromGithubRelease(decoded, asset));
  }
}

/// 选择第一个名称以 `.apk` 结尾且已上传的附件。
Map<Object?, Object?>? _findApkAsset(Object? assets) {
  if (assets is! List) return null;
  for (final asset in assets) {
    if (asset is! Map) continue;
    if (asset['state'] != 'uploaded') continue;
    final name = asset['name'];
    if (name is String && name.toLowerCase().endsWith('.apk')) {
      return asset;
    }
  }
  return null;
}

/// 存在更高版本且已匹配到安装包。
class UpdateAvailable extends UpdateCheckOutcome {
  const UpdateAvailable(this.package);

  final UpdatePackage package;
}

/// 无更高版本或版本缺少可用安装包。
class UpToDate extends UpdateCheckOutcome {
  const UpToDate(this.currentVersion);

  final String currentVersion;
}

/// 检查失败；[message] 为可展示原因。
class UpdateCheckFailure extends UpdateCheckOutcome {
  const UpdateCheckFailure(this.message);

  final String message;
}
