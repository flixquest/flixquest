import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';

/// Service to translate subtitle files (SRT or WebVTT) for free without API keys.
///
/// Uses the Google Translate web endpoint (client=gtx), batches cues for network
/// efficiency, and applies natural Indonesian pronoun rules when translating to
/// Indonesian.
class SubtitleTranslationService {
  SubtitleTranslationService._();

  static final SubtitleTranslationService instance =
      SubtitleTranslationService._();

  final Map<String, String> _cache = <String, String>{};

  static final RegExp _kamulahAndalahRegex =
      RegExp(r'\b(kamulah|andalah)\b', caseSensitive: false);
  static final RegExp _kamuAndaRegex =
      RegExp(r'\b(kamu|anda)\b', caseSensitive: false);
  static final RegExp _sayaRegex =
      RegExp(r'\b(saya)\b', caseSensitive: false);

  /// Matches the capitalization of [original] to choose the appropriate form.
  static String matchCase(
    String original, {
    required String uppercase,
    required String capitalized,
    required String lowercase,
  }) {
    if (original == original.toUpperCase()) return uppercase;
    if (original.isNotEmpty && original[0] == original[0].toUpperCase()) {
      return capitalized;
    }
    return lowercase;
  }

  /// Replaces pronouns according to Indonesian subtitle guidelines:
  /// - KAMU / ANDA -> KAU (case-matched)
  /// - SAYA -> AKU (case-matched)
  /// - KAMULAH / ANDALAH -> KAULAH (case-matched)
  ///
  /// Uses regex word boundaries so words containing these substrings (such as
  /// "pandai", "sayap", "menyayangi") are left unchanged.
  static String applyIndonesianPronounRules(String text) {
    if (text.isEmpty) return text;

    var result = text;

    // 1. Kamulah / Andalah -> Kaulah
    result = result.replaceAllMapped(_kamulahAndalahRegex, (match) {
      final original = match[0]!;
      return matchCase(
        original,
        uppercase: 'KAULAH',
        capitalized: 'Kaulah',
        lowercase: 'kaulah',
      );
    });

    // 2. Kamu / Anda -> Kau
    result = result.replaceAllMapped(_kamuAndaRegex, (match) {
      final original = match[0]!;
      return matchCase(
        original,
        uppercase: 'KAU',
        capitalized: 'Kau',
        lowercase: 'kau',
      );
    });

    // 3. Saya -> Aku
    result = result.replaceAllMapped(_sayaRegex, (match) {
      final original = match[0]!;
      return matchCase(
        original,
        uppercase: 'AKU',
        capitalized: 'Aku',
        lowercase: 'aku',
      );
    });

    return result;
  }

