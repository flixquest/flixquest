import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/cache/cache_key.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import '../support/fake_dio.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/data/models/announcement.dart';
import 'package:flixquest/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionHarness h;
  setUp(() async => h = await SessionHarness.create());
  tearDown(() => h.dispose());
  test(
      'active announcements accept Laravel aliases and preserve all display fields',
      () async {
    h.adapter.enqueueJson({
      'success': true,
      'messages': [
        {
          'id': 42,
          'title': 'Welcome',
          'body': null,
          'imageUrl': 'https://cdn.test/image.png',
          'actionUrl': 'https://flixquest.test',
          'buttonText': 'Open',
          'displayType': 'bottom_sheet'
        },
      ]
    });
    final result = await AnnouncementRepository(h.dio).fetchActive();
    expect(result, isA<Ok<List<Announcement>>>());
    final message = result.getOrElse((_) => []).single.toPayload();
    expect(message.id, '42');
    expect(message.title, 'Welcome');
    expect(message.body, '');
    expect(message.displayType, 'bottom_sheet');
    expect(message.imageUrl, 'https://cdn.test/image.png');
    expect(message.actionUrl, 'https://flixquest.test');
    expect(message.buttonText, 'Open');
    expect(h.adapter.requests.single.extra['authRequired'], isFalse);
    expect(h.adapter.requests.single.headers['Authorization'], isNull);
  });
  test(
      'polling coalesces requests, caches for fifteen minutes and filters expired cached messages',
      () async {
    var now = DateTime.utc(2026, 10, 4, 12);
    final repository = AnnouncementRepository(h.dio, now: () => now);
    h.adapter.enqueueJson({
      'success': true,
      'messages': [
        {'id': 1, 'title': 'Active', 'ends_at': '2026-10-04T12:05:00Z'},
        {'id': 2, 'title': 'Future', 'starts_at': '2026-10-05T00:00:00Z'},
        {'id': 3, 'title': 'Expired', 'ends_at': '2026-10-04T11:00:00Z'},
        {'id': 'invalid', 'title': 'Broken'},
      ]
    });
    final results =
        await Future.wait([repository.fetchActive(), repository.fetchActive()]);
    expect(results.first.getOrElse((_) => []).map((m) => m.id), ['1']);
    expect(h.adapter.requests.length, 1);
    now = now.add(const Duration(minutes: 6));
    expect((await repository.fetchActive()).getOrElse((_) => []), isEmpty);
    expect(h.adapter.requests.length, 1);
    now = now.add(const Duration(minutes: 9));
    h.adapter.enqueueJson({'success': true, 'messages': []});
    expect((await repository.fetchActive()).getOrElse((_) => []), isEmpty);
    await repository.fetchActive();
    expect(h.adapter.requests.length, 2);
  });

  test(
      'bad envelopes and offline requests retry without poisoning the poll cache',
      () async {
    final repository = AnnouncementRepository(h.dio);
    h.adapter.enqueueJson({'success': true, 'messages': 'broken'});
    expect(await repository.fetchActive(), isA<Err>());
    h.adapter.enqueueError();
    expect(await repository.fetchActive(), isA<Err>());
    h.adapter.enqueueJson({
      'success': true,
      'messages': [
        {'id': 8, 'title': 'Recovered'}
      ]
    });
    expect(
        (await repository.fetchActive()).getOrElse((_) => []).single.id, '8');
    expect(h.adapter.requests.length, 3);
  });
  test(
      'cold-start polling revalidates HTTP cache and offline fallback keeps its seven-day deadline',
      () async {
    final cache = HttpCache(MemCacheStore());
    final dio = createLaravelDio(
        AppEnvironment.resolve(defineUrl: 'https://backend.test'),
        httpCache: cache,
        debugLogging: false,
        retryDelay: (_) async {});
    final adapter = FakeDioAdapter();
    dio.httpClientAdapter = adapter;
    addTearDown(() async {
      dio.close();
      await cache.close();
    });
    adapter.enqueueJson({
      'success': true,
      'messages': [
        {'id': 7, 'title': 'Cached'}
      ]
    }, headers: {
      'etag': ['"messages-v1"'],
      'cache-control': ['public, no-cache']
    });
    expect(
        (await AnnouncementRepository(dio).fetchActive())
            .getOrElse((_) => [])
            .single
            .id,
        '7');
    adapter.enqueueJson(null, statusCode: 304);
    expect(
        (await AnnouncementRepository(dio).fetchActive())
            .getOrElse((_) => [])
            .single
            .id,
        '7');
    expect(adapter.requests.last.headers['if-none-match'], '"messages-v1"');
    final key = normalizedCacheKey(
        RequestOptions(path: 'https://backend.test/api/v1/messages/active'),
        scope: 'laravel');
    final original = (await cache.store.get(key))!;
    final old = DateTime.now().subtract(const Duration(days: 6));
    final deadline = old.add(const Duration(days: 7, minutes: 15));
    await cache.store.set(original.copyWith(
        requestDate: old, responseDate: old, maxStale: deadline));
    for (var i = 0; i < 3; i++) {
      adapter.enqueueError();
    }
    expect(
        (await AnnouncementRepository(dio).fetchActive())
            .getOrElse((_) => [])
            .single
            .id,
        '7');
    expect((await cache.store.get(key))!.maxStale, deadline);
    final expired = DateTime.now().subtract(const Duration(days: 8));
    await cache.store.set(original.copyWith(
        requestDate: expired,
        responseDate: expired,
        maxStale: expired.add(const Duration(days: 7, minutes: 15))));
    for (var i = 0; i < 3; i++) {
      adapter.enqueueError();
    }
    expect(await AnnouncementRepository(dio).fetchActive(), isA<Err>());
  });
}
