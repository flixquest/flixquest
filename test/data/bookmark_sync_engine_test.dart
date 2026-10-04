import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flixquest/controllers/bookmark_database_controller.dart';
import 'package:flixquest/data/repositories/bookmark_repository.dart';
import 'package:flixquest/data/sync/bookmark_sync_engine.dart';
import 'package:flixquest/models/movie.dart';
import '../support/fakes.dart';
import '../support/fake_dio.dart';

void main() {
  test(
      'SQLite union backfills genres, retains save dates, and applies a remote deletion on the next pull',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('f5-bookmarks-');
    final movies = await MovieDatabaseController()
        .initializeDatabase(directoryPath: '${dir.path}/');
    final tv = await TVDatabaseController()
        .initializeDatabase(directoryPath: '${dir.path}/');
    await movies.insert('movie_bookmark_table',
        Movie(id: 1, title: 'Local', dateAdded: '2026-01-01').toMap());
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'success': true,
        'movies': [
          {
            'id': 1,
            'title': 'Local',
            'genre_ids': [28]
          },
          {'id': 2, 'title': 'Remote', 'created_at': '2026-01-02'}
        ],
        'tvShows': []
      })
      ..enqueueJson({
        'success': true,
        'movies': [
          {'id': 2, 'title': 'Remote'}
        ],
        'tvShows': []
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final engine = BookmarkSyncEngine(BookmarkRepository(dio, FakeKvStore()));
    await engine.sync('user:1', movies, tv);
    final first = await movies.query('movie_bookmark_table', orderBy: 'id');
    expect(first, hasLength(2));
    expect(first[0]['genre_ids'], '28');
    expect(first[0]['date_added'], '2026-01-01');
    expect(first[1]['date_added'], '2026-01-02');
    await engine.sync('user:1', movies, tv);
    expect((await movies.query('movie_bookmark_table')).single['id'], 2);
    await movies.close();
    await tv.close();
    dio.close();
    await dir.delete(recursive: true);
  });
}
