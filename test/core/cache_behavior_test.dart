import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart'
    hide CachePolicy;
import 'package:flixquest/core/cache/cache_key.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/callback_dio.dart';
import '../support/fake_dio.dart';

const url = 'https://api.themoviedb.org/3/movie/7';

void main() {
  late HttpCache cache;
  late Dio dio;
  late FakeDioAdapter adapter;
  setUp(() {
    cache = HttpCache(MemCacheStore());
    adapter = FakeDioAdapter();
    dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: cache, debugLogging: false, retryDelay: (_) async {});
    dio.httpClientAdapter = adapter;
  });
  tearDown(() async {
    dio.close();
    await cache.close();
  });

  Future<CacheResponse> age(
      {Duration age = const Duration(days: 2), bool expired = false}) async {
    final key = normalizedCacheKey(RequestOptions(path: url), scope: 'tmdb');
    final entry = (await cache.store.get(key))!;
    final old = DateTime.now().subtract(age);
    final aged = entry.copyWith(
        requestDate: old, responseDate: old, maxStale: expired ? old : null);
    await cache.store.set(aged);
    return aged;
  }

  test('offline stale fallback retains its fixed expiration deadline',
      () async {
    adapter.enqueueJson({'title': 'saved'});
    await dio.get<Object>(url);
    final aged = await age();
    for (var i = 0; i < 3; i++) {
      adapter.enqueueError();
    }
    final response = await dio.get<Map<String, dynamic>>(url);
    expect(response.data!['title'], 'saved');
    expect(response.extra['cache'], 'stale');
    expect((await cache.store.get(aged.key))!.maxStale, aged.maxStale);
  });

  test('expired fallback is discarded and a network Failure is returned',
      () async {
    adapter.enqueueJson({'title': 'saved'});
    await dio.get<Object>(url);
    await age(expired: true);
    for (var i = 0; i < 3; i++) {
      adapter.enqueueError();
    }
    await expectLater(
        dio.get<Object>(url),
        throwsA(isA<DioException>()
            .having((e) => e.error, 'failure', const Failure.network())));
    expect(await cache.sizeBytes(), 0);
  });

  for (final status in [401, 403, 404, 409, 422, 429, 500]) {
    test('HTTP $status neither caches errors nor falls back to stale data',
        () async {
      adapter.enqueueJson({'title': 'saved'});
      await dio.get<Object>(url);
      await age();
      for (var i = 0; i < (status >= 500 ? 3 : 1); i++) {
        adapter.enqueueJson({'message': 'failed'}, statusCode: status);
      }
      await expectLater(
          dio.get<Object>(url),
          throwsA(isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', status)));
      adapter.enqueueJson({'title': 'new'});
      expect((await dio.get<Map<String, dynamic>>(url)).data!['title'], 'new');
    });
  }

  for (final headers in [
    {
      'cache-control': ['no-store']
    },
    {
      'set-cookie': ['session=secret']
    },
    {
      'vary': ['*']
    },
  ]) {
    test('uncacheable headers $headers evict the previous response', () async {
      adapter.enqueueJson({'title': 'saved'});
      await dio.get<Object>(url);
      await age();
      adapter.enqueueJson({'title': 'uncacheable'}, headers: headers);
      await dio.get<Object>(url);
      expect(await cache.sizeBytes(), 0);
      adapter.enqueueJson({'title': 'new'});
      expect((await dio.get<Map<String, dynamic>>(url)).data!['title'], 'new');
    });
  }

  test('non-GET and stream responses bypass storage', () async {
    for (final method in ['POST', 'PUT', 'DELETE']) {
      adapter.enqueueJson({'title': 'write'});
      await dio.request<Object>(url, options: Options(method: method));
    }
    adapter.enqueueJson({'title': 'stream'});
    final response = await dio.get<ResponseBody>(url,
        options: Options(responseType: ResponseType.stream));
    await response.data!.stream.drain<void>();
    expect(await cache.sizeBytes(), 0);
    expect(adapter.requests, hasLength(4));
  });

  test('query order, proxy wrapper and API key rotation share one cache key',
      () async {
    adapter.enqueueJson({'title': 'saved'});
    await dio.get<Object>('$url?language=en&page=1&api_key=one',
        options: Options(extra: {
          'tmdbProxyEnabled': true,
          'tmdbProxyUrl': 'https://proxy.example/proxy?mode=tmdb'
        }));
    final destination =
        adapter.requests.single.uri.queryParameters['destination'];
    expect(destination, '$url?language=en&page=1&api_key=one');
    expect(adapter.requests.single.uri.queryParameters['mode'], 'tmdb');
    final repeat = await dio.get<Object>('$url?api_key=two&page=1&language=en');
    expect(repeat.extra['cache'], 'hit');
    expect(adapter.requests, hasLength(1));
    // Non-TMDB api_key is significant; pages/languages are never stripped.
    expect(
        normalizedCacheKey(
            RequestOptions(path: 'https://scraper.example/providers?api_key=a'),
            scope: 'scraper'),
        isNot(normalizedCacheKey(
            RequestOptions(path: 'https://scraper.example/providers?api_key=b'),
            scope: 'scraper')));
  });

  test('Laravel users have separate cache entries and logout clearing',
      () async {
    final client = createLaravelDio(
        AppEnvironment.resolve(defineUrl: 'http://backend.test'),
        httpCache: cache,
        debugLogging: false);
    client.httpClientAdapter = adapter;
    addTearDown(client.close);
    Options owner(String id) => Options(
        headers: {'Authorization': 'Bearer secret'},
        extra: {'authScope': 'user:$id'});
    adapter.enqueueJson({'owner': 'a'});
    adapter.enqueueJson({'owner': 'b'});
    expect(
        (await client.get<Map<String, dynamic>>('ads', options: owner('a')))
            .data!['owner'],
        'a');
    expect(
        (await client.get<Map<String, dynamic>>('ads', options: owner('b')))
            .data!['owner'],
        'b');
    expect(
        (await client.get<Map<String, dynamic>>('ads', options: owner('a')))
            .data!['owner'],
        'a');
    await cache.clearScope('user:a');
    expect(
        (await client.get<Map<String, dynamic>>('ads', options: owner('b')))
            .data!['owner'],
        'b');
    await cache.clearScope('user');
    expect(await cache.sizeBytes(), 0);
    adapter.enqueueJson({'owner': 'unscoped'});
    await client.get<Object>('ads',
        options: Options(headers: {'Authorization': 'Bearer secret'}));
    expect(await cache.sizeBytes(), 0);
  });

  test(
      'concurrent metadata GETs share one request; cancelling a waiter does not cancel others',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    dio.httpClientAdapter = CallbackDioAdapter((_) async {
      calls++;
      if (!started.isCompleted) started.complete();
      await release.future;
      return jsonResponse('{"title":"saved"}', 200);
    });
    final cancellation = CancelToken();
    final first = dio.get<Object>(url);
    final second = dio.get<Object>(url, cancelToken: cancellation);
    await started.future;
    cancellation.cancel();
    await expectLater(
        second,
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.cancel)));
    release.complete();
    expect((await first).data, {'title': 'saved'});
    expect(calls, 1);
  });

  test('background refresh serves stale immediately then replaces it',
      () async {
    adapter.enqueueJson({'title': 'saved'});
    await dio.get<Object>(url);
    await age();
    final started = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    dio.httpClientAdapter = CallbackDioAdapter((_) async {
      calls++;
      if (!started.isCompleted) started.complete();
      await release.future;
      return jsonResponse('{"title":"new"}', 200);
    });
    final response = await dio.get<Object>(url,
        options: Options(extra: {'refreshStale': true}));
    expect(response.data, {'title': 'saved'});
    expect(response.extra['cache'], 'stale');
    await started.future;
    final repeat = await dio.get<Object>(url,
        options: Options(extra: {'refreshStale': true}));
    expect(repeat.data, {'title': 'saved'});
    release.complete();
    // Wait for persistence through its observable boundary, with a bounded deadline.
    for (var i = 0; i < 100; i++) {
      final key = normalizedCacheKey(RequestOptions(path: url), scope: 'tmdb');
      if ((await cache.store.get(key))
              ?.toResponse(RequestOptions(path: url))
              .data
              .toString()
              .contains('new') ==
          true) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect((await dio.get<Object>(url)).data, {'title': 'new'});
    expect(calls, 1);
  });

  test('clearing while a request is in flight prevents repopulation', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    dio.httpClientAdapter = CallbackDioAdapter((_) async {
      started.complete();
      await release.future;
      return jsonResponse('{"title":"saved"}', 200);
    });
    final response = dio.get<Object>(url);
    await started.future;
    await cache.clearAll();
    release.complete();
    expect((await response).data, {'title': 'saved'});
    expect(await cache.sizeBytes(), 0);
  });

  test('search freshness is capped and validators disabled', () async {
    const search = 'https://api.themoviedb.org/3/search/movie?query=test';
    adapter.enqueueJson({
      'results': []
    }, headers: {
      'etag': ['v1'],
      'cache-control': ['max-age=999999']
    });
    await dio.get<Object>(search);
    final key = normalizedCacheKey(RequestOptions(path: search), scope: 'tmdb');
    final entry = (await cache.store.get(key))!;
    expect(entry.cacheControl.maxAge, 300);
    expect(entry.eTag, isNull);
    final old = DateTime.now().subtract(const Duration(minutes: 10));
    await cache.store.set(entry.copyWith(requestDate: old, responseDate: old));
    adapter.enqueueJson({'results': []});
    await dio.get<Object>(search);
    expect(adapter.requests.last.headers['if-none-match'], isNull);
  });

  test(
      '304 accepted by validateStatus still returns stored JSON and diagnostics',
      () async {
    adapter.enqueueJson({
      'title': 'saved'
    }, headers: {
      'etag': ['v1']
    });
    await dio.get<Object>(url);
    await age();
    adapter.enqueueJson(null, statusCode: 304);
    final response = await dio.get<Object>(url,
        options: Options(
            validateStatus: (status) => status == 200 || status == 304));
    expect(response.statusCode, 200);
    expect(response.data, {'title': 'saved'});
    expect(response.extra['cache'], 'revalidated');
  });
  test('304 no-store serves the validated body once and evicts it', () async {
    adapter.enqueueJson({
      'title': 'saved'
    }, headers: {
      'etag': ['v1']
    });
    await dio.get<Object>(url);
    await age();
    adapter.enqueueJson(null, statusCode: 304, headers: {
      'cache-control': ['no-store']
    });
    expect((await dio.get<Object>(url)).data, {'title': 'saved'});
    expect(await cache.sizeBytes(), 0);
  });

  test('clearing during retries keeps the original invalidation generation',
      () async {
    final first = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    dio.httpClientAdapter = CallbackDioAdapter((request) async {
      calls++;
      if (calls == 1) {
        first.complete();
        await release.future;
        throw DioException(
            requestOptions: request, type: DioExceptionType.connectionError);
      }
      return jsonResponse('{"title":"saved"}', 200);
    });
    final response = dio.get<Object>(url);
    await first.future;
    await cache.clearAll();
    release.complete();
    await response;
    expect(calls, 2);
    expect(await cache.sizeBytes(), 0);
  });
  test('clearing waits for an already started storage write before deleting',
      () async {
    final slow = SlowCacheStore();
    final localCache = HttpCache(slow);
    final client = createPublicDio(AppEnvironment.resolve(isDebug: true),
        httpCache: localCache, debugLogging: false);
    client.httpClientAdapter = FakeDioAdapter()
      ..enqueueJson({'title': 'saved'});
    addTearDown(client.close);
    addTearDown(localCache.close);
    final response = client.get<Object>(url);
    await slow.started.future;
    final clearing = localCache.clearAll();
    slow.release.complete();
    await response;
    await clearing;
    expect(await localCache.sizeBytes(), 0);
  });
}

class SlowCacheStore extends MemCacheStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> set(CacheResponse response) async {
    started.complete();
    await release.future;
    await super.set(response);
  }
}
