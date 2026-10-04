import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flixquest/data/ads/ad_event_queue.dart';
import 'package:flixquest/data/ads/ad_events_controller.dart';
import 'package:flixquest/data/repositories/ads_repository.dart';
import '../support/fake_dio.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
      'boot and reconnect flush queued events while disconnected hints do nothing',
      () async {
    final queue =
        AdEventQueue(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await queue.enqueue('1', 'click', DateTime.now());
    final adapter = FakeDioAdapter()
      ..enqueueJson({'success': true})
      ..enqueueJson({'success': true});
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final repository = AdsRepository(dio, events: queue);
    final changes = StreamController<bool>(sync: true);
    final controller =
        AdEventsController(repository, connections: changes.stream);
    await controller.boot();
    expect(await queue.pending(), isEmpty);
    await queue.enqueue('2', 'impression', DateTime.now());
    changes.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(adapter.requests, hasLength(1));
    changes.add(true);
    await repository.flush();
    expect(await queue.pending(), isEmpty);
    expect(adapter.requests, hasLength(2));
    await controller.dispose();
    await changes.close();
    await repository.dispose();
    dio.close();
  });
}
