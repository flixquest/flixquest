import 'package:package_info_plus/package_info_plus.dart';

/// Version comparison and notification identity for the in-feed update prompt.
class AppUpdateService {
  const AppUpdateService._();

  static int effectiveBuildNumber({
    required int latestBuildNumber,
    required int minimumBuildNumber,
  }) {
    return latestBuildNumber > 0 ? latestBuildNumber : minimumBuildNumber;
  }

  static bool isAvailable({
    required PackageInfo packageInfo,
    required String remoteVersion,
    required int latestBuildNumber,
    required int minimumBuildNumber,
  }) {
    final remoteBuild = effectiveBuildNumber(
      latestBuildNumber: latestBuildNumber,
      minimumBuildNumber: minimumBuildNumber,
    );
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    if (remoteBuild > 0) return currentBuild < remoteBuild;

    final normalizedRemote = remoteVersion.trim();
    return normalizedRemote.isNotEmpty &&
        compareVersions(normalizedRemote, packageInfo.version) > 0;
  }

  static String notificationId({
    required String remoteVersion,
    required int latestBuildNumber,
    required int minimumBuildNumber,
  }) {
    final remoteBuild = effectiveBuildNumber(
      latestBuildNumber: latestBuildNumber,
      minimumBuildNumber: minimumBuildNumber,
    );
    return remoteBuild > 0 ? remoteBuild.toString() : remoteVersion.trim();
  }

  static int compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftPart = index < leftParts.length ? leftParts[index] : 0;
      final rightPart = index < rightParts.length ? rightParts[index] : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }
    return 0;
  }

  static List<int> _versionParts(String version) {
    return version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  static String displayVersion(String remoteVersion, int remoteBuild) {
    final version = remoteVersion.trim();
    if (version.isNotEmpty) return version;
    return remoteBuild > 0 ? remoteBuild.toString() : '';
  }

  /// The changelog as one entry per line, list markers stripped, so a long
  /// remote string can be previewed a few lines at a time.
  static List<String> changelogItems(String changeLog) => changeLog
      .split('\n')
      .map((line) =>
          line.trim().replaceFirst(RegExp(r'^(?:#+|[-*•·]|\d+[.)])\s+'), ''))
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}
