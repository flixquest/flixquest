import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/external_subtitles.dart';
import '../models/banner_ad.dart';
import 'common.dart';
import 'names.dart';

/// Client for the FlixQuest Scraper API v2 described in `openapi.json`.
///
/// The API proxies streams by default. This is intentional: the returned URL
/// can then be handed directly to Better Player without exposing provider
/// headers or anti-hotlink details in the app.
class ScraperApi {
  ScraperApi(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final String baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  Future<List<VideoProvider>> getProviders() async {
    try {
      final uri = _endpoint('/providers');
      _logRequest(uri);
      final response = await _get(uri);
      _logResponse(uri, response);
      final body = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ScraperApiException(_messageFrom(body, response.statusCode));
      }
      if (body['success'] != true) {
        throw ScraperApiException(_messageFrom(body, response.statusCode));
      }

      final providers = body['providers'];
      if (providers is! List) return const [];
      return providers
          .whereType<Map>()
          .map((provider) => Map<String, dynamic>.from(provider))
          .where((provider) => provider['enabled'] == true)
          .map(
            (provider) => VideoProvider.scraper(
              id: provider['id']?.toString() ?? '',
              name: provider['name']?.toString() ?? 'Unknown provider',
              alias: provider['alias']?.toString(),
              content: provider['content']?.toString(),
            ),
          )
          .where((provider) => provider.apiId?.isNotEmpty == true)
          .toList(growable: false);
    } finally {
      if (_ownsClient) _client.close();
    }
  }

  Future<List<BannerAd>> getAds() async {
    try {
      final uri = _endpoint('/ads');
      final response = await _get(uri, timeout: const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      _logRequest(uri);
      _logResponse(uri, response);
      final body = _decodeObject(response.body);
      if (body['success'] != true || body['ads'] is! List) return const [];
      return (body['ads'] as List)
          .whereType<Map>()
          .map((ad) => BannerAd.fromJson(Map<String, dynamic>.from(ad)))
          .where((ad) => ad.imageUrl.isNotEmpty && ad.targetUrl.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    } finally {
      if (_ownsClient) _client.close();
    }
  }

  Future<ProviderHealthSnapshot> getProviderHealthStatus() async {
    try {
      final uri = _endpoint('/providers/status');
      _logRequest(uri);
      final response = await _get(uri);
      _logResponse(uri, response);
      final body = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ScraperApiException(_messageFrom(body, response.statusCode));
      }
      if (body['success'] != true) {
        throw ScraperApiException(_messageFrom(body, response.statusCode));
      }

      return ProviderHealthSnapshot.fromJson(body);
    } finally {
      if (_ownsClient) _client.close();
    }
  }

  Future<ProviderLoadResult> loadMovie({
    required String providerId,
    required int movieId,
    bool full = false,
  }) {
    return _loadStream(
      '/stream-movie',
      _buildQueryParams(providerId, {'tmdbId': '$movieId'}),
      full: full,
    );
  }

  Future<ProviderLoadResult> loadTVEpisode({
    required String providerId,
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
    bool full = false,
  }) {
    return _loadStream(
      '/stream-tv',
      _buildQueryParams(providerId, {
        'tmdbId': '$tvId',
        'season': '$seasonNumber',
        'episode': '$episodeNumber',
      }),
      full: full,
    );
  }

  /// Estimates the source bytes represented by an API-issued signed token.
  /// A failed or unavailable estimate is intentionally represented as null so
  /// callers can keep the resolution selectable.
  Future<StreamSizeEstimate?> estimateStreamSize(String token) async {
    try {
      final uri = _endpoint('/stream-size');
      _logRequest(uri, method: 'POST');
      final response = await _post(
        uri,
        {'token': token},
        timeout: const Duration(seconds: 10),
      );
      _logResponse(uri, response);
      final body = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      if (body['success'] != true) return null;
      return StreamSizeEstimate.fromJson(body);
    } catch (_) {
      return null;
    } finally {
      if (_ownsClient) _client.close();
    }
  }

  /// Searches the API's subtitle providers for a movie or TV episode.
  ///
  /// Every returned URL points back at this API, so subtitle files are
  /// downloaded from the scraper instead of the upstream subtitle hosts.
  Future<List<ExternalSubtitle>> searchSubtitles({
    required int tmdbId,
    int? season,
    int? episode,
  }) async {
    try {
      final uri = _endpoint('/subtitles/search', {
        'tmdbId': '$tmdbId',
        if (season != null) 'season': '$season',
        if (episode != null) 'episode': '$episode',
      });
      _logRequest(uri);
      final response = await _get(uri, timeout: const Duration(seconds: 45));
      _logResponseSummary(uri, response, '${response.body.length} bytes');
      final body = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ScraperApiException(_messageFrom(body, response.statusCode));
      }
      if (body['success'] != true) {
        throw ScraperApiException(_messageFrom(body, response.statusCode));
      }

      final subtitles = body['subtitles'];
      if (subtitles is! List) return const [];
      return subtitles
          .whereType<Map>()
          .map(
            (subtitle) => ExternalSubtitle.fromJson(
              Map<String, dynamic>.from(subtitle),
            ),
          )
          .where((subtitle) => subtitle.url.isNotEmpty)
          .toList(growable: false);
    } finally {
      if (_ownsClient) _client.close();
    }
  }

