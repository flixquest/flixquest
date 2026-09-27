import 'package:flixquest/catalog/continue_watching.dart';
import 'package:flixquest/catalog/details_controller.dart';
import 'package:flixquest/catalog/episode_choice.dart';
import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/catalog/home_hero.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 26, 20);

RecentMovie _movie(
  int id, {
  required DateTime watched,
  int elapsed = 600,
  int remaining = 3000,
  String? backdrop = '/b.jpg',
}) =>
    RecentMovie(
      backdropPath: backdrop,
      dateTime: watched.toString(),
      elapsed: elapsed,
      id: id,
      posterPath: '/p.jpg',
      releaseYear: 2024,
      remaining: remaining,
      title: 'Movie $id',
    );

RecentEpisode _episode(
  int seriesId, {
  required int season,
  required int number,
  required DateTime watched,
  int elapsed = 600,
  int remaining = 1800,
}) =>
    RecentEpisode(
      dateTime: watched.toString(),
      elapsed: elapsed,
      episodeName: 'Episode $number',
      episodeNum: number,
      id: seriesId * 1000 + season * 100 + number,
      posterPath: '/p.jpg',
      remaining: remaining,
      seasonNum: season,
      seriesName: 'Series $seriesId',
      seriesId: seriesId,
      backdropPath: '/b.jpg',
    );

MediaItem _chart(MediaKind kind, int id) => MediaItem(
      kind: kind,
      id: id,
      title: '${kind.name} $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      rating: null,
      releaseDate: null,
    );

HomeFeed _feed(List<MediaItem> topTen) => HomeFeed(
      filter: HomeFilter.all,
      rows: <MediaKind, KindRows>{MediaKind.movie: KindRows(topTen: topTen)},
    );

