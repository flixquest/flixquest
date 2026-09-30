import '../api/endpoints.dart';
import '../controllers/bookmark_database_controller.dart';
import '../functions/network.dart';
import '../models/genres.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../widgets/common_widgets.dart'
    show AppStreamingService, appStreamingServices;
import 'media_item.dart';

/// A streaming service's most popular titles, for its row on a catalog page.
class ServiceShelf {
  const ServiceShelf({required this.service, required this.items});

  final AppStreamingService service;
  final List<MediaItem> items;
}

/// Everything a Movies or Series page shows, fetched together.
class CatalogData {
  const CatalogData({
    required this.kind,
    required this.topTen,
    required this.trending,
    required this.popular,
    required this.topRated,
    required this.fresh,
    required this.serviceShelves,
    required this.genres,
  });

  final MediaKind kind;

  /// Today's ten most watched.
  final List<MediaItem> topTen;
  final List<MediaItem> trending;
  final List<MediaItem> popular;
  final List<MediaItem> topRated;

  /// Upcoming movies, or series with new episodes on the air.
  final List<MediaItem> fresh;
  final List<ServiceShelf> serviceShelves;
  final List<Genres> genres;

  MediaItem? get featured => trending.isNotEmpty
      ? trending.first
      : popular.isNotEmpty
          ? popular.first
          : null;
}

/// A catalog opened from a shortcut tile, loaded a page at a time.
class MediaCollection {
  const MediaCollection({
    required this.id,
    required this.title,
    required this.kicker,
    required this.loadPage,
    this.logoAsset,
    this.adPlacement,
  });

  final String id;
  final String title;

  /// The hosted ad placement the collection's page reports, if it shows one.
  final String? adPlacement;

  /// What kind of collection it is, shown above the title.
  final String kicker;
  final String? logoAsset;

  /// Loads the 1-based [page]; an empty page means the collection has ended.
  final Future<List<MediaItem>> Function(int page) loadPage;
}

/// What Search shows before anything is typed.
class SearchSuggestions {
  const SearchSuggestions({
    required this.topSearches,
    required this.movieGenres,
    required this.seriesGenres,
  });

  static const empty = SearchSuggestions(
    topSearches: <MediaItem>[],
    movieGenres: <Genres>[],
    seriesGenres: <Genres>[],
  );

  /// Today's most watched, movies and series in turn.
  final List<MediaItem> topSearches;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;
}

class CatalogController {
  const CatalogController();

