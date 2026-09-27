import 'dart:math';

import '../api/endpoints.dart';
import '../models/genres.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../widgets/common_widgets.dart' show AppStreamingService;
import 'catalog_controller.dart';
import 'media_item.dart';

/// What the phone's Home page shows: everything, or one kind.
enum HomeFilter {
  all,
  movies,
  series;

  List<MediaKind> get kinds => switch (this) {
        HomeFilter.all => const <MediaKind>[MediaKind.movie, MediaKind.series],
        HomeFilter.movies => const <MediaKind>[MediaKind.movie],
        HomeFilter.series => const <MediaKind>[MediaKind.series],
      };

  bool shows(MediaKind kind) => kinds.contains(kind);
}

/// The lists a Home row is built from.
enum HomeList {
  /// Today's most watched, for the Top 10 and the hero.
  trendingToday,
  trendingWeek,
  popular,
  topRated,

  /// Movies in cinemas, or series with episodes on the air.
  newReleases,

  /// Movies still to come. Series have none.
  upcoming,
}

/// Where Home's lists come from, so tests can feed it their own.
abstract class HomeFeedSource {
  Future<List<MediaItem>> list(MediaKind kind, HomeList list);

  /// Popular titles of [kind] from one [year] and genre, a page deep: the
  /// random picks the hero mixes with what's trending.
  Future<List<MediaItem>> discover(
    MediaKind kind, {
    required int page,
    required int year,
    required int genreId,
  });

  /// The first page of a genre, for a category row.
  Future<List<MediaItem>> genre(MediaKind kind, int genreId);

  Future<List<MediaItem>> service(MediaKind kind, int providerId);
  Future<List<Genres>> genres(MediaKind kind);
}

/// TMDB through the app's usual fetchers and proxy settings.
class CatalogHomeFeedSource implements HomeFeedSource {
  const CatalogHomeFeedSource({
    required this.settings,
    required this.dependencies,
    this.catalog = const CatalogController(),
  });

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;
  final CatalogController catalog;

  /// The TMDB list behind [list] for [kind], or null where there is none
  /// (upcoming series).
  String? urlFor(MediaKind kind, HomeList list) {
    final language = settings.appLanguage;
    final isMovie = kind == MediaKind.movie;
    return switch (list) {
      HomeList.trendingToday => isMovie
          ? Endpoints.trendingMoviesTodayUrl(language)
          : Endpoints.trendingTVTodayUrl(language),
      HomeList.trendingWeek => isMovie
          ? Endpoints.trendingMoviesUrl(language)
          : Endpoints.trendingTVUrl(language),
      HomeList.popular => isMovie
          ? Endpoints.popularMoviesUrl(language)
          : Endpoints.popularTVUrl(language),
      HomeList.topRated => isMovie
          ? Endpoints.topRatedUrl(language)
          : Endpoints.topRatedTVUrl(language),
      HomeList.newReleases => isMovie
          ? Endpoints.nowPlayingMoviesUrl(1, language)
          : Endpoints.onTheAirUrl(language),
      HomeList.upcoming =>
        isMovie ? Endpoints.upcomingMoviesUrl(language) : null,
    };
  }

  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) {
    final url = urlFor(kind, list);
    if (url == null) return Future.value(const <MediaItem>[]);
    return catalog.loadRow(
      kind: kind,
      url: url,
      settings: settings,
      dependencies: dependencies,
    );
  }

  @override
  Future<List<MediaItem>> discover(
    MediaKind kind, {
    required int page,
    required int year,
    required int genreId,
  }) {
    final language = settings.appLanguage;
    return catalog.loadRow(
      kind: kind,
      url: kind == MediaKind.movie
          ? Endpoints.randomDiscoverMoviesUrl(
              language,
              page: page,
              year: '$year',
              genreId: '$genreId',
            )
          : Endpoints.randomDiscoverTVUrl(
              language,
              page: page,
              year: '$year',
              genreId: '$genreId',
            ),
      settings: settings,
      dependencies: dependencies,
    );
  }

  @override
  Future<List<MediaItem>> genre(MediaKind kind, int genreId) {
    final language = settings.appLanguage;
    return catalog.loadRow(
      kind: kind,
      url: kind == MediaKind.movie
          ? Endpoints.getMoviesForGenre(genreId, 1, language)
          : Endpoints.getTVShowsForGenre(genreId, 1, language),
      settings: settings,
      dependencies: dependencies,
    );
  }

  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) =>
      catalog.loadServiceRow(
        kind: kind,
        providerId: providerId,
        settings: settings,
        dependencies: dependencies,
      );

  @override
  Future<List<Genres>> genres(MediaKind kind) => catalog.loadGenres(
        kind: kind,
        settings: settings,
        dependencies: dependencies,
      );
}

