import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flixquest/controllers/recently_watched_database_controller.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flixquest/data/repositories/recently_watched_repository.dart';
import 'package:flixquest/data/sync/recent_sync_engine.dart';
import '../support/fakes.dart';
import '../support/fake_dio.dart';

void main() {
  test(
      'an in-flight playback edit stays pending; a newer remote tombstone wins',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('f5-recent-');
    final movies = await RecentlyWatchedMoviesController()
        .initializeDatabase(directoryPath: '${dir.path}/');
    final episodes = await RecentlyWatchedEpisodeController()
        .initializeDatabase(directoryPath: '${dir.path}/');
    final store = FakeKvStore();
    final clock = ServerClock(store,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
    final adapter = FakeDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    await movies.insert('recently_watched_movies_table',
        {'id': 1, 'updated_at_utc': 10, 'synced': 0});
    await movies.insert('recently_watched_movies_table',
        {'id': 2, 'updated_at_utc': 10, 'synced': 1});
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      await movies.update('recently_watched_movies_table',
          {'updated_at_utc': 30, 'elapsed': 99, 'synced': 0},
          where: 'id = 1');
      handler.next(options);
    }));
    adapter.enqueueJson({
      'success': true,
      'server_revision': 5,
      'server_time_utc': 1000,
      'movies': [
        {'movie_id': 1, 'updated_at_utc': 10},
        {'movie_id': 2, 'updated_at_utc': 20, 'deleted_at_utc': 20}
      ],
      'episodes': []
    });
    await RecentSyncEngine(RecentlyWatchedRepository(dio, store, clock), clock)
        .sync('user:1', movies, episodes);
    final rows =
        await movies.query('recently_watched_movies_table', orderBy: 'id');
    expect(rows[0]['elapsed'], 99);
    expect(rows[0]['synced'], 0);
    expect(rows[1]['deleted_at_utc'], 20);
    expect(rows[1]['synced'], 1);
    await movies.close();
    await episodes.close();
    dio.close();
    await dir.delete(recursive: true);
  });
  test(
      '451 future-dated rows use 450-row batches and correction also reaches the later batch',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('f5-batches-');
    final movies = await RecentlyWatchedMoviesController()
        .initializeDatabase(directoryPath: '${dir.path}/');
    final episodes = await RecentlyWatchedEpisodeController()
        .initializeDatabase(directoryPath: '${dir.path}/');
    await movies.transaction((txn) async {
      for (var id = 1; id <= 451; id++) {
        await txn.insert('recently_watched_movies_table',
            {'id': id, 'updated_at_utc': 90001000, 'synced': 0});
      }
    });
    final store = FakeKvStore();
    final clock = ServerClock(store,
        now: () => DateTime.fromMillisecondsSinceEpoch(90001000, isUtc: true));
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'success': false,
        'error': 'clock_skew_detected',
        'server_time_utc': 1000
      }, statusCode: 422)
      ..enqueueJson({
        'success': true,
        'server_revision': 1,
        'server_time_utc': 1000,
        'movies': List.generate(
            450, (i) => {'movie_id': i + 1, 'updated_at_utc': 1000}),
        'episodes': []
      })
      ..enqueueJson({
        'success': true,
        'server_revision': 2,
        'server_time_utc': 1000,
        'movies': [
          {'movie_id': 451, 'updated_at_utc': 1000}
        ],
        'episodes': []
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    await RecentSyncEngine(RecentlyWatchedRepository(dio, store, clock), clock)
        .sync('user:1', movies, episodes);
    expect(adapter.requests.first.data['movies'], hasLength(450));
    expect(adapter.requests.last.data['movies'], hasLength(1));
    expect(adapter.requests.last.data['movies'][0]['updated_at_utc'], 1000);
    expect(
        await movies.query('recently_watched_movies_table',
            where: 'synced = 0'),
        isEmpty);
    expect(await movies.query('recently_watched_movies_table'), hasLength(451));
    await movies.close();
    await episodes.close();
    dio.close();
    await dir.delete(recursive: true);
  });
}
