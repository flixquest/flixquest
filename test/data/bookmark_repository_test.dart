import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/data/repositories/bookmark_repository.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import '../support/fake_dio.dart';
import '../support/fakes.dart';

void main() {
  test(
      'bookmark union retains genres and acknowledged rows are not resurrected on the next device sync',
      () async {
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'success': true,
        'movies': [
          {'id': 1, 'title': 'Movie'},
          {'id': 2, 'title': 'Remote'}
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
    final store = FakeKvStore();
    var repository = BookmarkRepository(dio, store);
    final first = await repository.sync('user:1', [
      Movie(id: 1, title: 'Movie', genreIds: [28])
    ], <TV>[]);
    expect(first.movies.map((m) => m.id), [1, 2]);
    expect(first.movies.first.genreIds, [28]);
    repository = BookmarkRepository(dio, store);
    final second = await repository.sync('user:1', first.movies, first.tvShows);
    expect((adapter.requests.last.data as Map)['movies'], isEmpty);
    expect(second.movies.map((m) => m.id), [2]);
    dio.close();
  });
  test('offline deletion is journaled and retried by a new repository instance',
      () async {
    final adapter = FakeDioAdapter()
      ..enqueueError()
      ..enqueueJson({'success': true, 'movies': [], 'tvShows': []});
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final store = FakeKvStore();
    await expectLater(
        BookmarkRepository(dio, store).deleteMedia('movie', 9, owner: 'user:1'),
        throwsA(isA<DioException>()));
    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.uri.path, '/api/v1/sync/bookmarks/movie/9');
    await BookmarkRepository(dio, store).sync('user:1', [], []);
    expect(adapter.requests.last.data['deleted_media'], [
      {'media_type': 'movie', 'media_id': 9}
    ]);
    expect(store.getJson('sync.user:1.bookmarks.deleted'), isEmpty);
    dio.close();
  });
  test('re-adding a bookmark waits for its pending remote delete', () async {
    final adapter = FakeDioAdapter()
      ..enqueueJson({'success': true, 'movies': [], 'tvShows': []})
      ..enqueueJson({
        'success': true,
        'movies': [
          {'id': 9, 'title': 'Re-added'}
        ],
        'tvShows': []
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final deleteEntered = Completer<void>();
    final releaseDelete = Completer<void>();
    final entered = <String>[];
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      entered.add(options.method);
      if (options.method == 'DELETE') {
        deleteEntered.complete();
        await releaseDelete.future;
      }
      handler.next(options);
    }));
    final repository = BookmarkRepository(dio, FakeKvStore());
    final deletion = repository.deleteMedia('movie', 9, owner: 'user:1');
    await deleteEntered.future;
    final sync =
        repository.sync('user:1', [Movie(id: 9, title: 'Re-added')], []);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final whileDeleting = List<String>.of(entered);
    releaseDelete.complete();
    await deletion;
    final merged = await sync;
    expect(whileDeleting, ['DELETE']);
    expect(entered, ['DELETE', 'POST']);
    expect(merged.movies.single.id, 9);
    expect(adapter.requests.last.data['deleted_media'], isEmpty);
    dio.close();
  });
}
