import 'package:flixquest/catalog/continue_watching.dart';
import 'package:flixquest/catalog/episode_choice.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/up_next.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/tv_stream_metadata.dart';
import 'package:flixquest/provider/recently_watched_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 9, 27, 20);

TVStreamMetadata _playing({
  int season = 2,
  int episode = 4,
  List<EpisodeMetadata>? seasonEpisodes,
  List<SeasonMetadata>? allSeasons,
}) =>
    TVStreamMetadata(
      elapsed: 0,
      episodeId: 204,
      episodeName: 'Four',
      episodeNumber: episode,
      posterPath: '/poster.jpg',
      seasonNumber: season,
      seriesName: 'Severance',
      tvId: 7,
      airDate: null,
      backdropPath: '/backdrop.jpg',
      seasonEpisodes: seasonEpisodes,
      allSeasons: allSeasons,
    );

List<EpisodeMetadata> _season(int season, int count, {String? lastAirs}) => [
      for (var i = 1; i <= count; i++)
        EpisodeMetadata(
          episodeId: season * 100 + i,
          episodeName: 'Episode $i',
          episodeNumber: i,
          seasonNumber: season,
          stillPath: '/still$i.jpg',
          airDate: i == count && lastAirs != null ? lastAirs : '2020-01-01',
        ),
    ];

List<SeasonMetadata> _seasons(List<int> counts) => [
      SeasonMetadata(seasonNumber: 0, seasonName: 'Specials', episodeCount: 3),
      for (var i = 0; i < counts.length; i++)
        SeasonMetadata(
          seasonNumber: i + 1,
          seasonName: 'Season ${i + 1}',
          episodeCount: counts[i],
        ),
    ];

RecentEpisode _row(int seriesId, int season, int episode, DateTime at) =>
    RecentEpisode(
      dateTime: at.toString(),
      elapsed: 600,
      episodeName: 'E$episode',
      episodeNum: episode,
      id: seriesId * 1000 + season * 100 + episode,
      posterPath: '/p.jpg',
      remaining: 1200,
      seasonNum: season,
      seriesName: 'Series $seriesId',
      seriesId: seriesId,
      backdropPath: '/b.jpg',
      updatedAtUtc: 1,
    );

UpNext _next(int seriesId, int season, int episode, DateTime at) => UpNext(
      seriesId: seriesId,
      seriesName: 'Series $seriesId',
      finishedSeason: season,
      finishedEpisode: episode - 1,
      season: season,
      episode: episode,
      backdropPath: '/b.jpg',
      watchedAt: at,
    );

/// Recently watched in memory, recording what was asked of it.
class _FakeRecent extends ChangeNotifier implements RecentProvider {
  _FakeRecent({
    List<RecentMovie> movies = const [],
    List<RecentEpisode> episodes = const [],
    List<UpNext> upNext = const [],
  })  : _movies = List.of(movies),
        _episodes = List.of(episodes),
        _upNext = List.of(upNext);

  final List<RecentMovie> _movies;
  final List<RecentEpisode> _episodes;
  final List<UpNext> _upNext;
  final List<String> calls = <String>[];

  @override
  List<RecentMovie> get movies => _movies;
  @override
  List<RecentEpisode> get episodes => _episodes;
  @override
  List<UpNext> get upNext => _upNext;

  @override
  Future<void> deleteMovie(int id) async {
    calls.add('delete movie $id');
    _movies.removeWhere((movie) => movie.id == id);
  }

  @override
  Future<void> addMovie(RecentMovie movie) async {
    calls.add('add movie ${movie.id}');
    _movies.add(movie);
  }

  @override
  Future<void> deleteEpisode(int id, int episodeNum, int seasonNum) async {
    calls.add('delete episode $id');
    _episodes.removeWhere((episode) => episode.id == id);
  }

  @override
  Future<void> addEpisode(RecentEpisode episode) async {
    calls.add('add episode ${episode.id}');
    _episodes.add(episode);
  }

  @override
  Future<void> recordUpNext(UpNext entry) async {
    calls.add('up next ${entry.seriesId}');
    _upNext.add(entry);
  }

