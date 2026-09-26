import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _item(MediaKind kind, int id) => MediaItem(
      kind: kind,
      id: id,
      title: '${kind.name} $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      rating: null,
      releaseDate: null,
    );

List<MediaItem> _movies(Iterable<int> ids) =>
    ids.map((id) => _item(MediaKind.movie, id)).toList();
List<MediaItem> _series(Iterable<int> ids) =>
    ids.map((id) => _item(MediaKind.series, id)).toList();

List<String> _keys(List<MediaItem> items) => items.map(titleKey).toList();

/// Serves fixed lists, records what was asked for, and fails whatever it is
/// told to.
class _FakeSource implements HomeFeedSource {
  _FakeSource({
    this.lists = const {},
    this.services = const {},
    this.failing = const {},
    this.failServices = false,
  });

  final Map<(MediaKind, HomeList), List<MediaItem>> lists;
  final Map<(MediaKind, int), List<MediaItem>> services;
  final Set<(MediaKind, HomeList)> failing;
  final bool failServices;
  final List<Object> requests = <Object>[];

  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async {
    requests.add((kind, list));
    if (failing.contains((kind, list))) throw Exception('offline');
    return lists[(kind, list)] ?? const <MediaItem>[];
  }

  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) async {
    requests.add(('service', kind, providerId));
    if (failServices) throw Exception('offline');
    return services[(kind, providerId)] ?? const <MediaItem>[];
  }

  @override
  Future<List<Genres>> genres(MediaKind kind) async {
    requests.add(('genres', kind));
    return <Genres>[
      Genres(genreID: kind == MediaKind.movie ? 28 : 10759, genreName: 'x'),
    ];
  }
}

