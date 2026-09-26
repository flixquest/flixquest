import '../../api/endpoints.dart';
import '../../controllers/bookmark_database_controller.dart';
import '../../functions/network.dart';
import '../../models/genres.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../widgets/common_widgets.dart'
    show AppStreamingService, appStreamingServices;
import '../models/tv_media_item.dart';

/// A streaming service's most popular titles, for its row on a catalog page.
class TvServiceShelf {
  const TvServiceShelf({required this.service, required this.items});

  final AppStreamingService service;
  final List<TvMediaItem> items;
}

/// Everything a Movies or Series page shows, fetched together.
class TvCatalogData {
  const TvCatalogData({
    required this.kind,
    required this.topTen,
    required this.trending,
    required this.popular,
    required this.topRated,
    required this.fresh,
    required this.serviceShelves,
    required this.genres,
  });

  final TvMediaKind kind;

  /// Today's ten most watched.
  final List<TvMediaItem> topTen;
  final List<TvMediaItem> trending;
  final List<TvMediaItem> popular;
  final List<TvMediaItem> topRated;

  /// Upcoming movies, or series with new episodes on the air.
  final List<TvMediaItem> fresh;
  final List<TvServiceShelf> serviceShelves;
  final List<Genres> genres;

  TvMediaItem? get featured => trending.isNotEmpty
      ? trending.first
      : popular.isNotEmpty
          ? popular.first
          : null;
}

/// A catalog opened from a shortcut tile, loaded a page at a time.
class TvCollection {
  const TvCollection({
    required this.id,
    required this.title,
    required this.kicker,
    required this.loadPage,
    this.logoAsset,
  });

  final String id;
  final String title;

  /// What kind of collection it is, shown above the title.
  final String kicker;
  final String? logoAsset;

  /// Loads the 1-based [page]; an empty page means the collection has ended.
  final Future<List<TvMediaItem>> Function(int page) loadPage;
}

/// What Search shows before anything is typed.
class TvSearchSuggestions {
  const TvSearchSuggestions({
    required this.topSearches,
    required this.movieGenres,
    required this.seriesGenres,
  });

  static const empty = TvSearchSuggestions(
    topSearches: <TvMediaItem>[],
    movieGenres: <Genres>[],
    seriesGenres: <Genres>[],
  );

  /// Today's most watched, movies and series in turn.
  final List<TvMediaItem> topSearches;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;
}

class TvCatalogController {
  const TvCatalogController();

