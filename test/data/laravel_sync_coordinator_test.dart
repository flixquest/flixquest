import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flixquest/controllers/bookmark_database_controller.dart';
import 'package:flixquest/controllers/recently_watched_database_controller.dart';
import 'package:flixquest/controllers/wellness_database_controller.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/network/interceptors/auth_interceptor.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/data/repositories/auth_repository.dart';
import 'package:flixquest/data/repositories/bookmark_repository.dart';
import 'package:flixquest/data/repositories/recently_watched_repository.dart';
import 'package:flixquest/data/repositories/wellness_repository.dart';
import 'package:flixquest/data/sources/laravel_api.dart';
import 'package:flixquest/data/sync/laravel_sync_coordinator.dart';
import 'package:flixquest/data/sync/library_scope.dart';
import 'package:flixquest/data/sync/local_library.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/presentation/session/session_view_model.dart';
import '../support/fakes.dart';
import '../support/fake_dio.dart';
import '../support/session_harness.dart';
import 'wellness_repository_test.dart' show page;
import 'wellness_sync_engine_test.dart' show session;

const login = LoginRequest(email: 'beamlak@example.com', password: 'password');
void main() {
  late Directory dir;
  late FakeKvStore store;
  late FakeDioAdapter adapter;
  late Dio dio;
  late ServerClock clock;
  late WellnessDatabaseController wellness;
  late LaravelSyncCoordinator coordinator;
  late SessionViewModel vm;
  late HttpCache cache;
  final libraries = <String, LocalLibrary>{};
  Future<LocalLibrary> library(String owner) async {
    if (libraries[owner] case final existing?) return existing;
    return libraries[owner] = LocalLibrary(
        await MovieDatabaseController()
            .initializeDatabase(owner: owner, directoryPath: '${dir.path}/'),
        await TVDatabaseController()
            .initializeDatabase(owner: owner, directoryPath: '${dir.path}/'),
        await RecentlyWatchedMoviesController()
            .initializeDatabase(owner: owner, directoryPath: '${dir.path}/'),
        await RecentlyWatchedEpisodeController()
            .initializeDatabase(owner: owner, directoryPath: '${dir.path}/'));
  }

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LibraryScope.enabled = true;
    LibraryScope.activate(null);
    dir = await Directory.systemTemp.createTemp('f5-account-');
    store = FakeKvStore();
    clock = ServerClock(store,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true));
    LibraryScope.clock = clock;
    adapter = FakeDioAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    wellness = WellnessDatabaseController.forDatabase(
        await WellnessDatabaseController.instance
            .initializeDatabase(databasePath: '${dir.path}/wellness.db'));
    coordinator = LaravelSyncCoordinator(
        bookmarkRepository: BookmarkRepository(dio, store),
        recentRepository: RecentlyWatchedRepository(dio, store, clock),
        wellnessRepository: WellnessRepository(dio, store, clock),
        store: store,
        clock: clock,
        authenticatedOwner: () => vm.token == null ? null : vm.ownerId.value,
        wellness: wellness,
        openLibrary: library);
    cache = HttpCache(MemCacheStore());
    vm = SessionViewModel(
        repository: AuthRepository(LaravelApi(dio)),
        tokens: MemoryTokens(),
        preferences: store,
        cache: cache,
        google: FakeGoogleIdentity(),
        onOwnerChanged: coordinator.activateOwner,
        mergeGuestData: (user) => coordinator.mergeGuest('user:${user.id}'),
        deleteLocalData: coordinator.deleteLocal);
    dio.interceptors.add(AuthInterceptor(vm, dio.options.baseUrl));
  });
  tearDown(() async {
    coordinator.dispose();
    vm.dispose();
    dio.close();
    await cache.close();
    for (final library in libraries.values) {
      for (final table in library.tables) {
        await table.$1.close();
      }
    }
    libraries.clear();
    await (await wellness.database).close();
    await dir.delete(recursive: true);
    LibraryScope.enabled = false;
    LibraryScope.clock = null;
    LibraryScope.activate(null);
  });
  test(
      'login remaps and syncs guest rows, clears the copied guest data, and isolates deletion from another account',
      () async {
    final guest = await library('guest');
    await guest.movies
        .insert('movie_bookmark_table', Movie(id: 1, title: 'Guest').toMap());
    await guest.recentMovies.insert('recently_watched_movies_table',
        {'id': 2, 'updated_at_utc': 100, 'synced': 0});
    await wellness.upsertSession(WellnessViewingSession.fromMap(
        {...session('guest-session', 100), 'owner_id': 'guest'}));
    adapter
      ..enqueueJson(authFixture())
      ..enqueueJson({
        'success': true,
        'movies': [
          {'id': 1, 'title': 'Guest'}
        ],
        'tvShows': []
      })
      ..enqueueJson({
        'success': true,
        'server_revision': 1,
        'server_time_utc': 1000,
        'movies': [
          {'movie_id': 2, 'updated_at_utc': 100}
        ],
        'episodes': []
      })
      ..enqueueJson(page(2))
      ..enqueueJson(page(3, sessions: [session('guest-session', 1000)]));
    expect(await vm.signIn(login), isA<Ok>());
    expect(vm.ownerId.value, 'user:7');
    final account = await library('user:7');
    expect(await guest.movies.query('movie_bookmark_table'), isEmpty);
    expect(await guest.recentMovies.query('recently_watched_movies_table'),
        isEmpty);
    expect(await account.movies.query('movie_bookmark_table'), hasLength(1));
    expect(
        (await account.recentMovies.query('recently_watched_movies_table'))
            .single['synced'],
        1);
    expect(
        (await wellness.sessionsForOwner('user:7')).single.networkBytes, 1024);
    expect(await wellness.sessionsForOwner('guest'), isEmpty);
    expect(store.getString('sync.guest.claimed_by'), isNull);
    final other = await library('user:8');
    await other.movies.insert(
        'movie_bookmark_table', Movie(id: 8, title: 'Other account').toMap());
    await store.setJson('sync.user:7.up_next', [
      {'seriesId': 2}
    ]);
    adapter.enqueueJson({'success': true});
    expect(await vm.deleteAccount(), isA<Ok>());
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.uri.path, '/api/v1/user/account');
    expect(await account.movies.query('movie_bookmark_table'), isEmpty);
    expect(await wellness.sessionsForOwner('user:7'), isEmpty);
    expect(await other.movies.query('movie_bookmark_table'), hasLength(1));
    expect(store.getJson('sync.user:7.recent.cursor'), isNull);
    expect(LibraryScope.owner, 'guest');
    expect(store.getJson('sync.user:7.up_next'), isNull);
    // Reusing the captured owner in the fixture proves no local row or ledger
    // can be uploaded again after the server cascade and local wipe.
    adapter
      ..enqueueJson(authFixture())
      ..enqueueJson({'success': true, 'movies': [], 'tvShows': []})
      ..enqueueJson({
        'success': true,
        'server_revision': 1,
        'server_time_utc': 1000,
        'movies': [],
        'episodes': []
      })
      ..enqueueJson(page(2));
    expect(await vm.signIn(login), isA<Ok>());
    final last = adapter.requests.sublist(adapter.requests.length - 3);
    expect(last[0].data['movies'], isEmpty);
    expect(last[1].data['movies'], isEmpty);
    expect(last[2].data['sessions'], isEmpty);
    expect(await account.movies.query('movie_bookmark_table'), isEmpty);
    expect(await wellness.sessionsForOwner('user:7'), isEmpty);
  });
  test(
      'offline first login stays authenticated with durable pending rows and a retry clears the guest copy',
      () async {
    final guest = await library('guest');
    await guest.movies.insert(
        'movie_bookmark_table', Movie(id: 1, title: 'Offline guest').toMap());
    adapter
      ..enqueueJson(authFixture())
      ..enqueueError()
      ..enqueueError()
      ..enqueueError();
    expect(await vm.signIn(login), isA<Ok>());
    expect(vm.user?.id, 7);
    expect(store.getString('sync.guest.claimed_by'), 'user:7');
    expect(await (await library('user:7')).movies.query('movie_bookmark_table'),
        hasLength(1));
    expect(await guest.movies.query('movie_bookmark_table'), hasLength(1));
    adapter
      ..enqueueJson(authFixture())
      ..enqueueJson({
        'success': true,
        'movies': [
          {'id': 1, 'title': 'Offline guest'}
        ],
        'tvShows': []
      })
      ..enqueueJson({
        'success': true,
        'server_revision': 1,
        'server_time_utc': 1000,
        'movies': [],
        'episodes': []
      })
      ..enqueueJson(page(2));
    expect(await vm.signIn(login), isA<Ok>());
    expect(await guest.movies.query('movie_bookmark_table'), isEmpty);
    expect(store.getString('sync.guest.claimed_by'), isNull);
  });
  test(
      'an old account payload is rejected before it can receive a new account token',
      () async {
    adapter
      ..enqueueJson(authFixture(id: 8))
      ..enqueueJson({'success': true, 'movies': [], 'tvShows': []})
      ..enqueueJson({
        'success': true,
        'server_revision': 1,
        'server_time_utc': 1000,
        'movies': [],
        'episodes': []
      })
      ..enqueueJson(page(2));
    await vm.signIn(login);
    final before = adapter.requests.length;
    await expectLater(
        dio.post('sync/bookmarks',
            data: {'movies': []},
            options: Options(extra: {'syncOwner': 'user:7'})),
        throwsA(isA<DioException>()));
    expect(adapter.requests.length, before);
  });
}
