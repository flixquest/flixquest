import 'package:flixquest/video_providers/common.dart';
import 'package:better_player_plus/better_player.dart';

class VideoUtils {
  static const int _automaticFallbackHeight = 720;

  static const Set<int> _commonVideoHeights = {
    144,
    240,
    360,
    480,
    540,
    576,
    720,
    1080,
    1440,
    2160,
    4320,
  };

  /// Extract the vertical resolution from provider labels such as `480p AAC`,
  /// `480 AAC`, `1920x1080`, or `1080P (HEVC)`.
  ///
  /// Bare numbers are restricted to common video heights so audio bitrates and
  /// other metadata in the same label aren't mistaken for a resolution.
  static int? videoQualityHeight(String label) {
    final dimensions = RegExp(
      r'(?<!\d)(\d{2,5})\s*[x×]\s*(\d{3,4})(?!\d)',
      caseSensitive: false,
    ).firstMatch(label);
    if (dimensions != null) {
      return int.tryParse(dimensions.group(2)!);
    }

    final explicitHeight = RegExp(
      r'(?<!\d)(\d{3,4})\s*p\b',
      caseSensitive: false,
    ).firstMatch(label);
    if (explicitHeight != null) {
      return int.tryParse(explicitHeight.group(1)!);
    }

    for (final match in RegExp(r'(?<!\d)(\d{3,4})(?!\d)').allMatches(label)) {
      final height = int.tryParse(match.group(1)!);
      if (height != null && _commonVideoHeights.contains(height)) {
        return height;
      }
    }
    return null;
  }

  /// Pick a provider quality using the player's saved height preference.
  ///
  /// `0` first honors a provider's explicit Auto/Automatic master playlist. If
  /// the provider only exposes separate fixed-quality URLs, 720p is used as a
  /// conservative automatic ceiling. This avoids treating unrelated host
  /// labels (for example, `Voesx`) as an adaptive source merely because they
  /// happen to be first in the response.
  ///
  /// For a missing exact height, the preference behaves as a ceiling; if every
  /// source is larger, the smallest source is used.
  static MapEntry<String, T>? preferredVideoSource<T>(
    Map<String, T> sources,
    int preferredHeight,
  ) {
    if (sources.isEmpty) return null;

    if (preferredHeight == 0) {
      for (final entry in sources.entries) {
        if (RegExp(
          r'^\s*auto(?:matic)?\b',
          caseSensitive: false,
        ).hasMatch(entry.key)) {
          return entry;
        }
      }
    }

    final measured = <({MapEntry<String, T> entry, int height})>[];
    for (final entry in sources.entries) {
      final height = videoQualityHeight(entry.key);
      if (height != null) measured.add((entry: entry, height: height));
    }
    if (measured.isEmpty) return sources.entries.first;

    final targetHeight =
        preferredHeight == 0 ? _automaticFallbackHeight : preferredHeight;

    for (final source in measured) {
      if (source.height == targetHeight) return source.entry;
    }

    final atOrBelow = measured.where(
      (source) => source.height <= targetHeight,
    );
    if (atOrBelow.isNotEmpty) {
      return atOrBelow
          .reduce(
            (best, source) => source.height > best.height ? source : best,
          )
          .entry;
    }
    return measured
        .reduce(
          (best, source) => source.height < best.height ? source : best,
        )
        .entry;
  }

  /// The source a download at [preferredHeight] takes; 0 means the tallest.
  /// [exact] is whether that height is on offer: labelled, or inside an
  /// adaptive stream the download caps at it. Otherwise the source is the
  /// nearest below, as for playback.
  static ({MapEntry<String, T> entry, bool exact})? downloadSource<T>(
    Map<String, T> sources,
    int preferredHeight,
  ) {
    if (sources.isEmpty) return null;
    final measured = <({MapEntry<String, T> entry, int height})>[];
    MapEntry<String, T>? adaptive;
    for (final entry in sources.entries) {
      final height = videoQualityHeight(entry.key);
      if (height == null) {
        adaptive ??= entry;
      } else {
        measured.add((entry: entry, height: height));
      }
    }
    if (preferredHeight == 0) {
      if (measured.isEmpty) return (entry: adaptive!, exact: true);
      final tallest = measured.reduce(
        (best, source) => source.height > best.height ? source : best,
      );
      return (entry: tallest.entry, exact: true);
    }
    for (final source in measured) {
      if (source.height == preferredHeight) {
        return (entry: source.entry, exact: true);
      }
    }
    if (adaptive != null) return (entry: adaptive, exact: true);
    return (
      entry: preferredVideoSource(sources, preferredHeight)!,
      exact: false
    );
  }

