import 'dart:io';
import 'package:dio/dio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flixquest/core/cache/cache_key.dart';
import 'package:flixquest/core/cache/response_cache_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart'
    hide CachePolicy;
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/core/network/network_runtime.dart';
import 'package:flixquest/functions/network.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_dio.dart';

void main() {
  test('legacy fetchMovies uses the shared cache across API key rotation',
      () async {
    final cache = HttpCache(MemCacheStore());
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'page': 1,
        'total_pages': 1,
        'total_results': 1,
        'results': [
          {
            'id': 7,
            'title': 'Example',
            'overview': '',
            'poster_path': null,
            'backdrop_path': null,
            'release_date': '2026-10-03',
            'vote_average': 8.0,
            'genre_ids': [18]
          },
        ]
      });
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: cache, debugLogging: false);
    dio.httpClientAdapter = adapter;
    NetworkRuntime.configure(publicDio: dio, httpCache: cache);
    addTearDown(dio.close);
    addTearDown(cache.close);
    final first = await fetchMovies(
        'https://api.themoviedb.org/3/movie/popular?api_key=one', false, '');
    final offline = await fetchMovies(
        'https://api.themoviedb.org/3/movie/popular?api_key=two', false, '');
    expect(first.single.id, 7);
    expect(offline.single.title, 'Example');
    expect(adapter.requests, hasLength(1));
  });
  test('legacy TMDB rows render offline after restarting the SQLite cache',
      () async {
    sqfliteFfiInit();
    final directory =
        await Directory.systemTemp.createTemp('flixquest-offline-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/cache.db';
    const url = 'https://api.themoviedb.org/3/movie/popular';
    final firstCache = HttpCache(
        await ResponseCacheStore.open(factory: databaseFactoryFfi, path: path));
    final firstDio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: firstCache, debugLogging: false);
    firstDio.httpClientAdapter = FakeDioAdapter()
      ..enqueueJson({
        'results': [
          {
            'id': 7,
            'title': 'Example',
            'overview': '',
            'poster_path': null,
            'backdrop_path': null,
            'release_date': '2026-10-03',
            'vote_average': 8.0,
            'genre_ids': [18]
          },
        ]
      });
    NetworkRuntime.configure(publicDio: firstDio, httpCache: firstCache);
    expect((await fetchMovies(url, false, '')).single.id, 7);
    final key = normalizedCacheKey(RequestOptions(path: url), scope: 'tmdb');
    final cached = (await firstCache.store.get(key))!;
    final old = DateTime.now().subtract(const Duration(hours: 1));
    await firstCache.store
        .set(cached.copyWith(requestDate: old, responseDate: old));
    firstDio.close();
    await firstCache.close();
    final cache = HttpCache(
        await ResponseCacheStore.open(factory: databaseFactoryFfi, path: path));
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: cache, debugLogging: false, retryDelay: (_) async {});
    dio.httpClientAdapter = FakeDioAdapter()
      ..enqueueError()
      ..enqueueError()
      ..enqueueError();
    NetworkRuntime.configure(publicDio: dio, httpCache: cache);
    addTearDown(dio.close);
    addTearDown(cache.close);
    expect((await fetchMovies(url, false, '')).single.title, 'Example');
  });
}
