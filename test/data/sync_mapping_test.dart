import 'package:flixquest/catalog/up_next.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/fakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/wellness.dart';
import 'wellness_sync_engine_test.dart' show session;

void main() {
  test('backend recent fields and metadata map without adding SQLite columns',
      () {
    final movie = RecentMovie.fromLaravelMap({
      'movie_id': 5,
      'title': 'Movie',
      'release_year': 2026,
      'elapsed': 30,
      'remaining': 10,
      'date_watched': '2026-10-04',
      'updated_at_utc': 100,
      'sync_revision': 3,
      'synced_at_utc': 110
    });
    expect(movie.id, 5);
    expect(movie.syncRevision, 3);
    expect(movie.syncedAtUtc, 110);
    expect(movie.toMap().containsKey('sync_revision'), isFalse);
    expect(movie.toLaravelMap()['movie_id'], 5);
    expect(movie.toLaravelMap().containsKey('synced'), isFalse);
    final episode = RecentEpisode.fromLaravelMap({
      'episode_id': 6,
      'series_id': 7,
      'episode_num': 2,
      'season_num': 1,
      'backdrop_path': '/still.jpg',
      'updated_at_utc': 100,
      'deleted_at_utc': 100,
      'sync_revision': 4,
      'synced_at_utc': 110
    });
    expect(episode.id, 6);
    expect(episode.backdropPath, '/still.jpg');
    expect(episode.isDeleted, isTrue);
    expect(episode.syncRevision, 4);
    expect(episode.toLaravelMap()['deleted_at_utc'], 100);
  });
  test(
      'wellness payload keeps arrays and nullable network bytes through the backend mapping',
      () {
    final row = WellnessViewingSession.fromMap(session('a', 100));
    final payload = row.toLaravelMap();
    expect(payload['updated_at_utc'], 100);
    expect(payload.containsKey('updatedAtUtc'), isFalse);
    expect(payload['segments'], isA<List>());
    expect(
        WellnessViewingSession.fromMap({...payload, 'owner_id': 'user:1'})
            .networkBytes,
        1024);
    expect(
        WellnessViewingSession.fromMap(
            {...session('b', 100), 'network_bytes': null}).networkBytes,
        isNull);
  });
  test(
      'next-episode hints use the account namespace and disappear with its local wipe',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final kv = FakeKvStore();
    final account =
        UpNextStore(prefs, kvStore: kv, storageKey: 'sync.user:7.up_next');
    final other =
        UpNextStore(prefs, kvStore: kv, storageKey: 'sync.user:8.up_next');
    final entry = UpNext(
        seriesId: 1,
        seriesName: 'Series',
        finishedSeason: 1,
        finishedEpisode: 1,
        season: 1,
        episode: 2,
        watchedAt: DateTime.utc(2026, 10, 4));
    await account.save({1: entry});
    await other.save({1: entry});
    expect(account.load(), hasLength(1));
    expect(prefs.getString(UpNextStore.key), isNull);
    await kv.removePrefix('sync.user:7.');
    expect(account.load(), isEmpty);
    expect(other.load(), hasLength(1));
  });
}