  /// Each part fails on its own, so a missing one leaves the rest standing.
  Future<TvSearchSuggestions> loadSearchSuggestions({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final language = settings.appLanguage;
    List<Genres> named(List<Genres> genres) => genres
        .where((genre) => genre.genreID != null && genre.genreName != null)
        .toList(growable: false);
    final results = await Future.wait<Object>(<Future<Object>>[
      _fetch(
        TvMediaKind.movie,
        Endpoints.trendingMoviesTodayUrl(language),
        settings,
        dependencies,
      ),
      _fetch(
        TvMediaKind.series,
        Endpoints.trendingTVTodayUrl(language),
        settings,
        dependencies,
      ),
      _orEmpty(fetchGenre(
        Endpoints.movieGenresUrl(language),
        settings.enableProxy,
        dependencies.tmdbProxy,
      )),
      _orEmpty(fetchGenre(
        Endpoints.tvGenresUrl(language),
        settings.enableProxy,
        dependencies.tmdbProxy,
      )),
    ]);
    final movies = results[0] as List<TvMediaItem>;
    final series = results[1] as List<TvMediaItem>;
    return TvSearchSuggestions(
      topSearches: <TvMediaItem>[
        for (var i = 0; i < 5; i++) ...<TvMediaItem>[
          if (i < movies.length) movies[i],
          if (i < series.length) series[i],
        ],
      ].take(10).toList(growable: false),
      movieGenres: named(results[2] as List<Genres>),
      seriesGenres: named(results[3] as List<Genres>),
    );
  }

  /// The services given their own row on each page, by TMDB provider id.
  static const _movieShelfProviders = <int>[8, 9, 337, 384];
  static const _seriesShelfProviders = <int>[8, 384, 9, 15];

  static const _rowLength = 20;

  Future<TvCatalogData> loadCatalog({
    required TvMediaKind kind,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final language = settings.appLanguage;
    final isMovie = kind == TvMediaKind.movie;
    Future<List<TvMediaItem>> row(String url) =>
        _fetch(kind, url, settings, dependencies);

    final providers = (isMovie ? _movieShelfProviders : _seriesShelfProviders)
        .map(_serviceFor)
        .whereType<AppStreamingService>()
        .toList(growable: false);
    final shelves = Future.wait(<Future<TvServiceShelf>>[
      for (final service in providers)
        row(_serviceUrl(kind, service.providerId, 1, language)).then(
          (items) => TvServiceShelf(service: service, items: items),
        ),
    ]);
    final genres = _orEmpty(fetchGenre(
      isMovie
          ? Endpoints.movieGenresUrl(language)
          : Endpoints.tvGenresUrl(language),
      settings.enableProxy,
      dependencies.tmdbProxy,
    ));
    final lists = await Future.wait(<Future<List<TvMediaItem>>>[
      row(isMovie
          ? Endpoints.trendingMoviesUrl(language)
          : Endpoints.trendingTVUrl(language)),
      row(isMovie
          ? Endpoints.popularMoviesUrl(language)
          : Endpoints.popularTVUrl(language)),
      row(isMovie
          ? Endpoints.topRatedUrl(language)
          : Endpoints.topRatedTVUrl(language)),
      row(isMovie
          ? Endpoints.upcomingMoviesUrl(language)
          : Endpoints.onTheAirUrl(language)),
      row(isMovie
          ? Endpoints.trendingMoviesTodayUrl(language)
          : Endpoints.trendingTVTodayUrl(language)),
    ]);
    return TvCatalogData(
      kind: kind,
      topTen: lists[4].take(10).toList(growable: false),
      trending: lists[0],
      popular: lists[1],
      topRated: lists[2],
      fresh: lists[3],
      serviceShelves: await shelves,
      genres: (await genres)
          .where((genre) => genre.genreID != null && genre.genreName != null)
          .toList(growable: false),
    );
  }

  TvCollection serviceCollection({
    required TvMediaKind kind,
    required AppStreamingService service,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) {
    return TvCollection(
      id: '${kind.name}-service-${service.providerId}',
      title: service.name,
      kicker: kind == TvMediaKind.movie
          ? 'MOVIES ON THIS SERVICE'
          : 'SERIES ON THIS SERVICE',
      logoAsset: service.imagePath,
      loadPage: (page) => _fetch(
        kind,
        _serviceUrl(kind, service.providerId, page, settings.appLanguage),
        settings,
        dependencies,
        strict: true,
      ),
    );
  }

  TvCollection genreCollection({
    required TvMediaKind kind,
    required Genres genre,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) {
    final isMovie = kind == TvMediaKind.movie;
    return TvCollection(
      id: '${kind.name}-genre-${genre.genreID}',
      title: genre.genreName!,
      kicker: isMovie ? 'MOVIE GENRE' : 'SERIES GENRE',
      loadPage: (page) => _fetch(
        kind,
        isMovie
            ? Endpoints.getMoviesForGenre(
                genre.genreID!, page, settings.appLanguage)
            : Endpoints.getTVShowsForGenre(
                genre.genreID!, page, settings.appLanguage),
        settings,
        dependencies,
        strict: true,
      ),
    );
  }

  static AppStreamingService? _serviceFor(int providerId) {
    for (final service in appStreamingServices) {
      if (service.providerId == providerId) return service;
    }
    return null;
  }

  static String _serviceUrl(
    TvMediaKind kind,
    int providerId,
    int page,
    String language,
  ) =>
      kind == TvMediaKind.movie
          ? Endpoints.watchProvidersMovies(providerId, page, language)
          : Endpoints.watchProvidersTVShows(providerId, page, language);

  /// A page's rows fail on their own: a missing row leaves the rest of the
  /// page standing. A [strict] fetch lets the failure through, for a screen
  /// that has nothing else to show.
  Future<List<TvMediaItem>> _fetch(
    TvMediaKind kind,
    String url,
    SettingsProvider settings,
    AppDependencyProvider dependencies, {
    bool strict = false,
  }) async {
    final Future<List<TvMediaItem>> items = kind == TvMediaKind.movie
        ? fetchMovies(url, settings.enableProxy, dependencies.tmdbProxy)
            .then((movies) => movies.map(TvMediaItem.fromMovie).toList())
        : fetchTV(url, settings.enableProxy, dependencies.tmdbProxy)
            .then((series) => series.map(TvMediaItem.fromSeries).toList());
    final loaded = strict ? await items : await _orEmpty(items);
    return _unique(loaded).take(strict ? loaded.length : _rowLength).toList(
          growable: false,
        );
  }

  static Future<List<T>> _orEmpty<T>(Future<List<T>> future) async {
    try {
      return await future;
    } catch (_) {
      return <T>[];
    }
  }

  Future<List<TvMediaItem>> search({
    required String query,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final results = await Future.wait<List<TvMediaItem>>([
      fetchMovies(
        Endpoints.movieSearchUrl(
          encodedQuery,
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then(
        (items) => items.map(TvMediaItem.fromMovie).toList(growable: false),
      ),
      fetchTV(
        Endpoints.tvSearchUrl(
          encodedQuery,
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then(
        (items) => items.map(TvMediaItem.fromSeries).toList(growable: false),
      ),
    ]);
    return _unique(results.expand((items) => items));
  }

  Future<List<TvMediaItem>> loadLibrary() async {
    final results = await Future.wait<List<TvMediaItem>>([
      MovieDatabaseController().getMovieList().then(
            (items) => items.map(TvMediaItem.fromMovie).toList(growable: false),
          ),
      TVDatabaseController().getTVList().then(
            (items) =>
                items.map(TvMediaItem.fromSeries).toList(growable: false),
          ),
    ]);
    return results.expand((items) => items).toList(growable: false);
  }

  List<TvMediaItem> _unique(Iterable<TvMediaItem> items) {
    final found = <String>{};
    return items
        .where((item) => item.id >= 0 && found.add(item.stableId))
        .toList(growable: false);
  }
}
