import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/video_providers/scraper_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_dio.dart';

void main() {
  late Dio dio;
  late FakeDioAdapter adapter;
  late HttpCache cache;
  late ScraperApi api;
  setUp(() {
    cache = HttpCache(MemCacheStore());
    adapter = FakeDioAdapter();
    dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: cache, debugLogging: false, retryDelay: (_) async {});
    dio.httpClientAdapter = adapter;
    api = ScraperApi('https://scraper.example', dio: dio);
  });
  tearDown(() async {
    dio.close();
    await cache.close();
  });

  test('providers, health and subtitle searches cache independently', () async {
    adapter.enqueueJson({
      'success': true,
      'providers': [
        {'id': 'vixsrc', 'name': 'VixSrc', 'enabled': true}
      ]
    });
    expect((await api.getProviders()).single.apiId, 'vixsrc');
    expect((await api.getProviders()).single.apiId, 'vixsrc');
    adapter.enqueueJson({
      'success': true,
      'summary': {'total': 1, 'online': 1},
      'providers': []
    });
    expect((await api.getProviderHealthStatus()).online, 1);
    expect((await api.getProviderHealthStatus()).online, 1);
    adapter.enqueueJson({'success': true, 'subtitles': []});
    await api.searchSubtitles(tmdbId: 7);
    await api.searchSubtitles(tmdbId: 7);
    expect(adapter.requests, hasLength(3));
    expect(adapter.requests.last.receiveTimeout, const Duration(seconds: 45));
    await cache.clearScope('scraper');
    expect(await cache.sizeBytes(), 0);
  });

  test('movie/TV streams and signed size tokens never cache, retain timeouts',
      () async {
    final stream = {
      'success': true,
      'links': [
        {'url': 'https://scraper.example/proxy?token=secret', 'quality': 'auto'}
      ]
    };
    for (var i = 0; i < 4; i++) {
      adapter.enqueueJson(stream);
    }
    for (var i = 0; i < 2; i++) {
      expect((await api.loadMovie(providerId: 'vixsrc', movieId: 7)).success,
          isTrue);
    }
    for (var i = 0; i < 2; i++) {
      expect(
          (await api.loadTVEpisode(
                  providerId: 'vixsrc',
                  tvId: 7,
                  seasonNumber: 1,
                  episodeNumber: 1))
              .success,
          isTrue);
    }
    for (final request in adapter.requests) {
      expect(request.receiveTimeout, const Duration(seconds: 60));
    }
    for (var i = 0; i < 2; i++) {
      adapter.enqueueJson({'success': true, 'estimatedBytes': 42});
      expect(
          (await api.estimateStreamSize('signed-token'))!.estimatedBytes, 42);
    }
    expect(adapter.requests, hasLength(6));
    expect(await cache.sizeBytes(), 0);
    expect(adapter.requests.last.receiveTimeout, const Duration(seconds: 10));
  });

  test('scraper message envelope and timeout failures remain usable to callers',
      () async {
    adapter.enqueueJson({
      'success': false,
      'message': 'Provider unavailable',
      'error': 'legacy'
    }, statusCode: 503);
    adapter.enqueueJson({
      'success': false,
      'message': 'Provider unavailable',
      'error': 'legacy'
    }, statusCode: 503);
    adapter.enqueueJson({
      'success': false,
      'message': 'Provider unavailable',
      'error': 'legacy'
    }, statusCode: 503);
    expect((await api.loadMovie(providerId: 'vixsrc', movieId: 7)).errorMessage,
        'Provider unavailable');
    for (var i = 0; i < 3; i++) {
      adapter.enqueueError(type: DioExceptionType.receiveTimeout);
    }
    expect((await api.loadMovie(providerId: 'vixsrc', movieId: 7)).errorMessage,
        'Scraper request timed out');
  });
}
