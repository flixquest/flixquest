import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../core/cache/cache_policies.dart';
import '../core/cache/cache_policy.dart';
import '../core/network/network_runtime.dart';

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
  ScraperApi(this.baseUrl, {Dio? dio})
      : _dio = dio ?? NetworkRuntime.publicDio;

  final String baseUrl;
  final Dio _dio;

  Future<List<VideoProvider>> getProviders() async {
    try {
      final uri = _endpoint('/providers');
      _logRequest(uri);
      final response = await _get(uri);
      _logResponse(uri, response);
      final body = _decodeObject(response.data ?? '');
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
        throw ScraperApiException(_messageFrom(body, (response.statusCode ?? 0)));
      }
      if (body['success'] != true) {
        throw ScraperApiException(_messageFrom(body, (response.statusCode ?? 0)));
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
    } on DioException catch (error) {
      throw ScraperApiException(_dioMessage(error));
    }
  }

  Future<List<BannerAd>> getAds() async {
    try {
      final uri = _endpoint('/ads');
      final response = await _get(uri, timeout: const Duration(seconds: 10));
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
        return const [];
      }
      _logRequest(uri);
      _logResponse(uri, response);
      final body = _decodeObject(response.data ?? '');
      if (body['success'] != true || body['ads'] is! List) return const [];
      return (body['ads'] as List)
          .whereType<Map>()
          .map((ad) => BannerAd.fromJson(Map<String, dynamic>.from(ad)))
          .where((ad) => ad.imageUrl.isNotEmpty && ad.targetUrl.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<ProviderHealthSnapshot> getProviderHealthStatus() async {
    try {
      final uri = _endpoint('/providers/status');
      _logRequest(uri);
      final response = await _get(uri);
      _logResponse(uri, response);
      final body = _decodeObject(response.data ?? '');
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
        throw ScraperApiException(_messageFrom(body, (response.statusCode ?? 0)));
      }
      if (body['success'] != true) {
        throw ScraperApiException(_messageFrom(body, (response.statusCode ?? 0)));
      }

      return ProviderHealthSnapshot.fromJson(body);
    } on DioException catch (error) {
      throw ScraperApiException(_dioMessage(error));
    }
  }

  Future<ProviderLoadResult> loadMovie({
    required String providerId,
    required int movieId,
    bool full = false,
  }) {
    return _loadStream(
      '/stream-movie',
      _buildQueryParams(providerId, {
        'tmdbId': '$movieId',
        if (full) 'full': 'true',
      }),
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
        if (full) 'full': 'true',
      }),
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
      final body = _decodeObject(response.data ?? '');
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) return null;
      if (body['success'] != true) return null;
      return StreamSizeEstimate.fromJson(body);
    } catch (_) {
      return null;
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
      _logResponseSummary(uri, response, '${(response.data ?? '').length} bytes');
      final body = _decodeObject(response.data ?? '');
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
        throw ScraperApiException(_messageFrom(body, (response.statusCode ?? 0)));
      }
      if (body['success'] != true) {
        throw ScraperApiException(_messageFrom(body, (response.statusCode ?? 0)));
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
    } on DioException catch (error) {
      throw ScraperApiException(_dioMessage(error));
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

  Future<ProviderLoadResult> _loadStream(
    String path,
    Map<String, String> queryParameters,
  ) async {
    try {
      final uri = _endpoint(path, queryParameters);
      _logRequest(uri);
      final response = await _get(uri, timeout: const Duration(minutes: 1));
      _logResponse(uri, response);
      final body = _decodeObject(response.data ?? '');
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
        return ProviderLoadResult(
          errorMessage: _messageFrom(body, (response.statusCode ?? 0)),
        );
      }
      if (body['success'] != true) {
        return ProviderLoadResult(
          errorMessage: _messageFrom(body, (response.statusCode ?? 0)),
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
          errorMessage: _messageFrom(body, (response.statusCode ?? 0)),
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
    } on DioException catch (error) {
      final timedOut = [DioExceptionType.connectionTimeout, DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout].contains(error.type);
      return ProviderLoadResult(errorMessage: timedOut
          ? 'Scraper request timed out' : _dioMessage(error));
    } catch (error) {
      return ProviderLoadResult(errorMessage: error.toString());
    }
  }

  Future<Response<String>> _get(
    Uri uri, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    return _dio.get<String>(uri.toString(), options: Options(
      responseType: ResponseType.plain, receiveTimeout: timeout,
      extra: {'cacheScope': 'scraper',
        'cachePolicy': CachePolicies.forUrl(uri, scope: 'scraper')},
    ));
  }

  Future<Response<String>> _post(
    Uri uri,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    return _dio.post<String>(uri.toString(), data: body, options: Options(
      contentType: Headers.jsonContentType, responseType: ResponseType.plain,
      receiveTimeout: timeout, extra: {'cachePolicy': CachePolicy.noStore},
    ));
  }

  void _logRequest(Uri uri, {String method = 'GET'}) {
    if (!kDebugMode) return;
    debugPrint('[ScraperApi] $method ${uri.host}${uri.path}');
  }

  void _logResponse(Uri uri, Response<String> response) {
    if (!kDebugMode) return;
    debugPrint(
      '[ScraperApi] RESPONSE ${(response.statusCode ?? 0)} ${uri.host}${uri.path}',
    );
  }

  void _logResponseSummary(Uri uri, Response<String> response, String summary) {
    if (!kDebugMode) return;
    debugPrint('[ScraperApi] RESPONSE ${(response.statusCode ?? 0)} ${uri.host}${uri.path} ($summary)');
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

  String _dioMessage(DioException error) {
    final response = error.response;
    if (response == null) return 'Scraper service is unavailable';
    final raw = response.data;
    final body = raw is String ? _decodeObject(raw)
        : raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return _messageFrom(body, response.statusCode ?? 0);
  }

  String _messageFrom(Map<String, dynamic> body, int statusCode) {
    final message = body['message']?.toString();
    if (message != null && message.isNotEmpty) return message;
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
