import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart'
    hide CachePolicy;
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/cache/cache_key.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_dio.dart';

void main() {
  test('repeat TMDB metadata requests use the HTTP cache', () async {
    final cache = HttpCache(MemCacheStore());
    final adapter = FakeDioAdapter()..enqueueJson({'title': 'Example'});
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: cache, debugLogging: false);
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);
    addTearDown(cache.close);
    const url = 'https://api.themoviedb.org/3/movie/7?api_key=one';
    expect(
        (await dio.get<Map<String, dynamic>>(url)).data!['title'], 'Example');
    final repeat = await dio.get<Map<String, dynamic>>(url);
    expect(repeat.data!['title'], 'Example');
    expect(repeat.extra['cache'], 'hit');
    expect(adapter.requests, hasLength(1));
  });

  test('stale metadata revalidates with ETag and serves the stored body',
      () async {
    final cache = HttpCache(MemCacheStore());
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'title': 'Example'
      }, headers: {
        'etag': ['"v1"']
      })
      ..enqueueJson(null, statusCode: 304);
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: cache, debugLogging: false);
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);
    addTearDown(cache.close);
    const url = 'https://api.themoviedb.org/3/movie/7';
    await dio.get<Object>(url);
    final key = normalizedCacheKey(RequestOptions(path: url), scope: 'tmdb');
    final entry = (await cache.store.get(key))!;
    final old = DateTime.now().toUtc().subtract(const Duration(days: 2));
    await cache.store.set(entry.copyWith(requestDate: old, responseDate: old));
    final response = await dio.get<Map<String, dynamic>>(url);
    expect(adapter.requests.last.headers['if-none-match'], '"v1"');
    expect(response.data!['title'], 'Example');
    expect(response.statusCode, 200);
    expect(response.extra['cache'], 'revalidated');
    expect((await dio.get<Object>(url)).extra['cache'], 'hit');
  });
}
