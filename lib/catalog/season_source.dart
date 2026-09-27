import '../api/endpoints.dart';
import '../functions/network.dart';
import '../models/credits.dart';
import '../models/genres.dart';
import '../models/images.dart';
import '../models/tv.dart';
import '../models/videos.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';

/// What a season's or an episode's page shows. Each request fails on its
/// own, so one missing part never blanks the page.
abstract class SeasonSource {
  /// The series, for its seasons and what Viewing Insights records.
  Future<TVDetails> series(int seriesId);
  Future<List<Genres>> genres(int seriesId);
  Future<List<EpisodeList>> episodes(int seriesId, int season);
  Future<Credits> seasonCredits(int seriesId, int season);
  Future<Images> seasonImages(int seriesId, int season);
  Future<Videos> seasonVideos(int seriesId, int season);

  /// One episode in full, with its crew and guest stars.
  Future<EpisodeList> episode(int seriesId, int season, int episode);
  Future<Credits> episodeCredits(int seriesId, int season, int episode);
  Future<Images> episodeImages(int seriesId, int season, int episode);
}

/// TMDB through the app's fetchers, language and proxy.
class TmdbSeasonSource implements SeasonSource {
  const TmdbSeasonSource({required this.settings, required this.dependencies});

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;

  String get _language => settings.appLanguage;
  bool get _proxied => settings.enableProxy;
  String get _proxy => dependencies.tmdbProxy;

  @override
  Future<TVDetails> series(int seriesId) => fetchTVDetails(
        Endpoints.tvDetailsUrl(seriesId, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<List<Genres>> genres(int seriesId) => fetchGenre(
        Endpoints.tvDetailsUrl(seriesId, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<List<EpisodeList>> episodes(int seriesId, int season) async {
    final details = await fetchTVDetails(
      Endpoints.getSeasonDetails(seriesId, season, _language),
      _proxied,
      _proxy,
    );
    return details.episodes ?? const <EpisodeList>[];
  }

  @override
  Future<Credits> seasonCredits(int seriesId, int season) => fetchCredits(
        Endpoints.getFullTVSeasonCreditsUrl(seriesId, season, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<Images> seasonImages(int seriesId, int season) => fetchImages(
        Endpoints.getTVSeasonImagesUrl(seriesId, season),
        _proxied,
        _proxy,
      );

  @override
  Future<Videos> seasonVideos(int seriesId, int season) => fetchVideos(
        Endpoints.getTVSeasonVideosUrl(seriesId, season),
        _proxied,
        _proxy,
      );

  @override
  Future<EpisodeList> episode(int seriesId, int season, int episode) =>
      getEpisode(
        Endpoints.getEpisodeDetails(seriesId, season, episode, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<Credits> episodeCredits(int seriesId, int season, int episode) =>
      fetchCredits(
        Endpoints.getEpisodeCredits(seriesId, season, episode, _language),
        _proxied,
        _proxy,
      );

  @override
  Future<Images> episodeImages(int seriesId, int season, int episode) =>
      fetchImages(
        Endpoints.getTVEpisodeImagesUrl(seriesId, season, episode),
        _proxied,
        _proxy,
      );
}
