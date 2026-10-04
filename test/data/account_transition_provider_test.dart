import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixquest/controllers/bookmark_database_controller.dart';
import 'package:flixquest/controllers/wellness_database_controller.dart';
import 'package:flixquest/core/time/server_clock.dart';
import 'package:flixquest/data/repositories/bookmark_repository.dart';
import 'package:flixquest/data/repositories/recently_watched_repository.dart';
import 'package:flixquest/data/repositories/wellness_repository.dart';
import 'package:flixquest/data/sync/laravel_sync_coordinator.dart';
import 'package:flixquest/data/sync/library_scope.dart';
import 'package:flixquest/data/sync/sync_runtime.dart';
import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/provider/bookmark_provider.dart';
import 'package:flixquest/provider/wellness_provider.dart';
import 'package:flixquest/presentation/session/auth_runtime.dart';
import '../support/fake_dio.dart';
import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LaravelSyncCoordinator coordinator;
  late Dio dio;
  late FakeDioAdapter adapter;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('f5-provider-owner-');
    await databaseFactory.setDatabasesPath(directory.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '${directory.path}/');
    final store = FakeKvStore();
    final clock = ServerClock(store);
    adapter = FakeDioAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    coordinator = LaravelSyncCoordinator(
        bookmarkRepository: BookmarkRepository(dio, store),
        recentRepository: RecentlyWatchedRepository(dio, store, clock),
        wellnessRepository: WellnessRepository(dio, store, clock),
        store: store,
        clock: clock,
        authenticatedOwner: () => LibraryScope.owner);
    SyncRuntime.configure(coordinator, enabled: true);
    SharedPreferences.setMockInitialValues({});
    AuthRuntime.enabled = true;
    await WellnessProvider.instance.initialize();
  });
  tearDownAll(() async {
    WellnessProvider.instance.dispose();
    coordinator.dispose();
    dio.close();
    for (final owner in ['user:7', 'user:8']) {
      await (await MovieDatabaseController().databaseForOwner(owner)).close();
      await (await TVDatabaseController().databaseForOwner(owner)).close();
    }
    await (await WellnessDatabaseController.instance.database).close();
    await directory.delete(recursive: true);
    LibraryScope.enabled = false;
    LibraryScope.activate(null);
  });
  test(
      'bookmark delete cannot use the account activated during its local reload',
      () async {
    for (final type in ['movie', 'tv']) {
      coordinator.activateOwner('user:7');
      final movies = MovieDatabaseController();
      final tv = TVDatabaseController();
      for (final owner in ['user:7', 'user:8']) {
        await (await movies.databaseForOwner(owner))
            .insert(movies.tableName, {'id': 9});
        await (await tv.databaseForOwner(owner))
            .insert(tv.tableName, {'id': 9});
      }
      final provider = BookmarkProvider();
      provider.addListener(() {
        if (provider.isLoading) coordinator.activateOwner('user:8');
      });
      adapter.enqueueJson({'success': true});
      if (type == 'movie') {
        await provider.removeMovie(9);
      } else {
        await provider.removeTV(9);
      }
      expect(adapter.requests, isEmpty);
      expect(coordinator.store.getJson('sync.user:7.bookmarks.deleted'),
          contains('$type:9'));
      expect(
          await (await movies.databaseForOwner('user:8'))
              .query(movies.tableName),
          hasLength(1));
      expect(await (await tv.databaseForOwner('user:8')).query(tv.tableName),
          hasLength(1));
      provider.dispose();
      for (final owner in ['user:7', 'user:8']) {
        await (await movies.databaseForOwner(owner)).delete(movies.tableName);
        await (await tv.databaseForOwner(owner)).delete(tv.tableName);
      }
    }
  });
  test(
      'a disposed player save cannot resurrect history after an owner change or wipe',
      () async {
    coordinator.activateOwner('user:7');
    final owner = ValueNotifier<String?>('user:7');
    await WellnessProvider.instance.bindLaravelOwner(owner);
    final started = DateTime.now().subtract(const Duration(minutes: 1));
    final tracker = WellnessPlaybackTracker(
        id: 'old-player',
        createdAt: started,
        libraryGeneration: LibraryScope.generation)
      ..play(started);
    coordinator.activateOwner('user:8');
    owner.value = 'user:8';
    await WellnessProvider.instance.bindLaravelOwner(owner);
    await WellnessProvider.instance.recordPlayback(
        sessionId: tracker.id,
        tracker: tracker,
        mediaType: WellnessMediaType.movie,
        source: WellnessPlaybackSource.streaming,
        contentId: '9',
        title: 'Old player',
        durationMs: 120000,
        progressEndMs: 60000,
        completed: false);
    expect(await WellnessDatabaseController.instance.sessionsForOwner('user:8'),
        isEmpty);
    expect(await WellnessDatabaseController.instance.sessionsForOwner('user:7'),
        isEmpty);
    coordinator.activateOwner('user:7');
    owner.value = 'user:7';
    await WellnessProvider.instance.bindLaravelOwner(owner);
    final beforeWipe = WellnessPlaybackTracker(
        id: 'before-wipe',
        createdAt: started,
        libraryGeneration: LibraryScope.generation)
      ..play(started);
    LibraryScope.generation++;
    await WellnessDatabaseController.instance.permanentlyDeleteOwner('user:7');
    await WellnessProvider.instance.recordPlayback(
        sessionId: beforeWipe.id,
        tracker: beforeWipe,
        mediaType: WellnessMediaType.movie,
        source: WellnessPlaybackSource.offline,
        contentId: '9',
        title: 'Before wipe',
        durationMs: 120000,
        progressEndMs: 60000,
        completed: false);
    expect(await WellnessDatabaseController.instance.sessionsForOwner('user:7'),
        isEmpty);
  });
}
