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

  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) {
    final language = settings.appLanguage;
    final isMovie = kind == MediaKind.movie;
    final String? url = switch (list) {
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
    if (url == null) return Future.value(const <MediaItem>[]);
    return catalog.loadRow(
      kind: kind,
      url: url,
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

/// Everything Home fetches for one filter.
///
/// Continue Watching and My List are not here: they are the viewer's own and
/// change while Home is open, so Home reads them live and passes them through
/// [limitRepeats] with these rows.
class HomeFeed {
  const HomeFeed({
    required this.filter,
    required this.topTen,
    required this.trending,
    required this.popular,
    required this.newReleases,
    required this.topRated,
    required this.upcoming,
    required this.serviceShelves,
    required this.movieGenres,
    required this.seriesGenres,
  });

  final HomeFilter filter;
  final List<MediaItem> topTen;
  final List<MediaItem> trending;
  final List<MediaItem> popular;
  final List<MediaItem> newReleases;
  final List<MediaItem> topRated;
  final List<MediaItem> upcoming;
  final List<ServiceShelf> serviceShelves;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;

  /// The day's #1, else the best-known title there is.
  MediaItem? get hero => topTen.isNotEmpty
      ? topTen.first
      : trending.isNotEmpty
          ? trending.first
          : popular.isNotEmpty
              ? popular.first
              : null;

  bool get isEmpty =>
      topTen.isEmpty &&
      trending.isEmpty &&
      popular.isEmpty &&
      newReleases.isEmpty &&
      topRated.isEmpty &&
      upcoming.isEmpty &&
      serviceShelves.every((shelf) => shelf.items.isEmpty);
}

/// Loads [HomeFeed]s. Every list fails on its own, so a missing one leaves
/// the rest of Home standing.
class HomeFeedController {
  const HomeFeedController(this.source);

  final HomeFeedSource source;

  /// The services given a row, by TMDB provider id, in order.
  static const movieShelfProviders = <int>[8, 9, 337, 384];
  static const seriesShelfProviders = <int>[8, 384, 9, 15];
  static const allShelfProviders = <int>[8, 384, 9, 337, 15];

  static const rowLength = 20;

  /// How many of the leading rows a title may appear in.
  static const maxLeadAppearances = 2;

  Future<HomeFeed> load(HomeFilter filter) async {
    final kinds = filter.kinds;

    Future<List<MediaItem>> mixed(HomeList list) async => interleave(
          await Future.wait(<Future<List<MediaItem>>>[
            for (final kind in kinds) _orEmpty(source.list(kind, list)),
          ]),
        );

    final providers = switch (filter) {
      HomeFilter.all => allShelfProviders,
      HomeFilter.movies => movieShelfProviders,
      HomeFilter.series => seriesShelfProviders,
    };
    final shelves = Future.wait(<Future<ServiceShelf?>>[
      for (final providerId in providers) _shelf(providerId, kinds),
    ]);
    final genres = Future.wait(<Future<List<Genres>>>[
      filter.shows(MediaKind.movie)
          ? _orEmpty(source.genres(MediaKind.movie))
          : Future.value(const <Genres>[]),
      filter.shows(MediaKind.series)
          ? _orEmpty(source.genres(MediaKind.series))
          : Future.value(const <Genres>[]),
    ]);
    final lists = await Future.wait(<Future<List<MediaItem>>>[
      mixed(HomeList.trendingToday),
      mixed(HomeList.trendingWeek),
      mixed(HomeList.popular),
      mixed(HomeList.newReleases),
      mixed(HomeList.topRated),
      mixed(HomeList.upcoming),
    ]);

    // Top 10, Trending and New releases lead the page; keep them from
    // showing the same few titles over and over.
    final lead = limitRepeats(<List<MediaItem>>[
      lists[0].take(10).toList(growable: false),
      lists[1],
      lists[3],
    ]);
    final loadedGenres = await genres;
    return HomeFeed(
      filter: filter,
      topTen: lead[0],
      trending: _row(lead[1]),
      popular: _row(lists[2]),
      newReleases: _row(lead[2]),
      topRated: _row(lists[4]),
      upcoming: _row(lists[5]),
      serviceShelves: (await shelves).whereType<ServiceShelf>().toList(
            growable: false,
          ),
      movieGenres: loadedGenres[0],
      seriesGenres: loadedGenres[1],
    );
  }

  Future<ServiceShelf?> _shelf(int providerId, List<MediaKind> kinds) async {
    final AppStreamingService? service =
        CatalogController.serviceFor(providerId);
    if (service == null) return null;
    final items = interleave(await Future.wait(<Future<List<MediaItem>>>[
      for (final kind in kinds) _orEmpty(source.service(kind, providerId)),
    ]));
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