void main() {
  group('Continue Watching', () {
    test('movies and series merge newest first, a series once', () {
      final items = continueWatchingItems(
        movies: <RecentMovie>[
          _movie(1, watched: _now.subtract(const Duration(hours: 1))),
          _movie(2, watched: _now.subtract(const Duration(days: 2))),
        ],
        episodes: <RecentEpisode>[
          // The store lists episodes newest first.
          _episode(7, season: 1, number: 3, watched: _now),
          _episode(7, season: 1, number: 2, watched: _now),
          _episode(8,
              season: 2,
              number: 1,
              watched: _now.subtract(
                const Duration(days: 1),
              )),
        ],
      );
      expect(items.map((item) => item.stableId), <String>[
        'recent-series:7:1:3',
        'recent-movie:1',
        'recent-series:8:2:1',
        'recent-movie:2',
      ]);
    });

    test('a finished movie is left out', () {
      final items = continueWatchingItems(
        movies: <RecentMovie>[
          _movie(1, watched: _now, elapsed: 5000, remaining: 60),
          _movie(2, watched: _now),
        ],
        episodes: const <RecentEpisode>[],
      );
      expect(items.map((item) => item.id), <int>[2]);
    });

    test('the filter keeps only its kind, and the row holds 16', () {
      final movies = <RecentMovie>[
        for (var i = 1; i <= 20; i++) _movie(i, watched: _now),
      ];
      final episodes = <RecentEpisode>[
        _episode(50, season: 1, number: 1, watched: _now),
      ];
      expect(
        continueWatchingItems(
          movies: movies,
          episodes: episodes,
          filter: HomeFilter.series,
        ).map((item) => item.kind),
        <MediaKind>[MediaKind.series],
      );
      expect(
        continueWatchingItems(
          movies: movies,
          episodes: episodes,
          filter: HomeFilter.movies,
        ).every((item) => item.kind == MediaKind.movie),
        isTrue,
      );
      expect(
        continueWatchingItems(movies: movies, episodes: episodes),
        hasLength(16),
      );
    });
  });

  group('the hero', () {
    final spotlight = <MediaItem>[
      _chart(MediaKind.movie, 99),
      _chart(MediaKind.series, 98),
      _chart(MediaKind.movie, 1),
    ];
    HomeFeed feed() => HomeFeed(
          filter: HomeFilter.all,
          spotlight: spotlight,
        );

    test('turns through the spotlight', () {
      final heroes = chooseHomeHeroes(
        filter: HomeFilter.all,
        feed: feed(),
        continueWatching: const [],
        now: _now,
      );
      expect(heroes.map((hero) => hero.item.id), <int>[99, 98, 1]);
      expect(heroes.any((hero) => hero.continuing), isFalse);
    });

    test('under All, a title played in the last three days leads, once', () {
      final heroes = chooseHomeHeroes(
        filter: HomeFilter.all,
        feed: feed(),
        continueWatching: continueWatchingItems(
          movies: <RecentMovie>[
            _movie(1, watched: _now.subtract(const Duration(days: 2))),
          ],
          episodes: const <RecentEpisode>[],
        ),
        now: _now,
      );
      expect(heroes.first.continuing, isTrue);
      expect(heroes.map((hero) => hero.item.id), <int>[1, 99, 98]);
    });

    test('not when that title is older, or has no artwork', () {
      for (final recent in <RecentMovie>[
        _movie(1, watched: _now.subtract(const Duration(days: 4))),
        _movie(1, watched: _now, backdrop: null),
      ]) {
        final heroes = chooseHomeHeroes(
          filter: HomeFilter.all,
          feed: feed(),
          continueWatching: continueWatchingItems(
            movies: <RecentMovie>[recent],
            episodes: const <RecentEpisode>[],
          ),
          now: _now,
        );
        expect(heroes.first.continuing, isFalse);
        expect(heroes.first.item.id, 99);
      }
    });

    test('Movies and Series keep to the spotlight', () {
      final heroes = chooseHomeHeroes(
        filter: HomeFilter.movies,
        feed: feed(),
        continueWatching: continueWatchingItems(
          movies: <RecentMovie>[_movie(1, watched: _now)],
          episodes: const <RecentEpisode>[],
        ),
        now: _now,
      );
      expect(heroes.first.item.id, 99);
    });

    test("with no spotlight, the day's #1 alone", () {
      final heroes = chooseHomeHeroes(
        filter: HomeFilter.all,
        feed: _feed(<MediaItem>[_chart(MediaKind.movie, 7)]),
        continueWatching: const [],
      );
      expect(heroes.map((hero) => hero.item.id), <int>[7]);
    });
  });

  group('which episode Play starts', () {
    final seasons = <Seasons>[
      Seasons(seasonNumber: 1),
      Seasons(seasonNumber: 2),
      Seasons(seasonNumber: 0),
    ];
    List<EpisodeList> season(int number, int count, {String? airDate}) =>
        <EpisodeList>[
          for (var i = 1; i <= count; i++)
            EpisodeList(
              episodeId: number * 100 + i,
              episodeNumber: i,
              seasonNumber: number,
              airDate: airDate ?? '2020-01-01',
            ),
        ];
    Future<List<EpisodeList>> load(int number) async => switch (number) {
          1 => season(1, 3),
          2 => season(2, 2),
          _ => season(0, 1),
        };
    ResumePoint resume(int s, int e, {int remaining = 900}) => ResumePoint(
          elapsed: 600,
          remaining: remaining,
          episode: _episode(7, season: s, number: e, watched: _now),
        );

    test('the episode in progress, where it was left', () async {
      final choice = (await chooseEpisode(
        seasons: seasons,
        resume: resume(1, 2),
        loadSeason: load,
      ))!;
      expect(choice.episode.episodeId, 102);
      expect(choice.elapsed, 600);
    });

    test('the next one after a finished episode', () async {
      final choice = (await chooseEpisode(
        seasons: seasons,
        resume: resume(1, 2, remaining: 30),
        loadSeason: load,
      ))!;
      expect(choice.episode.episodeId, 103);
      expect(choice.elapsed, isNull);
    });

    test('on into the next season after a finale', () async {
      final choice = (await chooseEpisode(
        seasons: seasons,
        resume: resume(1, 3, remaining: 30),
        loadSeason: load,
      ))!;
      expect(choice.episode.episodeId, 201);
    });

    test('the very first episode, with nothing watched', () async {
      final choice = (await chooseEpisode(
        seasons: seasons,
        resume: null,
        loadSeason: load,
      ))!;
      expect(choice.episode.episodeId, 101);
    });

    test('not an episode that has yet to air', () async {
      final choice = (await chooseEpisode(
        seasons: seasons,
        resume: resume(1, 3, remaining: 30),
        loadSeason: (number) async => number == 2
            ? season(2, 2, airDate: '2099-01-01')
            : season(number, 3),
        now: _now,
      ))!;
      // Nothing new has aired: start the series over.
      expect(choice.episode.episodeId, 101);
    });
  });
}