  Map<String, String> _buildQueryParams(
    String providerId,
    Map<String, String> baseParams,
  ) {
    return {
      ...baseParams,
      'provider': providerId,
    };
  }

  /// Loads [path], asking for every server when [full] is set. A server with
  /// full collection turned off refuses such a request outright, so it is
  /// retried for the first working server instead.
  Future<ProviderLoadResult> _loadStream(
    String path,
    Map<String, String> queryParameters, {
    bool full = false,
  }) async {
    try {
      if (full) {
        final result =
            await _fetchStream(path, {...queryParameters, 'full': 'true'});
        if (!_isFullCollectionDisabled(result)) return result;
        if (kDebugMode) {
          debugPrint(
            '[ScraperApi] Full collection is disabled for $path '
            '(provider=${queryParameters['provider']}); retrying without full',
          );
        }
      }
      return await _fetchStream(path, queryParameters);
    } finally {
      if (_ownsClient) _client.close();
    }
  }

  static bool _isFullCollectionDisabled(ProviderLoadResult result) =>
      !result.success &&
      (result.errorMessage?.toLowerCase().contains('full stream collection') ??
          false);

  Future<ProviderLoadResult> _fetchStream(
    String path,
    Map<String, String> queryParameters,
  ) async {
    try {
      final uri = _endpoint(path, queryParameters);
      _logRequest(uri);
      final response = await _get(uri, timeout: const Duration(minutes: 1));
      _logResponse(uri, response);
      final body = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ProviderLoadResult(
          errorMessage: _messageFrom(body, response.statusCode),
        );
      }
      if (body['success'] != true) {
        return ProviderLoadResult(
          errorMessage: _messageFrom(body, response.statusCode),
        );
      }

      final links = <RegularVideoLinks>[];
      final subtitles = <RegularSubtitleLinks>[];
      final seenSubtitles = <String>{};
      final rawLinks = body['links'];
      if (rawLinks is List) {
        for (final rawLink in rawLinks.whereType<Map>()) {
          final link = Map<String, dynamic>.from(rawLink);
          final url = link['url']?.toString();
          if (url == null || url.isEmpty) continue;
          final linkHeaders = _parseHeaders(link['headers']);
          links.add(
            RegularVideoLinks(
              url: url,
              quality: link['quality']?.toString() ?? 'unknown quality',
              server: link['server']?.toString(),
              isM3U8: link['isM3U8'] == true,
              isDash: link['isDASH'] == true,
              headers: linkHeaders,
              sizeToken: link['sizeToken']?.toString(),
            ),
          );

          final rawSubtitles = link['subtitles'];
          if (rawSubtitles is List) {
            for (final rawSubtitle in rawSubtitles.whereType<Map>()) {
              final subtitle = Map<String, dynamic>.from(rawSubtitle);
              final file = subtitle['file']?.toString();
              if (file == null || file.isEmpty) continue;
              final language = subtitle['label']?.toString() ?? 'Unknown';
              if (seenSubtitles.add('$file\u0000$language')) {
                subtitles.add(
                  RegularSubtitleLinks(
                    url: file,
                    language: language,
                    headers: _parseHeaders(subtitle['headers']) ?? linkHeaders,
                  ),
                );
              }
            }
          }
        }
      }

      if (links.isEmpty) {
        return ProviderLoadResult(
          errorMessage: _messageFrom(body, response.statusCode),
        );
      }
      return ProviderLoadResult(
        success: true,
        videoLinks: links,
        subtitleLinks: subtitles,
      );
    } on TimeoutException {
      return const ProviderLoadResult(
          errorMessage: 'Scraper request timed out');
    } catch (error) {
      return ProviderLoadResult(errorMessage: error.toString());
    }
  }

  Future<http.Response> _get(
    Uri uri, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _client.get(uri).timeout(timeout);
  }

  Future<http.Response> _post(
    Uri uri,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
  }

  void _logRequest(Uri uri, {String method = 'GET'}) {
    if (!kDebugMode) return;
    debugPrint('[ScraperApi] $method $uri');
  }

  void _logResponse(Uri uri, http.Response response) {
    if (!kDebugMode) return;
    debugPrint(
      '[ScraperApi] RESPONSE ${response.statusCode} $uri\n${response.body}',
    );
  }

  void _logResponseSummary(Uri uri, http.Response response, String summary) {
    if (!kDebugMode) return;
    debugPrint('[ScraperApi] RESPONSE ${response.statusCode} $uri ($summary)');
  }

  Uri _endpoint(String path, [Map<String, String>? queryParameters]) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      throw const ScraperApiException('Scraper API URL is not configured');
    }
    final root =
        normalized.endsWith('/api/v2') ? normalized : '$normalized/api/v2';
    return Uri.parse('$root$path').replace(queryParameters: queryParameters);
  }

  Map<String, dynamic> _decodeObject(String text) {
    try {
      final value = jsonDecode(text);
      return value is Map<String, dynamic> ? value : const {};
    } on FormatException {
      return const {};
    }
  }

  Map<String, String>? _parseHeaders(Object? value) {
    if (value is! Map) return null;
    final headers = <String, String>{};
    for (final entry in value.entries) {
      if (entry.value is String) {
        headers[entry.key.toString()] = entry.value as String;
      }
    }
    return headers.isEmpty ? null : headers;
  }

  String _messageFrom(Map<String, dynamic> body, int statusCode) {
    final error = body['error']?.toString();
    if (error != null && error.isNotEmpty) return error;
    final details = body['details']?.toString();
    if (details != null && details.isNotEmpty) return details;
    return 'Scraper request failed (HTTP $statusCode)';
  }
}

