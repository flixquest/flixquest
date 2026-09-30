import 'dart:io';
import 'dart:math';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_constants.dart';

String episodeSeasonFormatter(int episodeNumber, int seasonNumber) {
  String formattedSeason =
      seasonNumber <= 9 ? 'S0$seasonNumber' : 'S$seasonNumber';
  String formattedEpisode =
      episodeNumber <= 9 ? 'E0$episodeNumber' : 'E$episodeNumber';
  return '$formattedSeason : $formattedEpisode';
}

Future<void> requestNotificationPermissions() async {
  final PermissionStatus status = await Permission.notification.status;
  if (!status.isGranted && !status.isPermanentlyDenied) {
    await Permission.notification.request();
  }
}

Future<bool> checkConnection() async {
  bool? isInternetWorking;
  try {
    final response = await InternetAddress.lookup('google.com');

    isInternetWorking = response.isNotEmpty;
  } on SocketException catch (e) {
    debugPrint(e.toString());
    isInternetWorking = false;
  }

  return isInternetWorking;
}

String normalizeTitle(String title) {
  return title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[":\']'), '')
      .replaceAll(RegExp('[^a-z0-9 ]+'), '_');
}

Future<bool> clearTempCache() async {
  try {
    Directory tempDir = await getTemporaryDirectory();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
      return true;
    } else {
      return false;
    }
  } catch (e) {
    throw Exception('Failed to clear temp files');
  }
}

Future<bool> clearCache() async {
  try {
    Directory cacheDir = await getApplicationCacheDirectory();
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
      return true;
    } else {
      return false;
    }
  } catch (e) {
    throw Exception('Failed to clear cache');
  }
}

/// Removes Better Player's persistent streaming cache without touching image,
/// database, or other application caches.
///
/// Movie playback no longer uses a persistent media cache, but older app
/// versions may have left a large cache behind on storage-constrained TVs.
Future<void> clearVideoPlaybackCache() async {
  try {
    final cacheDir = await getApplicationCacheDirectory();
    final videoCacheDir = Directory(
      '${cacheDir.path}${Platform.pathSeparator}betterPlayerCache',
    );
    if (await videoCacheDir.exists()) {
      await videoCacheDir.delete(recursive: true);
    }
  } catch (error) {
    debugPrint('Unable to clear the video playback cache: $error');
  }
}

void fileDelete() async {
  for (int i = 0; i < appNames.length; i++) {
    File file =
        // ignore: prefer_single_quotes
        File("${(await getApplicationCacheDirectory()).path}${appNames[i]}");
    if (file.existsSync()) {
      file.delete();
    }
  }
}

int totalStreamingDuration = 0; // Keep track of the total streaming duration

// Function to update and log the aggregate streaming duration
void updateAndLogTotalStreamingDuration(int durationInSeconds) {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  totalStreamingDuration += durationInSeconds;

  // Log the new total duration as a custom event for tracking purposes
  analytics.logEvent(
    name: 'total_streaming_duration',
    parameters: <String, Object>{
      'duration_seconds': totalStreamingDuration,
    },
  );
}

String generateCacheKey() {
  Random random = Random();

  List<String> characters = [];
  String generatedChars = '';

  for (var i = 0; i < 26; i++) {
    characters.add(String.fromCharCode(97 + i)); // Lowercase letters a-z
  }

  for (var i = 0; i < 26; i++) {
    characters.add(String.fromCharCode(65 + i)); // Uppercase letters A-Z
  }

  for (var i = 0; i < 10; i++) {
    characters.add(i.toString()); // Numbers 0-9
  }

  characters.add('-');

  int min = 0;
  int max = characters.length - 1;
  int randomInt;

  for (int i = 0; i < 50; i++) {
    randomInt = min + random.nextInt(max - min + 1);
    generatedChars += characters[randomInt];
  }

  return generatedChars;
}

String processVttFileTimestamps(String vttFile) {
  final lines = vttFile.split('\n');
  final processedLines = <String>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('-->') && line.trim().length == 23) {
      String endTimeModifiedString =
          '${line.trim().substring(0, line.trim().length - 9)}00:${line.trim().substring(line.trim().length - 9)}';
      String finalStr = '00:$endTimeModifiedString';
      processedLines.add(finalStr);
    } else {
      processedLines.add(line);
    }
  }

  return processedLines.join('\n');
}

bool isReleased(String target) {
  final DateTime? mediaDate = _parseMediaDate(target);
  if (mediaDate == null) return true;
  DateTime currentDate = DateTime.now();
  return mediaDate.isBefore(currentDate) ||
      mediaDate.isAtSameMomentAs(currentDate);
}

DateTime? _parseMediaDate(String target) {
  final DateTime? fullDate = DateTime.tryParse(target);
  if (fullDate != null) return fullDate;
  final DateTime? yearOnly = DateFormat('yyyy').tryParse(target);
  return yearOnly == null ? null : DateTime(yearOnly.year);
}

int createUniqueId() {
  return DateTime.now().millisecondsSinceEpoch.remainder(100000);
}

const Map<String, String> _searchAccentMap = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'æ': 'ae', 'œ': 'oe', 'ý': 'y', 'ÿ': 'y',
};

/// Folds text for tolerant searching: lowercase, strips accents, and
/// collapses punctuation and other non-alphanumeric characters into spaces.
String normalizeSearchText(String value) {
  var folded = value.toLowerCase().trim();
  for (final entry in _searchAccentMap.entries) {
    folded = folded.replaceAll(entry.key, entry.value);
  }
  return folded.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ').replaceAll('  ', ' ');
}

/// Splits a search query into folded tokens. All tokens must match for a
/// result to be included, which keeps multi-word queries useful.
List<String> searchTokens(String query) {
  return normalizeSearchText(query)
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

String buildImageUrl(String baseImage, String proxyUrl, bool isProxyEnabled,
    BuildContext context) {
  String concatenated = baseImage;
  if (isProxyEnabled && proxyUrl.isNotEmpty) {
    concatenated = '$proxyUrl?destination=$baseImage';
  }

  return concatenated;
}