/// One kind's rows on Home. Movies and series never share a catalogue row,
/// so it's always clear which a poster is.
class KindRows {
  const KindRows({
    this.topTen = const <MediaItem>[],
    this.trending = const <MediaItem>[],
    this.popular = const <MediaItem>[],
    this.newReleases = const <MediaItem>[],
    this.topRated = const <MediaItem>[],
    this.upcoming = const <MediaItem>[],
    this.serviceShelves = const <ServiceShelf>[],
  });

  static const empty = KindRows();

  final List<MediaItem> topTen;
  final List<MediaItem> trending;
  final List<MediaItem> popular;

  /// Movies in cinemas, or series with episodes on the air.
  final List<MediaItem> newReleases;
  final List<MediaItem> topRated;

  /// Movies still to come; series have none.
  final List<MediaItem> upcoming;
  final List<ServiceShelf> serviceShelves;

  MediaItem? get first =>
      topTen.firstOrNull ?? trending.firstOrNull ?? popular.firstOrNull;

  bool get isEmpty =>
      topTen.isEmpty &&
      trending.isEmpty &&
      popular.isEmpty &&
      newReleases.isEmpty &&
      topRated.isEmpty &&
      upcoming.isEmpty &&
      serviceShelves.every((shelf) => shelf.items.isEmpty);
}

/// Everything Home fetches for one filter.
///
/// Continue Watching and My List are not here: they are the viewer's own and
/// change while Home is open, so Home reads them live and passes them through
/// [limitRepeats] with these rows.
class HomeFeed {
  const HomeFeed({
    required this.filter,
    this.spotlight = const <MediaItem>[],
    this.categories = const <HomeCategory>[],
    this.rows = const <MediaKind, KindRows>{},
    this.movieGenres = const <Genres>[],
    this.seriesGenres = const <Genres>[],
  });

  final HomeFilter filter;

  /// The hero's titles, in turn: what's trending this week alternating with
  /// random picks from a genre and year, as FlixQuest's hero always has.
  final List<MediaItem> spotlight;

  /// A few genres picked at random for this visit, each with its own layout.
  final List<HomeCategory> categories;

  /// Each kind the filter shows, with its own rows.
  final Map<MediaKind, KindRows> rows;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;

  KindRows of(MediaKind kind) => rows[kind] ?? KindRows.empty;

  /// The spotlight's first, else the best-known title there is.
  MediaItem? get hero =>
      spotlight.firstOrNull ??
      filter.kinds.map((kind) => of(kind).first).nonNulls.firstOrNull;

  bool get isEmpty => rows.values.every((kind) => kind.isEmpty);
}

/// How a category row lays out its titles, varied so a run of them doesn't
/// read as the same row repeated.
enum CategoryLayout {
  /// A wide feature card for the first title, posters for the rest.
  feature,

  /// Wide stills, then posters.
  stillsAndPosters,

  /// Two rows of posters.
  twoPosterRows,

  /// A row of wide stills.
  stills,

  /// A row of posters.
  posters,
}

/// One of Home's random genre rows.
class HomeCategory {
  const HomeCategory({
    required this.kind,
    required this.genre,
    required this.layout,
  });

  final MediaKind kind;
  final Genres genre;
  final CategoryLayout layout;
}

/// Loads [HomeFeed]s. Every list fails on its own, so a missing one leaves
/// the rest of Home standing.
class HomeFeedController {
  HomeFeedController(this.source, {Random? random, DateTime Function()? now})
      : _random = random ?? Random(),
        _now = now ?? DateTime.now;

  final HomeFeedSource source;
  final Random _random;
  final DateTime Function() _now;

