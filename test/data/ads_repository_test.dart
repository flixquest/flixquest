import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/cache/cache_key.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/services/hosted_ads_repository.dart';
import 'package:flixquest/core/network/network_runtime.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/data/repositories/ads_repository.dart';
import '../support/fake_dio.dart';

void main() {
  test('all slots share one unfiltered catalog and renew after five minutes',
      () async {
    final adapter = FakeDioAdapter();
    final payload =
        jsonDecode(File('test/support/fixtures/ads.json').readAsStringSync());
    adapter.enqueueJson(payload);
    adapter.enqueueJson(payload);
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    var now = DateTime.utc(2026, 10, 4);
    final repository = AdsRepository(dio, now: () => now);
    final catalogs = await Future.wait(
        [repository.load(), repository.load(), repository.load()]);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.queryParameters, isEmpty);
    expect(adapter.requests.single.extra['authRequired'], false);
    expect(catalogs.first.single.appliesTo('movie_detail'), true);
    expect(catalogs.first.single.appliesTo('tv_list'), false);
    expect(catalogs.first.single.altText, 'NordVPN discount banner');
    expect(catalogs.first.single.width, 320.5);
    expect(catalogs.first.single.height, 50);
    await repository.load();
    expect(adapter.requests, hasLength(1));
    now = now.add(const Duration(minutes: 5));
    await repository.load();
    expect(adapter.requests, hasLength(2));
    dio.close();
  });
  test(
      'cached catalog revalidates and offline fallback stops at its fixed 24-hour deadline',
      () async {
    final cache = HttpCache(MemCacheStore());
    final dio = createLaravelDio(
        AppEnvironment.resolve(defineUrl: 'https://backend.test'),
        httpCache: cache,
        debugLogging: false,
        retryDelay: (_) async {});
    final adapter = FakeDioAdapter();
    dio.httpClientAdapter = adapter;
    final payload =
        jsonDecode(File('test/support/fixtures/ads.json').readAsStringSync());
    adapter.enqueueJson(payload, headers: {
      'etag': ['"ads-v1"'],
      'cache-control': ['public, no-cache']
    });
    expect(await AdsRepository(dio).load(), hasLength(1));
    adapter.enqueueJson(null, statusCode: 304);
    expect(await AdsRepository(dio).load(), hasLength(1));
    expect(adapter.requests.last.headers['if-none-match'], '"ads-v1"');
    final key = normalizedCacheKey(
        RequestOptions(path: 'https://backend.test/api/v1/ads'),
        scope: 'laravel');
    final original = (await cache.store.get(key))!;
    final old = DateTime.now().subtract(const Duration(hours: 23));
    final deadline = old.add(const Duration(hours: 24, minutes: 5));
    await cache.store.set(original.copyWith(
        requestDate: old, responseDate: old, maxStale: deadline));
    for (var i = 0; i < 3; i++) {
      adapter.enqueueError();
    }
    expect(await AdsRepository(dio).load(), hasLength(1));
    expect((await cache.store.get(key))!.maxStale, deadline);
    final expired = DateTime.now().subtract(const Duration(hours: 25));
    await cache.store.set(original.copyWith(
        requestDate: expired,
        responseDate: expired,
        maxStale: expired.add(const Duration(hours: 24, minutes: 5))));
    for (var i = 0; i < 3; i++) {
      adapter.enqueueError();
    }
    expect(await AdsRepository(dio).load(), isEmpty);
    await cache.close();
    dio.close();
  });

  test(
      'Laravel adapter shares its catalog across scraper URLs and flag-off retains rollback delivery',
      () async {
    final payload =
        jsonDecode(File('test/support/fixtures/ads.json').readAsStringSync());
    final adapter = FakeDioAdapter()..enqueueJson(payload);
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final repository = AdsRepository(dio);
    HostedAdsRepository.instance.configure(repository, enabled: true);
    await Future.wait([
      HostedAdsRepository.instance.load('https://scraper-a.test'),
      HostedAdsRepository.instance.load('https://scraper-b.test')
    ]);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.uri.host, 'backend.test');
    HostedAdsRepository.instance.configure(repository, enabled: false);
    expect(HostedAdsRepository.instance.telemetryEnabled, false);
    final fallback = FakeDioAdapter()..enqueueJson(payload);
    final legacy = Dio()..httpClientAdapter = fallback;
    final fallbackCache = HttpCache(MemCacheStore());
    NetworkRuntime.configure(publicDio: legacy, httpCache: fallbackCache);
    expect(
        await HostedAdsRepository.instance.load('https://scraper.test/api/v2/'),
        hasLength(1));
    expect(fallback.requests.single.uri.toString(),
        'https://scraper.test/api/v2/ads');
    HostedAdsRepository.instance.configure(repository, enabled: false);
    dio.close();
    legacy.close();
    await fallbackCache.close();
  });

  test(
      'malformed campaigns are isolated and nullable accessibility text has safe dimensions',
      () async {
    final payload =
        jsonDecode(File('test/support/fixtures/ads.json').readAsStringSync())
            as Map<String, dynamic>;
    final valid = Map<String, dynamic>.from((payload['ads'] as List).single);
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'success': true,
        'ads': [
          'invalid',
          {...valid, 'imageUrl': 'broken'},
          {
            ...valid,
            'id': 7,
            'altText': null,
            'aspectRatio': 0,
            'width': -10,
            'height': 0
          }
        ]
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final ads = await AdsRepository(dio).load();
    expect(ads, hasLength(1));
    expect(ads.single.id, '7');
    expect(ads.single.altText, '');
    expect(ads.single.aspectRatio, 2.2);
    expect(ads.single.width, isNull);
    expect(ads.single.height, isNull);
    dio.close();
  });
}