  /// Convert video links to a map format for the player
  static Map<String, String> convertVideoLinksToMap(
      List<RegularVideoLinks> vids) {
    final videos = <String, String>{};
    final keys = _videoSourceKeys(vids);
    for (int k = 0; k < vids.length; k++) {
      videos[keys[k]] = vids[k].url!;
    }
    return videos;
  }

  /// Preserve the stream type supplied by the scraper API. Its proxy URLs do
  /// not always end in `.m3u8` or `.mpd`, so URL inference alone is not enough
  /// for Better Player to choose HLS/DASH playback correctly.
  static Map<String, BetterPlayerVideoFormat?> convertVideoFormatsToMap(
    List<RegularVideoLinks> vids,
  ) {
    final formats = <String, BetterPlayerVideoFormat?>{};
    final keys = _videoSourceKeys(vids);
    for (var index = 0; index < vids.length; index++) {
      final key = keys[index];
      formats[key] = vids[index].isM3U8 == true
          ? BetterPlayerVideoFormat.hls
          : vids[index].isDash == true
              ? BetterPlayerVideoFormat.dash
              : null;
    }
    return formats;
  }

  /// Keep the request headers associated with each quality. Stream providers
  /// may require values such as Referer or Origin for direct playback.
  static Map<String, Map<String, String>> convertVideoHeadersToMap(
    List<RegularVideoLinks> vids,
  ) {
    final headers = <String, Map<String, String>>{};
    final keys = _videoSourceKeys(vids);
    for (var index = 0; index < vids.length; index++) {
      final linkHeaders = vids[index].headers;
      if (linkHeaders == null || linkHeaders.isEmpty) continue;
      final key = keys[index];
      headers[key] = Map.of(linkHeaders);
    }
    return headers;
  }

  /// Keep signed stream-size tokens aligned with the URL, format, and header
  /// maps, including duplicate qualities returned by different servers.
  static Map<String, String> convertVideoSizeTokensToMap(
    List<RegularVideoLinks> vids,
  ) {
    final tokens = <String, String>{};
    final keys = _videoSourceKeys(vids);
    for (var index = 0; index < vids.length; index++) {
      final token = vids[index].sizeToken?.trim();
      if (token == null || token.isEmpty) continue;
      tokens[keys[index]] = token;
    }
    return tokens;
  }

  /// Build stable display keys without collapsing same-quality links returned
  /// by different servers. All source metadata maps use this same key list so
  /// URLs, formats, and headers remain aligned.
  static List<String> _videoSourceKeys(List<RegularVideoLinks> vids) {
    final qualityCounts = <String, int>{};
    for (final video in vids) {
      final quality = video.quality ?? 'unknown quality';
      qualityCounts[quality] = (qualityCounts[quality] ?? 0) + 1;
    }

    final usedKeys = <String>{};
    return [
      for (var index = 0; index < vids.length; index++)
        () {
          final video = vids[index];
          final quality = video.quality ?? 'unknown quality';
          final server = video.server?.trim();
          var key = quality == 'unknown quality'
              ? '$quality $index'
              : qualityCounts[quality]! > 1 && server?.isNotEmpty == true
                  ? '$quality · $server'
                  : quality;
          final baseKey = key;
          var occurrence = 1;
          while (!usedKeys.add(key)) {
            occurrence++;
            key = '$baseKey ($occurrence)';
          }
          return key;
        }(),
    ];
  }

  /// Provider defaults used when a source does not explicitly return headers.
  /// These must be shared by streaming and offline downloads because manifests,
  /// segments, redirects, and encryption keys can all enforce the same origin.
  static Map<String, String>? inferVideoHeaders(String? url) {
    final host = Uri.tryParse(url ?? '')?.host.toLowerCase();
    if (host == null || !host.endsWith('vixsrc.to')) return null;

    return const {
      'accept': '*/*',
      'origin': 'https://vixsrc.to',
      'referer': 'https://vixsrc.to/',
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    };
  }