  /// The genres the hero's random picks come from, as the old Movies and
  /// Series pages had them.
  static const movieSpotlightGenres = <int>[
    28, 12, 16, 35, 80, 99, 18, 10751, 14, 36, //
    27, 10402, 9648, 10749, 878, 10770, 53, 10752, 37,
  ];
  static const seriesSpotlightGenres = <int>[
    10759, 16, 35, 80, 99, 18, 10751, 10762, //
    9648, 10763, 10764, 10765, 10766, 10767, 10768, 37,
  ];

  /// The earliest year the hero's random picks come from.
  static const spotlightFirstYear = 1990;
  static const spotlightLength = 10;

  /// How many random genre rows a visit gets.
  static const categoryCount = 5;

  /// The services given a row, by TMDB provider id, in order.
  static const movieShelfProviders = <int>[8, 9, 337, 384];
  static const seriesShelfProviders = <int>[8, 384, 9, 15];

  /// Under All, each service's row is of the kind it's best known for, so
  /// the page doesn't carry two rows per service.
  static const allShelves = <(int, MediaKind)>[
    (8, MediaKind.series),
    (9, MediaKind.movie),
    (384, MediaKind.series),
    (337, MediaKind.movie),
  ];

  static const rowLength = 20;

  /// How many of the leading rows a title may appear in.
  static const maxLeadAppearances = 2;

  Future<HomeFeed> load(HomeFilter filter) async {
    final kinds = filter.kinds;
    final shelves = <(int, MediaKind)>[
      ...switch (filter) {
        HomeFilter.all => allShelves,
        HomeFilter.movies => <(int, MediaKind)>[
            for (final id in movieShelfProviders) (id, MediaKind.movie),
          ],
        HomeFilter.series => <(int, MediaKind)>[
            for (final id in seriesShelfProviders) (id, MediaKind.series),
          ],
      },
    ];
    final genres = Future.wait(<Future<List<Genres>>>[
      filter.shows(MediaKind.movie)
          ? _orEmpty(source.genres(MediaKind.movie))
          : Future.value(const <Genres>[]),
      filter.shows(MediaKind.series)
          ? _orEmpty(source.genres(MediaKind.series))
          : Future.value(const <Genres>[]),
    ]);
    final loaded = await Future.wait(<Future<(KindRows, List<MediaItem>)>>[
      for (final kind in kinds)
        _rowsFor(
          kind,
          shelves
              .where((shelf) => shelf.$2 == kind)
              .map((shelf) => shelf.$1)
              .toList(growable: false),
        ),
    ]);
    final loadedGenres = await genres;
    return HomeFeed(
      filter: filter,
      spotlight: interleave(<List<MediaItem>>[
        for (final kindRows in loaded) kindRows.$2,
      ]).take(spotlightLength).toList(growable: false),
      categories: _categories(loadedGenres[0], loadedGenres[1]),
      rows: <MediaKind, KindRows>{
        for (var i = 0; i < kinds.length; i++) kinds[i]: loaded[i].$1,
      },
      movieGenres: loadedGenres[0],
      seriesGenres: loadedGenres[1],
    );
  }

  /// [kind]'s rows, and its share of the hero's spotlight.
  Future<(KindRows, List<MediaItem>)> _rowsFor(
    MediaKind kind,
    List<int> shelfProviders,
  ) async {
    Future<List<MediaItem>> list(HomeList list) =>
        _orEmpty(source.list(kind, list));
    final shelves = Future.wait(<Future<ServiceShelf?>>[
      for (final providerId in shelfProviders) _shelf(providerId, kind),
    ]);
    final trendingWeek = list(HomeList.trendingWeek);
    final spotlight =
        trendingWeek.then((trending) => _spotlight(kind, trending));
    final lists = await Future.wait(<Future<List<MediaItem>>>[
      list(HomeList.trendingToday),
      trendingWeek,
      list(HomeList.popular),
      list(HomeList.newReleases),
      list(HomeList.topRated),
      list(HomeList.upcoming),
    ]);
    // Top 10, Trending and New releases lead the page; keep them from
    // showing the same few titles over and over.
    final lead = limitRepeats(<List<MediaItem>>[
      lists[0].take(10).toList(growable: false),
      lists[1],
      lists[3],
    ]);
    return (
      KindRows(
        topTen: lead[0],
        trending: _row(lead[1]),
        popular: _row(lists[2]),
        newReleases: _row(lead[2]),
        topRated: _row(lists[4]),
        upcoming: _row(lists[5]),
        serviceShelves: (await shelves).whereType<ServiceShelf>().toList(
              growable: false,
            ),
      ),
      await spotlight,
    );
  }

