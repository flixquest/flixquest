import '../api/endpoints.dart';
import '../functions/network.dart';
import '../models/credits.dart';
import '../models/genres.dart';
import '../models/images.dart';
import '../models/movie.dart';
import '../models/tv.dart';
import '../models/videos.dart';
import '../models/watch_providers.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import 'media_item.dart';

/// Everything a details page shows about one title. Each request fails on
/// its own, so one missing part never blanks the page.
abstract class TitleDetailsSource {
  Future<MovieDetails> movie(int id);
  Future<TVDetails> series(int id);
  Future<List<Genres>> genres(MediaItem item);
  Future<Credits> credits(MediaItem item);
  Future<Videos> videos(MediaItem item);
  Future<Images> images(MediaItem item);
  Future<ExternalLinks> links(MediaItem item);

  /// The collection a movie belongs to, or null when it has none.
  Future<BelongsToCollection?> collection(int movieId);
  Future<List<MediaItem>> recommendations(MediaItem item, int page);
  Future<List<MediaItem>> similar(MediaItem item, int page);
  Future<List<EpisodeList>> season(int seriesId, int seasonNumber);
  Future<WatchProviders> watchProviders(MediaItem item);
}

/// TMDB through the app's fetchers, language, proxy and adult setting.
class TmdbTitleDetailsSource implements TitleDetailsSource {
  const TmdbTitleDetailsSource({
    required this.settings,
    required this.dependencies,
  });

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;

  String get _language => settings.appLanguage;
  bool get _proxied => settings.enableProxy;
  String get _proxy => dependencies.tmdbProxy;

  bool _isMovie(MediaItem item) => item.kind == MediaKind.movie;

  String _detailsUrl(MediaItem item) => _isMovie(item)
      ? Endpoints.movieDetailsUrl(item.id, _language)
      : Endpoints.tvDetailsUrl(item.id, _language);

  @override
  Future<MovieDetails> movie(int id) => fetchMovieDetails(
        Endpoints.movieDetailsUrl(id, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<TVDetails> series(int id) => fetchTVDetails(
        Endpoints.tvDetailsUrl(id, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<List<Genres>> genres(MediaItem item) =>
      fetchGenre(_detailsUrl(item), _proxied, _proxy);

  @override
  Future<Credits> credits(MediaItem item) => fetchCredits(
        _isMovie(item)
            ? Endpoints.getCreditsUrl(item.id, _language)
            : Endpoints.getTVCreditsUrl(item.id, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<Videos> videos(MediaItem item) => fetchVideos(
        _isMovie(item)
            ? Endpoints.getVideos(item.id)
            : Endpoints.getTVVideos(item.id),
        _proxied,
        _proxy,
      );

  @override
  Future<Images> images(MediaItem item) => fetchImages(
        _isMovie(item)
            ? Endpoints.getImages(item.id)
            : Endpoints.getTVImages(item.id),
        _proxied,
        _proxy,
      );

  @override
  Future<ExternalLinks> links(MediaItem item) => fetchSocialLinks(
        _isMovie(item)
            ? Endpoints.getExternalLinksForMovie(item.id, _language)
            : Endpoints.getExternalLinksForTV(item.id, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<BelongsToCollection?> collection(int movieId) async {
    final value = await fetchBelongsToCollection(
      Endpoints.movieDetailsUrl(movieId, _language),
      _proxied,
      _proxy,
    ) as BelongsToCollection;
    return value.id == null ? null : value;
  }

  @override
  Future<List<MediaItem>> recommendations(MediaItem item, int page) => _related(
        item,
        _isMovie(item)
            ? Endpoints.getMovieRecommendations(item.id, page, _language)
            : Endpoints.getTVRecommendations(item.id, page, _language),
      );

  @override
  Future<List<MediaItem>> similar(MediaItem item, int page) => _related(
        item,
        _isMovie(item)
            ? Endpoints.getSimilarMovies(item.id, page, _language)
            : Endpoints.getSimilarTV(item.id, page, _language),
      );

  Future<List<MediaItem>> _related(MediaItem item, String url) async {
    final request = '$url&include_adult=${settings.isAdult}';
    if (_isMovie(item)) {
      final movies = await fetchMovies(request, _proxied, _proxy);
      return movies.map(MediaItem.fromMovie).toList(growable: false);
    }
    final series = await fetchTV(request, _proxied, _proxy);
    return series.map(MediaItem.fromSeries).toList(growable: false);
  }

  @override
  Future<List<EpisodeList>> season(int seriesId, int seasonNumber) async {
    final details = await fetchTVDetails(
      Endpoints.getSeasonDetails(seriesId, seasonNumber, _language),
      _proxied,
      _proxy,
    );
    return details.episodes ?? const <EpisodeList>[];
  }

  @override
  Future<WatchProviders> watchProviders(MediaItem item) => fetchWatchProviders(
        _isMovie(item)
            ? Endpoints.getMovieWatchProviders(item.id, _language)
            : Endpoints.getTVWatchProviders(item.id, _language),
        settings.defaultCountry,
        _proxied,
        _proxy,
      );
}