  /// Each part fails on its own, so a missing one leaves the rest standing.
  Future<SearchSuggestions> loadSearchSuggestions({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final language = settings.appLanguage;
    List<Genres> named(List<Genres> genres) => genres
        .where((genre) => genre.genreID != null && genre.genreName != null)
        .toList(growable: false);
    final results = await Future.wait<Object>(<Future<Object>>[
      _fetch(
        MediaKind.movie,
        Endpoints.trendingMoviesTodayUrl(language),
        settings,
        dependencies,
      ),
      _fetch(
        MediaKind.series,
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
    final movies = results[0] as List<MediaItem>;
    final series = results[1] as List<MediaItem>;
    return SearchSuggestions(
      topSearches: <MediaItem>[
        for (var i = 0; i < 5; i++) ...<MediaItem>[
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

  Future<CatalogData> loadCatalog({
    required MediaKind kind,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final language = settings.appLanguage;
    final isMovie = kind == MediaKind.movie;
    Future<List<MediaItem>> row(String url) =>
        _fetch(kind, url, settings, dependencies);

    final providers = (isMovie ? _movieShelfProviders : _seriesShelfProviders)
        .map(serviceFor)
        .whereType<AppStreamingService>()
        .toList(growable: false);
    final shelves = Future.wait(<Future<ServiceShelf>>[
      for (final service in providers)
        row(_serviceUrl(kind, service.providerId, 1, language)).then(
          (items) => ServiceShelf(service: service, items: items),
        ),
    ]);
    final genres = _orEmpty(fetchGenre(
      isMovie
          ? Endpoints.movieGenresUrl(language)
          : Endpoints.tvGenresUrl(language),
      settings.enableProxy,
      dependencies.tmdbProxy,
    ));
    final lists = await Future.wait(<Future<List<MediaItem>>>[
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
    return CatalogData(
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

  MediaCollection serviceCollection({
    required MediaKind kind,
    required AppStreamingService service,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) {
    return MediaCollection(
      id: '${kind.name}-service-${service.providerId}',
      title: service.name,
      kicker: kind == MediaKind.movie
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

  MediaCollection genreCollection({
    required MediaKind kind,
    required Genres genre,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) {
    final isMovie = kind == MediaKind.movie;
    return MediaCollection(
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

  /// Any TMDB list of [kind] at [url], a page at a time.
  MediaCollection listCollection({
    required String id,
    required MediaKind kind,
    required String url,
    required String title,
    required String kicker,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    String? adPlacement,
  }) {
    return MediaCollection(
      id: id,
      title: title,
      kicker: kicker,
      adPlacement: adPlacement,
      loadPage: (page) {
        final uri = Uri.parse(url);
        return _fetch(
          kind,
          uri.replace(
            queryParameters: <String, String>{
              ...uri.queryParameters,
              'page': '$page',
            },
          ).toString(),
          settings,
          dependencies,
          strict: true,
        );
      },
    );
  }

  /// One row from [url], empty if it fails.
  Future<List<MediaItem>> loadRow({
    required MediaKind kind,
    required String url,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    bool strict = false,
  }) =>
      _fetch(kind, url, settings, dependencies, strict: strict);

  /// A service's most popular titles of [kind], empty if it fails.
  Future<List<MediaItem>> loadServiceRow({
    required MediaKind kind,
    required int providerId,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) =>
      _fetch(
        kind,
        _serviceUrl(kind, providerId, 1, settings.appLanguage),
        settings,
        dependencies,
      );

  /// The named genres of [kind], empty if they fail.
  Future<List<Genres>> loadGenres({
    required MediaKind kind,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final genres = await _orEmpty(fetchGenre(
      kind == MediaKind.movie
          ? Endpoints.movieGenresUrl(settings.appLanguage)
          : Endpoints.tvGenresUrl(settings.appLanguage),
      settings.enableProxy,
      dependencies.tmdbProxy,
    ));
    return genres
        .where((genre) => genre.genreID != null && genre.genreName != null)
        .toList(growable: false);
  }

  static AppStreamingService? serviceFor(int providerId) {
    for (final service in appStreamingServices) {
      if (service.providerId == providerId) return service;
    }
    return null;
  }

  static String _serviceUrl(
    MediaKind kind,
    int providerId,
    int page,
    String language,
  ) =>
      kind == MediaKind.movie
          ? Endpoints.watchProvidersMovies(providerId, page, language)
          : Endpoints.watchProvidersTVShows(providerId, page, language);

  /// A page's rows fail on their own: a missing row leaves the rest of the
  /// page standing. A [strict] fetch lets the failure through, for a screen
  /// that has nothing else to show.
  Future<List<MediaItem>> _fetch(
    MediaKind kind,
    String url,
    SettingsProvider settings,
    AppDependencyProvider dependencies, {
    bool strict = false,
  }) async {
    final Future<List<MediaItem>> items = kind == MediaKind.movie
        ? fetchMovies(url, settings.enableProxy, dependencies.tmdbProxy)
            .then((movies) => movies.map(MediaItem.fromMovie).toList())
        : fetchTV(url, settings.enableProxy, dependencies.tmdbProxy)
            .then((series) => series.map(MediaItem.fromSeries).toList());
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

  Future<List<MediaItem>> search({
    required String query,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final results = await Future.wait<List<MediaItem>>([
      fetchMovies(
        Endpoints.movieSearchUrl(
          encodedQuery,
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then(
        (items) => items.map(MediaItem.fromMovie).toList(growable: false),
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
        (items) => items.map(MediaItem.fromSeries).toList(growable: false),
      ),
    ]);
    return _unique(results.expand((items) => items));
  }

  Future<List<MediaItem>> loadLibrary() async {
    final results = await Future.wait<List<MediaItem>>([
      MovieDatabaseController().getMovieList().then(
            (items) => items.map(MediaItem.fromMovie).toList(growable: false),
          ),
      TVDatabaseController().getTVList().then(
            (items) => items.map(MediaItem.fromSeries).toList(growable: false),
          ),
    ]);
    return results.expand((items) => items).toList(growable: false);
  }

  List<MediaItem> _unique(Iterable<MediaItem> items) {
    final found = <String>{};
    return items
        .where((item) => item.id >= 0 && found.add(item.stableId))
        .toList(growable: false);
  }
}