  /// FlixQuest's hero for [kind]: this week's trending in turn with random
  /// popular titles from a random genre, year (1990 on) and page (1 to 5),
  /// only titles with artwork, ten at most. Trending alone if the random
  /// pick finds nothing.
  Future<List<MediaItem>> _spotlight(
    MediaKind kind,
    List<MediaItem> trending,
  ) async {
    final genres =
        kind == MediaKind.movie ? movieSpotlightGenres : seriesSpotlightGenres;
    final thisYear = _now().year;
    final random = await _orEmpty(
      source.discover(
        kind,
        page: _random.nextInt(5) + 1,
        year: spotlightFirstYear +
            _random.nextInt(thisYear - spotlightFirstYear + 1),
        genreId: genres[_random.nextInt(genres.length)],
      ),
    );
    bool hasArt(MediaItem item) =>
        item.backdropPath != null || item.posterPath != null;
    final picks = random.where(hasArt).toList()..shuffle(_random);
    final combined = interleave(<List<MediaItem>>[
      trending.where(hasArt).toList(growable: false),
      picks,
    ]).take(spotlightLength).toList(growable: false);
    return combined.isNotEmpty ? combined : trending;
  }

  /// [categoryCount] genres at random from those on show, each given one of
  /// the layouts, shuffled so no two visits look alike.
  List<HomeCategory> _categories(
    List<Genres> movieGenres,
    List<Genres> seriesGenres,
  ) {
    final pool = <(MediaKind, Genres)>[
      for (final genre in movieGenres) (MediaKind.movie, genre),
      for (final genre in seriesGenres) (MediaKind.series, genre),
    ]..shuffle(_random);
    final layouts = List<CategoryLayout>.of(CategoryLayout.values)
      ..shuffle(_random);
    final picked = pool.take(categoryCount).toList(growable: false);
    return <HomeCategory>[
      for (var i = 0; i < picked.length; i++)
        HomeCategory(
          kind: picked[i].$1,
          genre: picked[i].$2,
          layout: layouts[i % layouts.length],
        ),
    ];
  }

  Future<ServiceShelf?> _shelf(int providerId, MediaKind kind) async {
    final AppStreamingService? service =
        CatalogController.serviceFor(providerId);
    if (service == null) return null;
    final items = interleave(<List<MediaItem>>[
      await _orEmpty(source.service(kind, providerId)),
    ]);
    if (items.isEmpty) return null;
    return ServiceShelf(service: service, items: _row(items));
  }

  static List<MediaItem> _row(List<MediaItem> items) =>
      items.take(rowLength).toList(growable: false);

  static Future<List<T>> _orEmpty<T>(Future<List<T>> future) async {
    try {
      return await future;
    } catch (_) {
      return <T>[];
    }
  }
}

/// A title's identity across rows: an episode in Continue Watching is the
/// same title as its series on a poster.
String titleKey(MediaItem item) => '${item.kind.name}:${item.id}';

/// [lists] taken in turn, one from each, skipping titles already taken and
/// items without an id.
List<MediaItem> interleave(List<List<MediaItem>> lists) {
  final seen = <String>{};
  final result = <MediaItem>[];
  final longest = lists.fold<int>(
    0,
    (length, list) => list.length > length ? list.length : length,
  );
  for (var i = 0; i < longest; i++) {
    for (final list in lists) {
      if (i >= list.length) continue;
      final item = list[i];
      if (item.id >= 0 && seen.add(titleKey(item))) result.add(item);
    }
  }
  return result;
}

/// [rows], in page order, with each title kept in at most [max] of them:
/// later appearances past the limit are dropped.
List<List<MediaItem>> limitRepeats(
  List<List<MediaItem>> rows, {
  int max = HomeFeedController.maxLeadAppearances,
}) {
  final counts = <String, int>{};
  final result = <List<MediaItem>>[];
  for (final row in rows) {
    final kept = <MediaItem>[];
    final inRow = <String>{};
    for (final item in row) {
      final key = titleKey(item);
      if (!inRow.add(key) || (counts[key] ?? 0) >= max) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      kept.add(item);
    }
    result.add(List<MediaItem>.unmodifiable(kept));
  }
  return result;
}
