import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flixquest/data/repositories/wellness_repository.dart';
import 'package:flixquest/data/sync/sync_cursor.dart';
import '../support/fakes.dart';
import '../support/fake_dio.dart';

Map<String, dynamic> page(int revision,
        {List sessions = const [],
        bool more = false,
        String? cursor,
        List daily = const []}) =>
    {
      'success': true,
      'server_revision': revision,
      'server_time_utc': 1000,
      'sessions': sessions,
      'daily': daily,
      'has_more': more,
      'next_cursor': cursor,
    };
void main() {
  test(
      'uploads all batches before draining a stable pull; saves only after apply and reseeds ledger',
      () async {
    final store = FakeKvStore();
    final clock = ServerClock(store,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
    final adapter = FakeDioAdapter()
      ..enqueueJson(page(1, more: true, cursor: 'upload-page'))
      ..enqueueJson(page(2))
      ..enqueueJson(page(3,
          sessions: [
            {'id': 'a', 'network_bytes': 123}
          ],
          daily: [
            {'local_day': '2026-10-04', 'updated_at_utc': 9}
          ],
          more: true,
          cursor: 'pull-page'))
      ..enqueueJson(page(3, sessions: [
        {'id': 'b', 'deleted_at_utc': 9}
      ]));
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final repository = WellnessRepository(dio, store, clock);
    final result = await repository.sync('user:1',
        sessions: List.generate(451, (i) => {'id': '$i', 'updated_at_utc': 10}),
        daily: [
          {'local_day': '2026-10-04', 'updated_at_utc': 10}
        ]);
    expect(adapter.requests[0].data['sessions'], hasLength(450));
    expect(adapter.requests[1].data['sessions'], hasLength(1));
    expect(adapter.requests[2].data['since_revision'], 0);
    expect(adapter.requests[2].data['sessions'], isEmpty);
    expect(adapter.requests[3].data['cursor'], 'pull-page');
    expect(adapter.requests[3].data['sessions'], isEmpty);
    expect(adapter.requests[3].data['daily'], isEmpty);
    expect(result.sessions.map((s) => s['id']), ['a', 'b']);
    expect(result.sessions.first['network_bytes'], 123);
    expect(SyncCursor.load(store, 'user:1', 'wellness').serverRevision, isNull);
    await result.save();
    expect(SyncCursor.load(store, 'user:1', 'wellness').serverRevision, 3);
    expect(repository.dailyLedger('user:1'), {'2026-10-04': 9});
    dio.close();
  });
  test(
      'a failed later page keeps the durable cursor and daily ledger unchanged',
      () async {
    final store = FakeKvStore();
    final clock = ServerClock(store,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
    final adapter = FakeDioAdapter()
      ..enqueueJson(page(3, more: true, cursor: 'next'))
      ..enqueueError();
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final repository = WellnessRepository(dio, store, clock);
    await expectLater(repository.sync('user:1'), throwsA(isA<DioException>()));
    expect(SyncCursor.load(store, 'user:1', 'wellness').serverRevision, isNull);
    expect(repository.dailyLedger('user:1'), isEmpty);
    dio.close();
  });
}
