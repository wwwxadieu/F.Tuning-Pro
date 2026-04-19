import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Holds information about a remote app version.
class FTuneRemoteVersion {
  const FTuneRemoteVersion({
    required this.version,
    required this.build,
    required this.releaseNotesVi,
    required this.releaseNotesEn,
    required this.exeDownloadUrl,
    required this.downloadUrl,
  });

  final String version;
  final int build;
  final String releaseNotesVi;
  final String releaseNotesEn;
  /// Direct URL to the new portable .exe file.
  final String exeDownloadUrl;
  /// Fallback page URL (GitHub Releases).
  final String downloadUrl;

  String releaseNotes(String languageCode) =>
      languageCode == 'vi' ? releaseNotesVi : releaseNotesEn;
}

/// Checks GitHub for a newer version of F.Tune Pro.
class FTuneUpdateChecker {
  FTuneUpdateChecker._();
  static final FTuneUpdateChecker instance = FTuneUpdateChecker._();

  static const String _versionUrl =
      'https://raw.githubusercontent.com/wwwxadieu/F.Tuning-Pro/main/version.json';

  /// Returns the remote version if it is newer than the installed build,
  /// or `null` if the app is up to date or the check failed.
  Future<FTuneRemoteVersion?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteBuild = (data['build'] as num?)?.toInt() ?? 0;
      final remoteVersion = (data['version'] as String?) ?? '';
      final notes = (data['release_notes'] as Map<String, dynamic>?) ?? {};
      final exeDownloadUrl = (data['exe_download_url'] as String?) ?? '';
      final downloadUrl =
          (data['download_url'] as String?) ?? _versionUrl;

      final info = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(info.buildNumber) ?? 0;

      if (remoteBuild <= localBuild) return null;

      return FTuneRemoteVersion(
        version: remoteVersion,
        build: remoteBuild,
        releaseNotesVi: (notes['vi'] as String?) ?? '',
        releaseNotesEn: (notes['en'] as String?) ?? '',
        exeDownloadUrl: exeDownloadUrl,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