void main() {
  group('filters', () {
    test('All mixes movies and series in turn', () async {
      final source = _FakeSource(lists: {
        (MediaKind.movie, HomeList.trendingWeek): _movies([1, 2]),
        (MediaKind.series, HomeList.trendingWeek): _series([1, 2, 3]),
      });
      final feed = await HomeFeedController(source).load(HomeFilter.all);
      expect(_keys(feed.trending), <String>[
        'movie:1',
        'series:1',
        'movie:2',
        'series:2',
        'series:3',
      ]);
      expect(feed.movieGenres, hasLength(1));
      expect(feed.seriesGenres, hasLength(1));
    });

    test('Movies asks only for movies', () async {
      final source = _FakeSource(lists: {
        (MediaKind.movie, HomeList.trendingWeek): _movies([1]),
        (MediaKind.series, HomeList.trendingWeek): _series([1]),
      });
      final feed = await HomeFeedController(source).load(HomeFilter.movies);
      expect(_keys(feed.trending), <String>['movie:1']);
      expect(feed.seriesGenres, isEmpty);
      expect(
        source.requests.where(
          (request) => request.toString().contains('MediaKind.series'),
        ),
        isEmpty,
      );
    });

    test('Series asks only for series', () async {
      final source = _FakeSource(lists: {
        (MediaKind.movie, HomeList.newReleases): _movies([1]),
        (MediaKind.series, HomeList.newReleases): _series([4]),
      });
      final feed = await HomeFeedController(source).load(HomeFilter.series);
      expect(_keys(feed.newReleases), <String>['series:4']);
      expect(feed.movieGenres, isEmpty);
      expect(
        source.requests.where(
          (request) => request.toString().contains('MediaKind.movie'),
        ),
        isEmpty,
      );
    });

    test('each filter gets its own service shelves', () async {
      final source = _FakeSource(services: {
        (MediaKind.movie, 8): _movies([1]),
        (MediaKind.series, 8): _series([1]),
        (MediaKind.movie, 337): _movies([2]),
        (MediaKind.series, 15): _series([3]),
      });
      final controller = HomeFeedController(source);

      final all = await controller.load(HomeFilter.all);
      expect(all.serviceShelves.first.service.providerId, 8);
      expect(
        _keys(all.serviceShelves.first.items),
        <String>['movie:1', 'series:1'],
      );

      final movies = await controller.load(HomeFilter.movies);
      expect(
        movies.serviceShelves.map((shelf) => shelf.service.providerId),
        <int>[8, 337],
        reason: 'shelves with nothing on them are left out',
      );

      final series = await controller.load(HomeFilter.series);
      expect(
        series.serviceShelves.map((shelf) => shelf.service.providerId),
        <int>[8, 15],
      );
    });
  });

  test('a failing list leaves the rest of Home standing', () async {
    final source = _FakeSource(
      lists: {
        (MediaKind.movie, HomeList.trendingToday): _movies([1, 2]),
        (MediaKind.series, HomeList.trendingToday): _series([1]),
        (MediaKind.movie, HomeList.topRated): _movies([9]),
      },
      failing: {
        (MediaKind.series, HomeList.trendingToday),
        (MediaKind.movie, HomeList.trendingWeek),
      },
      failServices: true,
    );
    final feed = await HomeFeedController(source).load(HomeFilter.all);
    expect(_keys(feed.topTen), <String>['movie:1', 'movie:2']);
    expect(feed.trending, isEmpty);
    expect(_keys(feed.topRated), <String>['movie:9']);
    expect(feed.serviceShelves, isEmpty);
    expect(feed.isEmpty, isFalse);
  });

  test('the Top 10 holds ten and leads the hero', () async {
    final source = _FakeSource(lists: {
      (MediaKind.movie, HomeList.trendingToday): _movies(
        List<int>.generate(15, (i) => i + 1),
      ),
      (MediaKind.movie, HomeList.popular): _movies([99]),
    });
    final feed = await HomeFeedController(source).load(HomeFilter.movies);
    expect(feed.topTen, hasLength(10));
    expect(titleKey(feed.hero!), 'movie:1');
  });

  test('the hero falls back when there is no Top 10', () async {
    final source = _FakeSource(lists: {
      (MediaKind.movie, HomeList.popular): _movies([99]),
    });
    final feed = await HomeFeedController(source).load(HomeFilter.movies);
    expect(titleKey(feed.hero!), 'movie:99');
  });

  test('no title shows in all three leading rows', () async {
    final source = _FakeSource(lists: {
      (MediaKind.movie, HomeList.trendingToday): _movies([1, 2, 3]),
      (MediaKind.movie, HomeList.trendingWeek): _movies([1, 2, 4]),
      (MediaKind.movie, HomeList.newReleases): _movies([1, 3, 4, 5]),
    });
    final feed = await HomeFeedController(source).load(HomeFilter.movies);
    expect(_keys(feed.topTen), <String>['movie:1', 'movie:2', 'movie:3']);
    expect(_keys(feed.trending), <String>['movie:1', 'movie:2', 'movie:4']);
    // 1 is already in two rows; 3 and 4 have only been in one.
    expect(
      _keys(feed.newReleases),
      <String>['movie:3', 'movie:4', 'movie:5'],
    );
  });

  group('limitRepeats', () {
    test('keeps a title in at most two rows, earliest first', () {
      final rows = limitRepeats(<List<MediaItem>>[
        _movies([1, 2]),
        _movies([1]),
        _movies([1, 2]),
        _movies([2, 3]),
      ]);
      expect(rows.map(_keys), <List<String>>[
        <String>['movie:1', 'movie:2'],
        <String>['movie:1'],
        <String>['movie:2'],
        <String>['movie:3'],
      ]);
    });

    test('an episode counts as its series', () {
      final episode = MediaItem(
        kind: MediaKind.series,
        id: 7,
        title: 'Series 7',
        overview: '',
        posterPath: null,
        backdropPath: null,
        rating: null,
        releaseDate: null,
        stableKey: 'recent-series:7:2:4',
      );
      final rows = limitRepeats(<List<MediaItem>>[
        <MediaItem>[episode],
        _series([7]),
        _series([7]),
      ]);
      expect(rows[2], isEmpty);
    });

    test('a movie and a series sharing an id are different titles', () {
      final rows = limitRepeats(
        <List<MediaItem>>[
          _movies([5]),
          _series([5]),
        ],
        max: 1,
      );
      expect(rows[1], hasLength(1));
    });
  });

  test('interleave skips repeats and items without an id', () {
    final items = interleave(<List<MediaItem>>[
      _movies([1, -1, 2]),
      _movies([1, 3]),
    ]);
    expect(_keys(items), <String>['movie:1', 'movie:3', 'movie:2']);
  });
}
