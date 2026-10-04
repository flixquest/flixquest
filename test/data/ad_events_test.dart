import 'dart:async';
import '../support/callback_dio.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flixquest/data/ads/ad_event_queue.dart';
import 'package:flixquest/data/repositories/ads_repository.dart';
import '../support/fake_dio.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
      'offline events survive restart, expire after seven days, and tolerate deleted ads',
      () async {
    final directory = await Directory.systemTemp.createTemp('ad-events');
    final path = '${directory.path}/events.db';
    var now = DateTime.utc(2026, 10, 4);
    var queue = AdEventQueue(factory: databaseFactoryFfi, path: path);
    await queue.enqueue(
        'expired', 'click', now.subtract(const Duration(days: 8)));
    final adapter = FakeDioAdapter()
      ..enqueueError()
      ..enqueueError();
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    var repository = AdsRepository(dio, events: queue, now: () => now);
    await repository.reportImpression('1');
    await repository.flush();
    await repository.reportClick('deleted');
    await repository.flush();
    expect(
        (await queue.pending()).map((event) => event.adId), ['1', 'deleted']);
    await queue.close();
    queue = AdEventQueue(factory: databaseFactoryFfi, path: path);
    repository = AdsRepository(dio, events: queue, now: () => now);
    adapter.enqueueJson({'success': true});
    adapter.enqueueJson({'success': false}, statusCode: 404);
    await repository.flush();
    expect(await queue.pending(), isEmpty);
    expect(adapter.requests.map((r) => r.uri.path), [
      '/api/v1/ads/1/impression',
      '/api/v1/ads/1/impression',
      '/api/v1/ads/1/impression',
      '/api/v1/ads/deleted/click'
    ]);
    expect(
        adapter.requests.every(
            (r) => r.method == 'POST' && r.extra['authRequired'] == false),
        true);
    await queue.close();
    dio.close();
    await directory.delete(recursive: true);
  });
  test(
      'events added during a slow flush are delivered without parallel or duplicate posts',
      () async {
    final queue =
        AdEventQueue(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await queue.enqueue('first', 'impression', DateTime.now());
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    final requests = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = CallbackDioAdapter((request) async {
        requests.add(request.uri.path);
        if (requests.length == 1) {
          started.complete();
          return response.future;
        }
        return jsonResponse('{"success":true}', 200);
      });
    final repository = AdsRepository(dio, events: queue);
    final flushing = repository.flush();
    await started.future;
    await repository.reportClick('second');
    expect(requests, hasLength(1));
    response.complete(jsonResponse('{"success":true}', 200));
    await flushing;
    expect(
        requests, ['/api/v1/ads/first/impression', '/api/v1/ads/second/click']);
    expect(await queue.pending(), isEmpty);
    await repository.dispose();
    dio.close();
  });

  for (final status in [429, 500]) {
    test('HTTP $status retains events for a later retry', () async {
      final queue =
          AdEventQueue(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      final adapter = FakeDioAdapter()
        ..enqueueJson({'success': false}, statusCode: status);
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
        ..httpClientAdapter = adapter;
      final repository = AdsRepository(dio, events: queue);
      await repository.reportClick('1');
      await repository.flush();
      expect(await queue.pending(), hasLength(1));
      expect(adapter.requests, hasLength(1));
      await repository.dispose();
      dio.close();
    });
  }
}
