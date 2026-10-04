import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flixquest/data/repositories/recently_watched_repository.dart';
import 'package:flixquest/data/sync/sync_cursor.dart';
import '../support/fakes.dart';
import '../support/fake_dio.dart';

void main() {
  test(
      'clock skew retries once with corrected versions and persists a revision cursor per account',
      () async {
    final preferences = FakeKvStore();
    final clock = ServerClock(preferences,
        now: () => DateTime.fromMillisecondsSinceEpoch(90001000, isUtc: true));
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'success': false,
        'error': 'clock_skew_detected',
        'server_time_utc': 1000
      }, statusCode: 422)
      ..enqueueJson({
        'success': true,
        'server_revision': 3,
        'server_time_utc': 1000,
        'movies': [],
        'episodes': []
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final repository = RecentlyWatchedRepository(dio, preferences, clock);
    final result = await repository.sync('user:1', movies: [
      {
        'id': 5,
        'updated_at_utc': 90001000,
        'deleted_at_utc': 90001000,
        'elapsed': 1,
        'remaining': 1
      }
    ]);
    final retried = adapter.requests.last.data as Map;
    expect(retried['client_time_utc'], 1000);
    expect(retried['movies'][0]['updated_at_utc'], 1000);
    expect(retried['movies'][0]['deleted_at_utc'], 1000);
    expect(result.revision, 3);
    await result.saveCursor();
    expect(SyncCursor.load(preferences, 'user:1', 'recent').serverRevision, 3);
    expect(SyncCursor.load(preferences, 'user:2', 'recent').serverRevision,
        isNull);
    dio.close();
  });
  test(
      'a revision ahead of the server resets to a full pull; failed responses do not advance it',
      () async {
    final preferences = FakeKvStore();
    final now = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
    final clock = ServerClock(preferences, now: () => now);
    await SyncCursor(serverRevision: 99, lastFullPullAt: now)
        .save(preferences, 'user:1', 'recent');
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'success': false,
        'errors': {
          'since_revision': ['Ahead']
        }
      }, statusCode: 422)
      ..enqueueJson({
        'success': true,
        'server_revision': 3,
        'server_time_utc': 1000,
        'movies': [],
        'episodes': []
      })
      ..enqueueError();
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final repository = RecentlyWatchedRepository(dio, preferences, clock);
    final result = await repository.sync('user:1');
    expect(adapter.requests.first.data['since_revision'], 99);
    expect(adapter.requests[1].data['since_revision'], 0);
    expect(SyncCursor.load(preferences, 'user:1', 'recent').serverRevision, 99);
    await result.saveCursor();
    expect(SyncCursor.load(preferences, 'user:1', 'recent').serverRevision, 3);
    await expectLater(repository.sync('user:1'), throwsA(isA<DioException>()));
    expect(SyncCursor.load(preferences, 'user:1', 'recent').serverRevision, 3);
    dio.close();
  });
  test('a second clock skew error is surfaced after exactly one retry',
      () async {
    final preferences = FakeKvStore();
    final clock = ServerClock(preferences,
        now: () => DateTime.fromMillisecondsSinceEpoch(90001000, isUtc: true));
    final skew = {
      'success': false,
      'error': 'clock_skew_detected',
      'server_time_utc': 1000
    };
    final adapter = FakeDioAdapter()
      ..enqueueJson(skew, statusCode: 422)
      ..enqueueJson(skew, statusCode: 422);
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    await expectLater(
        RecentlyWatchedRepository(dio, preferences, clock).sync('user:1'),
        throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(2));
    expect(SyncCursor.load(preferences, 'user:1', 'recent').serverRevision,
        isNull);
    dio.close();
  });
  test('explicit requires-full-sync response resets a previously valid cursor',
      () async {
    final preferences = FakeKvStore();
    final now = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
    final clock = ServerClock(preferences, now: () => now);
    await SyncCursor(serverRevision: 10, lastFullPullAt: now)
        .save(preferences, 'user:1', 'recent');
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'success': true,
        'server_revision': 1,
        'server_time_utc': 1000,
        'requires_full_sync': true
      })
      ..enqueueJson({
        'success': true,
        'server_revision': 2,
        'server_time_utc': 1000,
        'movies': [],
        'episodes': []
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final result =
        await RecentlyWatchedRepository(dio, preferences, clock).sync('user:1');
    expect(adapter.requests.last.data['since_revision'], 0);
    await result.saveCursor();
    expect(SyncCursor.load(preferences, 'user:1', 'recent').serverRevision, 2);
    dio.close();
  });
}
