import 'package:flixquest/catalog/details_play.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/up_next.dart';
import 'package:flixquest/models/credits.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/videos.dart';
import 'package:flutter_test/flutter_test.dart';

final _movie = MediaItem.fromMovie(Movie(id: 1, title: 'Heat'));
final _series = MediaItem.fromSeries(TV(id: 9, name: 'Dark'));

RecentMovie _watchedMovie({required int elapsed, required int remaining}) =>
    RecentMovie(
      backdropPath: '/b.jpg',
      dateTime: DateTime(2026, 9, 20).toString(),
      elapsed: elapsed,
      id: 1,
      posterPath: '/p.jpg',
      releaseYear: 1995,
      remaining: remaining,
      title: 'Heat',
    );

RecentEpisode _episode(
  int season,
  int episode, {
  int elapsed = 600,
  int remaining = 1200,
  DateTime? at,
}) =>
    RecentEpisode(
      dateTime: (at ?? DateTime(2026, 9, 20)).toString(),
      elapsed: elapsed,
      episodeName: 'E$episode',
      episodeNum: episode,
      id: 9000 + season * 100 + episode,
      posterPath: '/p.jpg',
      remaining: remaining,
      seasonNum: season,
      seriesName: 'Dark',
      seriesId: 9,
    );

UpNext _next(int season, int episode, DateTime at) => UpNext(
      seriesId: 9,
      seriesName: 'Dark',
      finishedSeason: season,
      finishedEpisode: episode - 1,
      season: season,
      episode: episode,
      watchedAt: at,
    );

void main() {
  group('the main button', () {
    test('a movie not started plays', () {
      final plan = detailsPlayFor(_movie, const WatchHistory());
      expect(plan.kind, DetailsPlayKind.play);
      expect(plan.resume, isNull);
    });

    test('a movie part way through resumes, with its progress', () {
      final plan = detailsPlayFor(
        _movie,
        WatchHistory(movies: [_watchedMovie(elapsed: 1800, remaining: 5400)]),
      );
      expect(plan.kind, DetailsPlayKind.resume);
      expect(plan.resuming, isTrue);
      expect(plan.resume!.progress, closeTo(.25, .001));
    });

    test('a finished movie plays from the start', () {
      final plan = detailsPlayFor(
        _movie,
        WatchHistory(movies: [_watchedMovie(elapsed: 7000, remaining: 60)]),
      );
      expect(plan.kind, DetailsPlayKind.play);
    });

    test('a series not started plays its first season\'s first episode', () {
      final plan = detailsPlayFor(
        _series,
        const WatchHistory(),
        firstSeason: 1,
      );
      expect(plan.kind, DetailsPlayKind.playEpisode);
      expect(plan.episode, 'S1:E1');
    });

    test('a series whose first season is not 1 says so', () {
      final plan = detailsPlayFor(
        _series,
        const WatchHistory(),
        firstSeason: 2,
      );
      expect(plan.episode, 'S2:E1');
    });

    test('an episode part way through resumes by name', () {
      final plan = detailsPlayFor(
        _series,
        WatchHistory(episodes: [_episode(2, 4)]),
        firstSeason: 1,
      );
      expect(plan.kind, DetailsPlayKind.resumeEpisode);
      expect(plan.episode, 'S2:E4');
      expect(plan.resume, isNotNull);
    });

    test('after a finished episode, the next one plays by name', () {
      final plan = detailsPlayFor(
        _series,
        WatchHistory(
          episodes: [
            _episode(2, 4, elapsed: 2700, remaining: 30),
          ],
          upNext: [_next(2, 5, DateTime(2026, 9, 21))],
        ),
        firstSeason: 1,
      );
      expect(plan.kind, DetailsPlayKind.playEpisode);
      expect(plan.episode, 'S2:E5');
      expect(plan.upNext, isNotNull);
      expect(plan.resuming, isFalse);
    });

    test('an episode started after the up-next record wins over it', () {
      final plan = detailsPlayFor(
        _series,
        WatchHistory(
          episodes: [_episode(3, 1, at: DateTime(2026, 9, 25))],
          upNext: [_next(2, 5, DateTime(2026, 9, 21))],
        ),
        firstSeason: 1,
      );
      expect(plan.kind, DetailsPlayKind.resumeEpisode);
      expect(plan.episode, 'S3:E1');
    });

    test('a finished episode with no record of what follows: next episode', () {
      final plan = detailsPlayFor(
        _series,
        WatchHistory(episodes: [_episode(1, 8, elapsed: 2700, remaining: 10)]),
        firstSeason: 1,
      );
      expect(plan.kind, DetailsPlayKind.nextEpisode);
      expect(plan.resume, isNull);
    });
  });

  test('episode progress is found by series, season and number', () {
    final watched = [_episode(1, 3, elapsed: 300, remaining: 900)];
    expect(
      episodeProgress(watched, seriesId: 9, season: 1, episode: 3),
      closeTo(.25, .001),
    );
    expect(
        episodeProgress(watched, seriesId: 9, season: 2, episode: 3), isNull);
    expect(
        episodeProgress(watched, seriesId: 8, season: 1, episode: 3), isNull);
  });

  test('credits: three stars in billing order, directors, creators', () {
    final credits = Credits(
      cast: [
        Cast(name: 'Third', order: 2),
        Cast(name: 'First', order: 0),
        Cast(name: 'Fourth', order: 3),
        Cast(name: 'Second', order: 1),
      ],
      crew: [
        Crew(name: 'Michael Mann', job: 'Director'),
        Crew(name: 'Someone', job: 'Writer'),
        Crew(name: 'Michael Mann', job: 'Director'),
      ],
    );
    expect(starring(credits), ['First', 'Second', 'Third']);
    expect(directors(credits), ['Michael Mann']);
    expect(
      creators(TVDetails(createdBy: [CreatedBy(name: 'Baran bo Odar')])),
      ['Baran bo Odar'],
    );
    expect(starring(null), isEmpty);
  });

  test('the trailer is a YouTube trailer before a teaser or a featurette', () {
    Results video(String key, String type, {String site = 'YouTube'}) =>
        Results(name: key, videoLink: key, type: type, site: site);
    expect(
      pickTrailer(Videos(result: [
        video('a', 'Featurette'),
        video('b', 'Teaser'),
        video('c', 'Trailer', site: 'Vimeo'),
        video('d', 'Trailer'),
      ]))!
          .videoLink,
      'd',
    );
    expect(
      pickTrailer(Videos(result: [video('a', 'Clip'), video('b', 'Teaser')]))!
          .videoLink,
      'b',
    );
    expect(pickTrailer(Videos(result: [Results(name: 'x')])), isNull);
    expect(pickTrailer(null), isNull);
  });

  test('more like this alternates the two lists, once each, never itself', () {
    MediaItem movie(int id) => MediaItem.fromMovie(Movie(id: id, title: '$id'));
    final merged = moreLikeThis(
      _movie,
      [movie(2), movie(3), movie(1)],
      [movie(3), movie(4)],
    );
    expect(merged.map((item) => item.id), [2, 3, 4]);
  });

  test('viewing insights take names from the details, else the language', () {
    final insights = insightsMetadata(
      genres: const ['Crime', '', 'Crime', 'Drama'],
      originalLanguage: 'de',
    );
    expect(insights.genres, ['Crime', 'Drama']);
    expect(insights.languages, ['de']);
    expect(insights.countries, isEmpty);
  });
}