class ScraperApiException implements Exception {
  const ScraperApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StreamSizeEstimate {
  const StreamSizeEstimate({this.estimatedBytes});

  final int? estimatedBytes;

  factory StreamSizeEstimate.fromJson(Map<String, dynamic> json) {
    final rawBytes = json['estimatedBytes'];
    return StreamSizeEstimate(
      estimatedBytes: rawBytes is num ? rawBytes.toInt() : null,
    );
  }
}

class ProviderHealthSnapshot {
  const ProviderHealthSnapshot({
    required this.interval,
    required this.total,
    required this.online,
    required this.offline,
    required this.providers,
    this.startedAt,
    this.updatedAt,
    this.methodology,
  });

  factory ProviderHealthSnapshot.fromJson(Map<String, dynamic> json) {
    final rawProviders = json['providers'];
    final providers = rawProviders is List
        ? rawProviders
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(ProviderHealthResult.fromJson)
            .where((provider) => provider.id.isNotEmpty)
            .toList(growable: false)
        : const <ProviderHealthResult>[];
    final rawSummary = json['summary'];
    final summary = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : const <String, dynamic>{};

    return ProviderHealthSnapshot(
      startedAt: _dateTimeFrom(json['startedAt']),
      updatedAt: _dateTimeFrom(json['updatedAt']),
      interval: Duration(milliseconds: _intFrom(json['intervalMs'])),
      methodology: json['methodology']?.toString(),
      total: _intFrom(summary['total'], fallback: providers.length),
      online: _intFrom(
        summary['online'],
        fallback: providers.where((provider) => provider.online).length,
      ),
      offline: _intFrom(
        summary['offline'],
        fallback: providers.where((provider) => !provider.online).length,
      ),
      providers: providers,
    );
  }

  final DateTime? startedAt;
  final DateTime? updatedAt;
  final Duration interval;
  final String? methodology;
  final int total;
  final int online;
  final int offline;
  final List<ProviderHealthResult> providers;

  double get availability => total == 0 ? 0 : online / total;
}

class ProviderHealthResult {
  const ProviderHealthResult({
    required this.id,
    required this.alias,
    this.name,
    required this.online,
    required this.requestTime,
  });

  factory ProviderHealthResult.fromJson(Map<String, dynamic> json) {
    return ProviderHealthResult(
      id: json['id']?.toString() ?? '',
      alias: json['alias']?.toString() ?? '',
      name: json['name']?.toString(),
      online: json['status'] == 'online',
      requestTime: Duration(milliseconds: _intFrom(json['requestTimeMs'])),
    );
  }

  final String id;
  final String alias;
  final String? name;
  final bool online;
  final Duration requestTime;

  String get originalName {
    final rawName = name?.trim();
    if (rawName != null && rawName.isNotEmpty) {
      return rawName;
    }
    return id;
  }

  String get displayName => alias.trim().isEmpty ? originalName : alias;
}

int _intFrom(Object? value, {int fallback = 0}) {
  return value is num ? value.toInt() : fallback;
}

DateTime? _dateTimeFrom(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}