  /// Process VTT file timestamps to fix formatting issues
  static String processVttFileTimestamps(String vttContent) {
    final lines = vttContent.split('\n');
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

  /// Parse and create BetterPlayer subtitle sources from subtitle links
  static Future<List<BetterPlayerSubtitlesSource>> parseSubtitles({
    required List<RegularSubtitleLinks> subtitles,
    required String defaultLanguage,
    required bool fetchAllLanguages,
    required Future<String> Function(String) getVttContent,
  }) async {
    List<BetterPlayerSubtitlesSource> subs = [];

    if (subtitles.isEmpty) {
      return subs;
    }

    // If no specific language preference, fetch all
    if (defaultLanguage.isEmpty) {
      for (int i = 0; i < subtitles.length; i++) {
        try {
          final content = await getVttContent(subtitles[i].url!);
          subs.add(
            BetterPlayerSubtitlesSource(
              name: subtitles[i].language!,
              selectedByDefault: _isDefaultEnglish(subtitles[i].language!),
              content: subtitles[i].url!.endsWith('srt')
                  ? content
                  : processVttFileTimestamps(content),
              type: BetterPlayerSubtitlesSourceType.memory,
            ),
          );
        } catch (e) {
          // Skip failed subtitle
          continue;
        }
      }
    } else {
      // Check if preferred language exists
      final hasPreferredLanguage = subtitles.any((sub) =>
          sub.language!
              .toLowerCase()
              .startsWith(defaultLanguage.toLowerCase()) ||
          sub.language == defaultLanguage);

      if (hasPreferredLanguage) {
        if (fetchAllLanguages) {
          // Fetch all languages but prioritize preferred
          for (int i = 0; i < subtitles.length; i++) {
            try {
              final content = await getVttContent(subtitles[i].url!);
              final isPreferred = subtitles[i]
                      .language!
                      .toLowerCase()
                      .startsWith(defaultLanguage.toLowerCase()) ||
                  subtitles[i].language == defaultLanguage;

              subs.add(
                BetterPlayerSubtitlesSource(
                  name: subtitles[i].language!,
                  selectedByDefault: isPreferred,
                  content: subtitles[i].url!.endsWith('srt')
                      ? content
                      : processVttFileTimestamps(content),
                  type: BetterPlayerSubtitlesSourceType.memory,
                ),
              );
            } catch (e) {
              continue;
            }
          }
        } else {
          // Fetch only preferred language (first match)
          for (int i = 0; i < subtitles.length; i++) {
            if (subtitles[i]
                    .language!
                    .toLowerCase()
                    .startsWith(defaultLanguage.toLowerCase()) ||
                subtitles[i].language == defaultLanguage) {
              try {
                final content = await getVttContent(subtitles[i].url!);
                subs.add(
                  BetterPlayerSubtitlesSource(
                    name: subtitles[i].language!,
                    selectedByDefault: true,
                    content: subtitles[i].url!.endsWith('srt')
                        ? content
                        : processVttFileTimestamps(content),
                    type: BetterPlayerSubtitlesSourceType.memory,
                  ),
                );
                break;
              } catch (e) {
                continue;
              }
            }
          }
        }
      }
    }

    return subs;
  }

  /// Check if language should be default English
  static bool _isDefaultEnglish(String language) {
    return language == 'English' ||
        language == 'English - English' ||
        language == 'English - SDH' ||
        language == 'English 1' ||
        language == 'English - English [CC]' ||
        language == 'en';
  }

  /// Order measurable video qualities from highest to lowest while keeping
  /// provider-specific, non-quality labels stable at the end.
  ///
  /// The legacy method name is retained because movie, TV, download, and
  /// provider-switching flows all share it.
  static Map<String, T> reverseVideoQualityMap<T>(Map<String, T> videos) {
    final indexedEntries = videos.entries.indexed.toList();
    indexedEntries.sort((left, right) {
      final leftHeight = videoQualityHeight(left.$2.key);
      final rightHeight = videoQualityHeight(right.$2.key);
      if (leftHeight != null && rightHeight != null) {
        final heightComparison = rightHeight.compareTo(leftHeight);
        return heightComparison != 0
            ? heightComparison
            : left.$1.compareTo(right.$1);
      }
      if (leftHeight != null) return -1;
      if (rightHeight != null) return 1;
      return left.$1.compareTo(right.$1);
    });
    return Map.fromEntries(indexedEntries.map((entry) => entry.$2));
  }
}