  /// Fixes WebVTT timestamps if needed
  static String processVttTimestamps(String vttContent) {
    final lines = vttContent.split('\n');
    final processedLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.contains('-->') && trimmed.length == 23) {
        final endTimeModifiedString =
            '${trimmed.substring(0, trimmed.length - 9)}00:${trimmed.substring(trimmed.length - 9)}';
        processedLines.add('00:$endTimeModifiedString');
      } else {
        processedLines.add(line);
      }
    }

    return processedLines.join('\n');
  }

  /// Translates a raw text string using the free Google Translate web endpoint.
  Future<String> translateText(
    String text, {
    required String targetLanguage,
    http.Client? client,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;

    final target = targetLanguage.toLowerCase().split(RegExp('[-_]')).first;
    final httpClient = client ?? http.Client();
    final retryOptions = const RetryOptions(maxAttempts: 3);

    try {
      // Primary: Google Translate dict-chrome-ex POST (resilient, no length limit, no 429)
      try {
        final response = await retryOptions.retry(
          () => httpClient.post(
            Uri.parse('https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=$target'),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
            },
            body: {'q': trimmed},
          ).timeout(const Duration(seconds: 15)),
          retryIf: (e) => e is SocketException || e is http.ClientException,
        );

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes, allowMalformed: true)) as List<dynamic>;
          if (data.isNotEmpty && data[0] is List && (data[0] as List).isNotEmpty) {
            var translated = data[0][0].toString();
            if (target == 'id') {
              translated = applyIndonesianPronounRules(translated);
            }
            return translated;
          }
        }
      } catch (_) {}

      // Fallback: gtx endpoint
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$target&dt=t&q=${Uri.encodeComponent(trimmed)}',
      );
      final response = await retryOptions.retry(
        () => httpClient.get(
          uri,
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        ).timeout(const Duration(seconds: 15)),
        retryIf: (e) => e is SocketException || e is http.ClientException,
      );

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final data = json.decode(utf8.decode(response.bodyBytes, allowMalformed: true)) as List<dynamic>;
      final sentences = data[0] as List<dynamic>;
      final buffer = StringBuffer();
      for (final part in sentences) {
        if (part is List && part.isNotEmpty && part[0] != null) {
          buffer.write(part[0].toString());
        }
      }

      var translated = buffer.toString();
      if (target == 'id') {
        translated = applyIndonesianPronounRules(translated);
      }
      return translated;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Translates subtitle content in SRT or WebVTT format into [targetLanguage].
  Future<String> translateSubtitleContent(
    String rawContent, {
    required String targetLanguage,
    http.Client? client,
  }) async {
    if (rawContent.trim().isEmpty) return rawContent;

    final isVtt = rawContent.trimLeft().startsWith('WEBVTT');
    final cues = _parseSubtitleCues(rawContent);

    if (cues.isEmpty) {
      return translateText(
        rawContent,
        targetLanguage: targetLanguage,
        client: client,
      );
    }

    final target = targetLanguage.toLowerCase().split(RegExp('[-_]')).first;
    if (target == 'en') {
      return rawContent;
    }

    const batchSize = 35;
    const delimiter = '\n___999___\n';
    final splitRegex = RegExp(r'\s*___999___\s*');

    final batches = <List<_SubtitleCue>>[];
    for (var i = 0; i < cues.length; i += batchSize) {
      final end = (i + batchSize < cues.length) ? i + batchSize : cues.length;
      batches.add(cues.sublist(i, end));
    }

    final httpClient = client ?? http.Client();
    try {
      // Process batches in parallel groups of 6 to complete full translation in 2-3s
      const concurrency = 6;
      for (var i = 0; i < batches.length; i += concurrency) {
        final group = batches.sublist(
          i,
          (i + concurrency < batches.length) ? i + concurrency : batches.length,
        );

        await Future.wait(
          group.map((batch) async {
            final joinedText = batch.map((cue) => cue.text).join(delimiter);
            try {
              final translatedJoined = await translateText(
                joinedText,
                targetLanguage: targetLanguage,
                client: httpClient,
              );

              final parts = translatedJoined.split(splitRegex);
              if (parts.length == batch.length) {
                for (var j = 0; j < batch.length; j++) {
                  batch[j].text = parts[j].trim();
                }
              } else {
                for (final cue in batch) {
                  cue.text = await translateText(
                    cue.text,
                    targetLanguage: targetLanguage,
                    client: httpClient,
                  );
                }
              }
            } catch (_) {
              // Keep original text on translation failure for this batch
            }
          }),
        );
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    final rebuilt = _rebuildSubtitle(cues, isVtt: isVtt);
    return isVtt ? processVttTimestamps(rebuilt) : rebuilt;
  }

  /// Fetches content from a URL or local file and translates it.
  Future<String?> translateUrlOrFile({
    required String pathOrUrl,
    required String targetLanguageCode,
    Map<String, String>? headers,
  }) async {
    final cacheKey = '${pathOrUrl}_$targetLanguageCode';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    String rawContent = '';
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      try {
        final effectiveHeaders = <String, String>{
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
          'Accept': '*/*',
          if (headers != null) ...headers,
        };
        final response = await http
            .get(Uri.parse(pathOrUrl), headers: effectiveHeaders)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          rawContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (_) {}
    } else {
      try {
        final file = File(pathOrUrl);
        if (await file.exists()) {
          rawContent = await file.readAsString();
        }
      } catch (_) {}
    }

    if (rawContent.trim().isEmpty) return null;

    final translated = await translateSubtitleContent(
      rawContent,
      targetLanguage: targetLanguageCode,
    );

    _cache[cacheKey] = translated;
    return translated;
  }

  List<_SubtitleCue> _parseSubtitleCues(String content) {
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final cues = <_SubtitleCue>[];

    var index = 0;
    while (index < lines.length) {
      final line = lines[index].trim();
      if (line.isEmpty || line == 'WEBVTT' || line.startsWith('NOTE') || line.startsWith('STYLE')) {
        index++;
        continue;
      }

      if (line.contains('-->')) {
        final timing = line;
        index++;
        final textLines = <String>[];
        while (index < lines.length && lines[index].trim().isNotEmpty) {
          textLines.add(lines[index].trim());
          index++;
        }
        if (textLines.isNotEmpty) {
          cues.add(_SubtitleCue(header: null, timing: timing, text: textLines.join('\n')));
        }
      } else if (index + 1 < lines.length && lines[index + 1].contains('-->')) {
        final header = line;
        final timing = lines[index + 1].trim();
        index += 2;
        final textLines = <String>[];
        while (index < lines.length && lines[index].trim().isNotEmpty) {
          textLines.add(lines[index].trim());
          index++;
        }
        if (textLines.isNotEmpty) {
          cues.add(_SubtitleCue(header: header, timing: timing, text: textLines.join('\n')));
        }
      } else {
        index++;
      }
    }

    return cues;
  }

  String _rebuildSubtitle(List<_SubtitleCue> cues, {required bool isVtt}) {
    final buffer = StringBuffer();
    if (isVtt) {
      buffer.writeln('WEBVTT\n');
    }

    for (var i = 0; i < cues.length; i++) {
      final cue = cues[i];
      if (cue.header != null && cue.header!.isNotEmpty) {
        buffer.writeln(cue.header);
      } else if (!isVtt) {
        buffer.writeln('${i + 1}');
      }
      buffer.writeln(cue.timing);
      buffer.writeln(cue.text);
      buffer.writeln();
    }

    return buffer.toString();
  }
}

class _SubtitleCue {
  _SubtitleCue({
    required this.header,
    required this.timing,
    required this.text,
  });

  final String? header;
  final String timing;
  String text;
}
