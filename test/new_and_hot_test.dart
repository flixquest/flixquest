import 'package:flixquest/api/endpoints.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/new_and_hot.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem movie(int id, String? date,
        {num popularity = 0, String? art = '/a'}) =>
    MediaItem.fromMovie(Movie(
      id: id,
      title: 'Movie $id',
      releaseDate: date,
      posterPath: art,
      popularity: popularity,
    ));

MediaItem series(int id, String? date, {num popularity = 0}) =>
    MediaItem.fromSeries(TV(
      id: id,
      name: 'Series $id',
      firstAirDate: date,
      backdropPath: '/b',
      popularity: popularity,
    ));

class FakeHotSource implements NewAndHotSource {
  bool failUpcoming = false;
  bool failPremieres = false;
  int upcomingCalls = 0;
  int premiereCalls = 0;
  int movieTrendCalls = 0;
  int seriesTrendCalls = 0;

  @override
  Future<List<MediaItem>> upcomingMovies() async {
    upcomingCalls++;
    if (failUpcoming) throw Exception('offline');
    return <MediaItem>[movie(1, '2026-09-27')];
  }

  @override
  Future<List<MediaItem>> seriesPremieres(DateTime today) async {
    premiereCalls++;
    if (failPremieres) throw Exception('offline');
    return <MediaItem>[series(2, '2026-09-28')];
  }

  @override
  Future<List<MediaItem>> trending(MediaKind kind) async {
    if (kind == MediaKind.movie) {
      movieTrendCalls++;
      return <MediaItem>[movie(3, '2026-09-20')];
    }
    seriesTrendCalls++;
    return <MediaItem>[series(4, '2026-09-20')];
  }

  @override
  Future<List<Genres>> genres(MediaKind kind) async => <Genres>[];
}

void main() {
  setUp(() =>
      dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x'));

  test('premieres query covers sixty days and follows adult setting', () {
    final url = Endpoints.upcomingSeriesPremieresUrl(
      'ar',
      DateTime(2026, 9, 27),
      includeAdult: true,
    );
    expect(url, contains('first_air_date.gte=2026-09-27'));
    expect(url, contains('first_air_date.lte=2026-11-26'));
    expect(url, contains('include_adult=true'));
    expect(url, contains('language=ar'));
  });

  test('groups dates soonest first and sorts the day by popularity', () {
    final groups = groupPremieres(
      <MediaItem>[
        movie(1, '2026-10-02', popularity: 1),
        movie(2, '2026-09-28', popularity: 2),
      ],
      <MediaItem>[
        series(3, '2026-09-28', popularity: 9),
        series(4, '2026-10-02', popularity: 5),
      ],
      DateTime(2026, 9, 27),
    );
    expect(groups.map((group) => group.date.day), <int>[28, 2]);
    expect(groups.first.items.map((item) => item.id), <int>[3, 2]);
    expect(groups.last.items.map((item) => item.id), <int>[4, 1]);
  });

  test('drops yesterday, missing dates, and missing art; includes today', () {
    final groups = groupPremieres(
      <MediaItem>[
        movie(1, '2026-09-26'),
        movie(2, '2026-09-27'),
        movie(3, null),
        movie(4, '2026-09-28', art: null),
      ],
      <MediaItem>[],
      DateTime(2026, 9, 27, 23, 59),
    );
    expect(groups.single.items.single.id, 2);
  });

  test('an incomplete duplicate does not hide a dated title with artwork', () {
    final groups = groupPremieres(
      <MediaItem>[
        movie(7, null),
        movie(7, '2026-09-28'),
      ],
      <MediaItem>[],
      DateTime(2026, 9, 27),
    );
    expect(groups.single.items.single.id, 7);
  });

  test('top ten dedupes and caps an oversized source response', () {
    final list = <MediaItem>[
      for (var i = 0; i < 20; i++) movie(i, '2026-09-27'),
      movie(0, '2026-09-27'),
    ];
    expect(
        topTen(list).map((item) => item.id), List<int>.generate(10, (i) => i));
  });

  test('everyone watching alternates kinds and stops at twenty', () {
    final list = everyoneWatching(
      <MediaItem>[for (var i = 0; i < 20; i++) movie(i, '2026-09-27')],
      <MediaItem>[for (var i = 0; i < 20; i++) series(i, '2026-09-27')],
    );
    expect(list.length, 20);
    expect(list.take(4).map((item) => item.kind), <MediaKind>[
      MediaKind.movie,
      MediaKind.series,
      MediaKind.movie,
      MediaKind.series
    ]);
  });

  test('each load calls only the selected segment source', () async {
    final source = FakeHotSource();
    final catalog = NewAndHotCatalog(source, now: () => DateTime(2026, 9, 27));
    await catalog.load(HotSegment.comingSoon);
    expect(source.upcomingCalls, 1);
    expect(source.premiereCalls, 1);
    expect(source.movieTrendCalls, 0);
    expect(source.seriesTrendCalls, 0);
    await catalog.load(HotSegment.topSeries);
    expect(source.movieTrendCalls, 0);
    expect(source.seriesTrendCalls, 1);
  });

  test('one kind failing leaves the other; both failing fails the segment',
      () async {
    final source = FakeHotSource()..failPremieres = true;
    final catalog = NewAndHotCatalog(source, now: () => DateTime(2026, 9, 27));
    final feed = await catalog.load(HotSegment.comingSoon);
    expect(feed.groups.single.items.single.id, 1);
    source.failUpcoming = true;
    await expectLater(catalog.load(HotSegment.comingSoon), throwsException);
  });
}