  @override
  Future<void> clearUpNext(int seriesId) async {
    calls.add('clear up next $seriesId');
    _upNext.removeWhere((entry) => entry.seriesId == seriesId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('what comes after a finished episode', () {
    test('the next one in the season, with what the player knew of it', () {
      final next = UpNext.after(
        _playing(seasonEpisodes: _season(2, 8), allSeasons: _seasons([9, 8])),
        now: _now,
      )!;
      expect(next.label, 'S2:E5');
      expect(next.episodeId, 205);
      expect(next.episodeName, 'Episode 5');
      expect(next.backdropPath, '/still5.jpg');
      expect(next.finishedEpisode, 4);
    });

    test('after a finale, the next season', () {
      final next = UpNext.after(
        _playing(
          episode: 8,
          seasonEpisodes: _season(2, 8),
          allSeasons: _seasons([9, 8, 10]),
        ),
        now: _now,
      )!;
      expect(next.label, 'S3:E1');
      expect(next.backdropPath, '/backdrop.jpg');
    });

    test('nothing after the last episode there is, or one yet to air', () {
      expect(
        UpNext.after(
          _playing(
            episode: 8,
            seasonEpisodes: _season(2, 8),
            allSeasons: _seasons([9, 8]),
          ),
          now: _now,
        ),
        isNull,
      );
      expect(
        UpNext.after(
          _playing(
            episode: 7,
            seasonEpisodes: _season(2, 8, lastAirs: '2027-01-01'),
            allSeasons: _seasons([9, 8]),
          ),
          now: _now,
        ),
        isNull,
      );
    });

    test("without the season's episodes, its count decides", () {
      expect(
        UpNext.after(_playing(allSeasons: _seasons([9, 8])), now: _now)!.label,
        'S2:E5',
      );
      expect(
        UpNext.after(
          _playing(episode: 8, allSeasons: _seasons([9, 8, 6])),
          now: _now,
        )!
            .label,
        'S3:E1',
      );
      // Knowing nothing, assume there's more.
      expect(UpNext.after(_playing(), now: _now)!.label, 'S2:E5');
    });

    test('survives a trip through storage', () {
      final next = _next(7, 2, 5, _now);
      final back = UpNext.fromJson(next.toJson())!;
      expect(back.label, next.label);
      expect(back.watchedAt, next.watchedAt);
      expect(UpNext.fromJson(<String, Object?>{'seriesId': 'x'}), isNull);
    });
  });

  group('Continue Watching with next episodes', () {
    test('a next episode newer than the one in progress takes its place', () {
      final items = continueWatchingItems(
        movies: const [],
        episodes: [_row(7, 2, 3, _now.subtract(const Duration(days: 1)))],
        upNext: [_next(7, 2, 5, _now)],
      );
      expect(items.single.upNext?.label, 'S2:E5');
      expect(items.single.stableId, 'up-next:7:2:5');
    });

    test('an episode started since wins over an older next episode', () {
      final items = continueWatchingItems(
        movies: const [],
        episodes: [_row(7, 2, 5, _now)],
        upNext: [_next(7, 2, 5, _now.subtract(const Duration(hours: 2)))],
      );
      expect(items.single.upNext, isNull);
      expect(items.single.recentEpisode?.episodeNum, 5);
    });

    test('a series with only a next episode still shows, newest first', () {
      final items = continueWatchingItems(
        movies: const [],
        episodes: [_row(8, 1, 1, _now.subtract(const Duration(days: 2)))],
        upNext: [_next(7, 3, 1, _now)],
      );
      expect(items.map((item) => item.id), [7, 8]);
    });
  });

  group('what Play starts', () {
    MediaItem series(int id) =>
        MediaItem.fromSeries(TV(id: id, name: 'Series $id'));

    test('the next episode when it is the latest', () {
      final next = upNextFor(
        series(7),
        episodes: [_row(7, 2, 3, _now.subtract(const Duration(days: 1)))],
        upNext: [_next(7, 2, 5, _now)],
      );
      expect(next?.label, 'S2:E5');
      expect(
        upNextFor(
          series(7),
          episodes: [_row(7, 2, 5, _now)],
          upNext: [_next(7, 2, 5, _now.subtract(const Duration(hours: 1)))],
        ),
        isNull,
      );
      expect(
        upNextFor(
          MediaItem.fromUpNext(_next(9, 1, 2, _now)),
          episodes: const [],
          upNext: const [],
        )?.label,
        'S1:E2',
      );
    });

    test('that very episode, else the usual choice', () async {
      Future<List<EpisodeList>> load(int season) async => [
            for (var i = 1; i <= 6; i++)
              EpisodeList(
                episodeId: season * 100 + i,
                episodeNumber: i,
                seasonNumber: season,
                airDate: '2020-01-01',
              ),
          ];
      final seasons = [Seasons(seasonNumber: 1), Seasons(seasonNumber: 2)];
      final choice = await chooseEpisode(
        seasons: seasons,
        resume: null,
        loadSeason: load,
        upNext: _next(7, 2, 5, _now),
      );
      expect(choice!.episode.episodeId, 205);
      expect(choice.elapsed, isNull);
      // Gone from the season: start as usual.
      final fallback = await chooseEpisode(
        seasons: seasons,
        resume: null,
        loadSeason: load,
        upNext: _next(7, 2, 40, _now),
      );
      expect(fallback!.episode.episodeId, 101);
    });
  });

  group('removing from the row', () {
    test('a series goes whole, and Undo brings it all back', () async {
      final started = _now.subtract(const Duration(days: 3));
      final recent = _FakeRecent(
        episodes: [
          _row(7, 2, 3, started),
          _row(7, 1, 9, started.subtract(const Duration(days: 9))),
          _row(8, 1, 1, _now),
        ],
        upNext: [_next(7, 2, 5, _now)],
      );
      final undo = await removeFromContinueWatching(
        recent,
        MediaItem.fromUpNext(recent.upNext.single),
      );
      expect(recent.episodes.map((row) => row.seriesId), [8]);
      expect(recent.upNext, isEmpty);
      expect(
        continueWatchingItems(
          movies: recent.movies,
          episodes: recent.episodes,
          upNext: recent.upNext,
        ).map((item) => item.id),
        [8],
      );

      await undo();
      expect(recent.episodes.where((row) => row.seriesId == 7), hasLength(2));
      expect(recent.upNext.single.label, 'S2:E5');
      final restored = recent.episodes.firstWhere((row) => row.episodeNum == 3);
      // Where it was in the row, and newer than the tombstone for sync.
      expect(restored.dateTime, started.toString());
      expect(restored.updatedAtUtc, greaterThan(1));
      expect(restored.deletedAtUtc, isNull);
    });

    test('a movie goes, and comes back', () async {
      final recent = _FakeRecent(
        movies: [
          RecentMovie(
            backdropPath: '/b.jpg',
            dateTime: _now.toString(),
            elapsed: 600,
            id: 11,
            posterPath: '/p.jpg',
            releaseYear: 2024,
            remaining: 3000,
            title: 'Dune',
          ),
        ],
      );
      final undo = await removeFromContinueWatching(
        recent,
        MediaItem.fromRecentMovie(recent.movies.single),
      );
      expect(recent.movies, isEmpty);
      await undo();
      expect(recent.calls, ['delete movie 11', 'add movie 11']);
      expect(recent.movies.single.dateTime, _now.toString());
    });
  });

  test('next episodes last between launches, fifty at most', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final book = UpNextBook(store: UpNextStore(prefs), limit: 50);
    for (var i = 0; i < 55; i++) {
      await book.record(_next(i, 1, 2, _now.add(Duration(minutes: i))));
    }
    expect(book.entries, hasLength(50));
    // The oldest went first.
    expect(book.entries.map((entry) => entry.seriesId), isNot(contains(0)));
    // A series keeps one entry, the latest.
    await book.record(_next(53, 2, 1, _now.add(const Duration(days: 1))));
    expect(book.entries.where((entry) => entry.seriesId == 53), hasLength(1));

    expect(await book.clear(54), isTrue);
    expect(await book.clear(54), isFalse);
    final reloaded = UpNextBook(store: UpNextStore(prefs));
    expect(reloaded.entries, hasLength(49));
    expect(
      reloaded.entries.firstWhere((entry) => entry.seriesId == 53).label,
      'S2:E1',
    );
  });
}
