import 'dart:io';
import 'package:flixquest/controllers/bookmark_database_controller.dart';
import 'package:flixquest/controllers/recently_watched_database_controller.dart';
import 'package:flixquest/controllers/wellness_database_controller.dart';
import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/provider/wellness_provider.dart';
import 'package:flixquest/services/local_account_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('flixquest-f2-local-');
    await databaseFactory.setDatabasesPath(directory.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '${directory.path}/');
  });
  tearDownAll(() async {
    for (final db in [
      await MovieDatabaseController().database,
      await TVDatabaseController().database,
      await RecentlyWatchedMoviesController().database,
      await RecentlyWatchedEpisodeController().database,
      await WellnessDatabaseController.instance.database
    ]) {
      await db.close();
    }
    await directory.delete(recursive: true);
  });
  Future<void> history(String owner) async {
    final now = DateTime.utc(2026, 10, 3);
    await WellnessDatabaseController.instance.upsertSession(
        WellnessViewingSession(
            id: owner,
            ownerId: owner,
            deviceId: 'test-device',
            mediaType: WellnessMediaType.movie,
            source: WellnessPlaybackSource.streaming,
            contentId: '7',
            title: 'Saved history',
            startedAtUtc: now,
            endedAtUtc: now.add(const Duration(minutes: 2)),
            timezoneOffsetMinutes: 0,
            watchedMs: 120000,
            durationMs: 300000,
            progressEndMs: 120000,
            completed: false,
            segments: const [],
            updatedAtUtc: now));
  }

  test('Laravel owner binding never adopts Firebase or guest wellness rows',
      () async {
    await history('user:legacy-firebase-uid');
    await history('guest');
    await history('user:7');
    final owner = ValueNotifier<String?>('user:7');
    await WellnessProvider.instance.bindLaravelOwner(owner);
    expect(WellnessProvider.instance.activeOwnerId, 'user:7');
    expect(
        WellnessProvider.instance.sessions.map((s) => s.ownerId), ['user:7']);
    owner.value = null;
    // Await the same public binding operation to finish the asynchronous owner reload.
    await WellnessProvider.instance.bindLaravelOwner(owner);
    expect(WellnessProvider.instance.sessions.map((s) => s.ownerId), ['guest']);
    expect(
        await WellnessDatabaseController.instance
            .ownerSessionCount('user:legacy-firebase-uid'),
        1);
  });
  test(
      'local account wipe clears libraries and only the deleted owner wellness',
      () async {
    final movies = MovieDatabaseController();
    final tv = TVDatabaseController();
    final recentMovies = RecentlyWatchedMoviesController();
    final recentEpisodes = RecentlyWatchedEpisodeController();
    for (final entry in [
      (await movies.database, movies.tableName),
      (await tv.database, tv.tableName),
      (await recentMovies.database, recentMovies.tableName),
      (await recentEpisodes.database, recentEpisodes.tableName)
    ]) {
      await entry.$1.insert(entry.$2, {'id': 7});
    }
    await history('user:8');
    await history('user:7');
    await LocalAccountData.delete('user:7');
    for (final entry in [
      (await movies.database, movies.tableName),
      (await tv.database, tv.tableName),
      (await recentMovies.database, recentMovies.tableName),
      (await recentEpisodes.database, recentEpisodes.tableName)
    ]) {
      expect(await entry.$1.query(entry.$2), isEmpty);
    }
    expect(
        await WellnessDatabaseController.instance.ownerSessionCount('user:7'),
        0);
    expect(
        await WellnessDatabaseController.instance.ownerSessionCount('user:8'),
        1);
    expect(
        await WellnessDatabaseController.instance
            .ownerSessionCount('user:legacy-firebase-uid'),
        1);
    expect(await WellnessDatabaseController.instance.ownerSessionCount('guest'),
        1);
  });
}
