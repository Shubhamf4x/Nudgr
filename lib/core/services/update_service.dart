import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import '../constants/app_constants.dart';

class UpdateService {
  static const String _apiBase = 'https://api.github.com/repos';

  UpdateService._();

  static Future<UpdateCheckResult> checkForUpdate() async {
    final repo = AppConstants.githubRepo;
    if (repo.isEmpty || repo.contains('YOUR_')) {
      return const UpdateCheckError(
        'Updates are not configured yet. Set your GitHub repo in '
        'lib/core/constants/app_constants.dart.',
      );
    }

    final PackageInfo packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      return const UpdateCheckError('Could not read the current app version.');
    }

    final Uri uri;
    try {
      uri = Uri.parse('$_apiBase/$repo/releases/latest');
    } catch (_) {
      return const UpdateCheckError('Invalid update repository configuration.');
    }

    final Map<String, dynamic> release;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'Nudgr-App');
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        return UpdateCheckError(
          response.statusCode == 404
              ? 'No releases published yet. Upload an APK in a GitHub Release.'
              : 'Could not reach the update server (${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const UpdateCheckError('Unexpected response from update server.');
      }
      release = decoded;
    } on TimeoutException {
      return const UpdateCheckError('Connection timed out. Try again later.');
    } on SocketException {
      return const UpdateCheckError('No internet connection.');
    } catch (_) {
      return const UpdateCheckError('Could not check for updates.');
    }

    final latestTag = (release['tag_name'] as String?)?.trim() ?? '';
    if (latestTag.isEmpty) {
      return const UpdateCheckError('The latest release has no version tag.');
    }

    final remoteVersion = _normalizeVersion(latestTag);
    final localVersion = packageInfo.version;

    final isNewer = _isNewerVersion(remoteVersion, localVersion);

    if (!isNewer) {
      return UpdateUpToDate(currentVersion: localVersion);
    }

    String? downloadUrl;
    final assets = release['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final url = asset['browser_download_url'] as String?;
          if (url != null && name.endsWith('.apk')) {
            downloadUrl = url;
            break;
          }
        }
      }
    }
    downloadUrl ??=
        release['html_url'] as String? ?? 'https://github.com/$repo/releases';

    return UpdateAvailable(
      currentVersion: localVersion,
      latestVersion: _normalizeVersion(latestTag),
      releaseNotes: (release['body'] as String?) ?? '',
      downloadUrl: downloadUrl,
    );
  }

  static String _normalizeVersion(String tag) {
    var v = tag.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    final plus = v.indexOf('+');
    if (plus >= 0) v = v.substring(0, plus);
    if (v.startsWith('-')) v = v.substring(1);
    return v;
  }

  static bool _isNewerVersion(String remote, String local) {
    final r = _parseSegments(remote);
    final l = _parseSegments(local);
    final len = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  static List<int> _parseSegments(String version) {
    return version
        .split(RegExp(r'[.\-_\s]'))
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
  }
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateAvailable({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class UpdateUpToDate extends UpdateCheckResult {
  final String currentVersion;

  const UpdateUpToDate({required this.currentVersion});
}

class UpdateCheckError extends UpdateCheckResult {
  final String message;

  const UpdateCheckError(this.message);
}
