import 'dart:convert';

import 'package:flixquest/video_providers/scraper_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ScraperApi', () {
    test('maps enabled API providers, aliases, and content metadata', () async {
      late Uri requestedUri;
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'providers': [
                {
                  'id': 'vidsrc',
                  'name': 'VidSrc upstream',
                  'alias': 'VidSrc',
                  'content': 'Hollywood: English | Anime: Japanese',
                  'enabled': true,
                },
                {
                  'id': 'disabled',
                  'name': 'Disabled',
                  'alias': 'Disabled',
                  'enabled': false,
                },
              ],
            }),
            200,
          );
        }),
      );

      final providers = await api.getProviders();

      expect(requestedUri.path, '/api/v2/providers');
      expect(providers, hasLength(1));
      expect(providers.single.apiId, 'vidsrc');
      expect(providers.single.codeName, 'scraper:vidsrc');
      expect(providers.single.displayName, 'VidSrc');
      expect(providers.single.content, 'Hollywood: English | Anime: Japanese');
    });

    test('maps the persisted provider health snapshot', () async {
      late Uri requestedUri;
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'startedAt': '2026-08-14T09:00:00.000Z',
              'updatedAt': '2026-08-14T09:00:04.000Z',
              'intervalMs': 900000,
              'methodology': 'Checks one known title per provider.',
              'summary': {'total': 2, 'online': 1, 'offline': 1},
              'providers': [
                {
                  'id': 'vixsrc',
                  'alias': 'VixSrc',
                  'status': 'online',
                  'requestTimeMs': 1432,
                },
                {
                  'id': 'vidsrc',
                  'alias': 'VidSrc',
                  'status': 'offline',
                  'requestTimeMs': 30001,
                },
              ],
            }),
            200,
          );
        }),
      );

      final snapshot = await api.getProviderHealthStatus();

      expect(requestedUri.path, '/api/v2/providers/status');
      expect(snapshot.updatedAt, DateTime.utc(2026, 8, 14, 9, 0, 4));
      expect(snapshot.interval, const Duration(minutes: 15));
      expect(snapshot.total, 2);
      expect(snapshot.online, 1);
      expect(snapshot.offline, 1);
      expect(snapshot.availability, .5);
      expect(snapshot.providers.first.displayName, 'VixSrc');
      expect(snapshot.providers.first.originalName, 'vixsrc');
      expect(snapshot.providers.first.online, isTrue);
      expect(
        snapshot.providers.first.requestTime,
        const Duration(milliseconds: 1432),
      );
      expect(snapshot.providers.last.originalName, 'vidsrc');
      expect(snapshot.providers.last.online, isFalse);
    });

    test('surfaces an unavailable health snapshot response', () async {
      final api = ScraperApi(
        'https://scraper.example/api/v2',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'No provider health snapshot available'}),
            503,
          ),
        ),
      );

      expect(
        api.getProviderHealthStatus,
        throwsA(
          isA<ScraperApiException>().having(
            (error) => error.message,
            'message',
            'No provider health snapshot available',
          ),
        ),
      );
    });

    test('normalizes movie links, subtitles, and proxy stream type', () async {
      late Uri requestedUri;
      final api = ScraperApi(
        'https://scraper.example/api/v2',
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'provider': 'vidsrc',
              'links': [
                {
                  'url': 'https://scraper.example/proxy?token=first',
                  'sizeToken': 'signed-size-token-1080',
                  'server': 'ShowBox 2',
                  'quality': '1080p',
                  'isM3U8': true,
                  'isDASH': false,
                  'headers': {
                    'Referer': 'https://provider.example/',
                    'Origin': 'https://provider.example',
                  },
                  'subtitles': [
                    {
                      'file': 'https://subs.example/en.vtt',
                      'label': 'English',
                      'kind': 'captions',
                    },
                  ],
                },
                {
                  'url': 'https://scraper.example/proxy?token=second',
                  'quality': '720p',
                  'isM3U8': false,
                  'isDASH': true,
                  'subtitles': [
                    {
                      'file': 'https://subs.example/en.vtt',
                      'label': 'English',
                      'kind': 'captions',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await api.loadMovie(providerId: 'vidsrc', movieId: 42);

      expect(requestedUri.path, '/api/v2/stream-movie');
      expect(requestedUri.queryParameters, {
        'tmdbId': '42',
        'provider': 'vidsrc',
      });
      expect(result.success, isTrue);
      expect(result.videoLinks, hasLength(2));
      expect(result.videoLinks!.first.isM3U8, isTrue);
      expect(result.videoLinks!.first.sizeToken, 'signed-size-token-1080');
      expect(result.videoLinks!.first.server, 'ShowBox 2');
      expect(result.videoLinks!.first.headers, {
        'Referer': 'https://provider.example/',
        'Origin': 'https://provider.example',
      });
      expect(result.videoLinks!.last.isDash, isTrue);
      expect(result.subtitleLinks, hasLength(1));
      expect(result.subtitleLinks!.single.headers, {
        'Referer': 'https://provider.example/',
        'Origin': 'https://provider.example',
      });
    });

    test('uses the documented TV episode query parameters', () async {
      late Uri requestedUri;
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'provider': 'vidsrc',
              'links': [
                {
                  'url': 'https://scraper.example/proxy?token=tv',
                  'quality': 'auto',
                  'isM3U8': true,
                  'subtitles': [],
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await api.loadTVEpisode(
        providerId: 'vidsrc',
        tvId: 99,
        seasonNumber: 2,
        episodeNumber: 3,
      );

      expect(result.success, isTrue);
      expect(requestedUri.path, '/api/v2/stream-tv');
      expect(requestedUri.queryParameters, {
        'tmdbId': '99',
        'season': '2',
        'episode': '3',
        'provider': 'vidsrc',
      });
    });

    test('requests every movie server when full is enabled', () async {
      late Uri requestedUri;
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'provider': 'vidsrc',
              'links': [
                {
                  'url': 'https://scraper.example/full-movie',
                  'quality': '1080p',
                  'isM3U8': true,
                  'subtitles': [],
                },
              ],
            }),
            200,
          );
        }),
      );

      await api.loadMovie(providerId: 'vidsrc', movieId: 42, full: true);

      expect(requestedUri.queryParameters, {
        'tmdbId': '42',
        'full': 'true',
        'provider': 'vidsrc',
      });
    });

    test('requests every TV server when full is enabled', () async {
      late Uri requestedUri;
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'provider': 'vidsrc',
              'links': [
                {
                  'url': 'https://scraper.example/full-tv',
                  'quality': '720p',
                  'isM3U8': true,
                  'subtitles': [],
                },
              ],
            }),
            200,
          );
        }),
      );

      await api.loadTVEpisode(
        providerId: 'vidsrc',
        tvId: 99,
        seasonNumber: 2,
        episodeNumber: 3,
        full: true,
      );

      expect(requestedUri.queryParameters, {
        'tmdbId': '99',
        'season': '2',
        'episode': '3',
        'full': 'true',
        'provider': 'vidsrc',
      });
    });

    test('retries without full when the server has full collection disabled',
        () async {
      final requestedUris = <Uri>[];
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient((request) async {
          requestedUris.add(request.url);
          if (request.url.queryParameters['full'] == 'true') {
            return http.Response(
              jsonEncode({
                'success': false,
                'provider': 'vidsrc',
                'links': [],
                'error': 'Full stream collection is disabled. '
                    'Omit full=true to find the first working server.',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'provider': 'vidsrc',
              'links': [
                {
                  'url': 'https://scraper.example/first-server',
                  'quality': '1080p',
                  'isM3U8': true,
                  'subtitles': [],
                },
              ],
            }),
            200,
          );
        }),
      );

      final result =
          await api.loadMovie(providerId: 'vidsrc', movieId: 42, full: true);

      expect(result.success, isTrue);
      expect(result.videoLinks?.single.url,
          'https://scraper.example/first-server');
      expect(requestedUris.map((uri) => uri.queryParameters['full']),
          ['true', null]);
    });

    test('does not retry a full request that failed for another reason',
        () async {
      var requests = 0;
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'success': false,
              'error': 'No streams found for this movie',
            }),
            404,
          );
        }),
      );

      final result =
          await api.loadMovie(providerId: 'vidsrc', movieId: 42, full: true);

      expect(result.success, isFalse);
      expect(result.errorMessage, 'No streams found for this movie');
      expect(requests, 1);
    });

    test('posts a signed token and maps a stream size estimate', () async {
      late http.Request request;
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            jsonEncode({
              'success': true,
              'estimatedBytes': 1500000000,
              'confidence': 'high',
              'method': 'hls-bandwidth',
              'format': 'hls',
              'bitrate': 4200000,
              'initBytes': 0,
              'segmentCount': 1500,
            }),
            200,
          );
        }),
      );

      final estimate = await api.estimateStreamSize('signed-size-token');

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v2/stream-size');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), {'token': 'signed-size-token'});
      expect(estimate?.estimatedBytes, 1500000000);
    });

    test('maps an unavailable stream size response', () async {
      final api = ScraperApi(
        'https://scraper.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'estimatedBytes': null,
              'confidence': 'unknown',
              'method': 'unavailable',
              'format': 'unknown',
              'bitrate': null,
              'initBytes': 0,
              'segmentCount': 0,
            }),
            200,
          ),
        ),
      );

      final estimate = await api.estimateStreamSize('signed-size-token');

      expect(estimate, isNotNull);
      expect(estimate?.estimatedBytes, isNull);
    });
  });
}
