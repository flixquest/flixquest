import '../../api/endpoints.dart';
import '../../controllers/bookmark_database_controller.dart';
import '../../functions/network.dart';
import '../../models/movie.dart';
import '../../models/recently_watched.dart';
import '../../models/tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../models/tv_media_item.dart';

class TvMediaDetailsData {
  const TvMediaDetailsData({
    required this.item,
    required this.recommendations,
    this.movieDetails,
    this.seriesDetails,
  });

  final TvMediaItem item;
  final MovieDetails? movieDetails;
  final TVDetails? seriesDetails;
  final List<TvMediaItem> recommendations;

  String? get tagline => movieDetails?.tagline ?? seriesDetails?.tagline;
  String? get status => movieDetails?.status ?? seriesDetails?.status;

  /// The hero's facts line: year, rating, and how long it runs.
  List<String> get facts => <String>[
        if (item.year case final year?) year,
        if (item.rating case final rating? when rating > 0)
          '★ ${rating.toStringAsFixed(1)}',
        if (movieDetails?.runtime case final runtime? when runtime > 0)
          formatRuntime(Duration(minutes: runtime)),
        if (seriesDetails?.numberOfSeasons case final seasons? when seasons > 0)
          '$seasons Season${seasons == 1 ? '' : 's'}',
      ];

  /// The seasons worth offering, specials last rather than first.
  List<Seasons> get seasons {
    final all = (seriesDetails?.seasons ?? const <Seasons>[])
        .where((season) => season.seasonNumber != null)
        .toList();
    return <Seasons>[
      ...all.where((season) => season.seasonNumber! > 0),
      ...all.where((season) => season.seasonNumber! <= 0),
    ];
  }
}

/// "2h 14m", "48m", "1h".
String formatRuntime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${duration.inMinutes.clamp(1, 59)}m';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

/// Where Play picks up for a title the user has started: a movie part way
/// through, or the series episode watched last.
class TvResumePoint {
  const TvResumePoint({
    required this.elapsed,
    required this.remaining,
    this.movie,
    this.episode,
  });

  /// Seconds watched and left, as the player saves them.
  final int elapsed;
  final int remaining;
  final RecentMovie? movie;
  final RecentEpisode? episode;

  /// Under this much left counts as watched: a movie starts over, and a
  /// series moves on to the next episode.
  static const finishedWithin = Duration(minutes: 3);

  bool get finished => remaining <= finishedWithin.inSeconds;

  double get progress => elapsed + remaining <= 0
      ? 0
      : (elapsed / (elapsed + remaining)).clamp(0, 1);

  /// "S2:E4", for an episode.
  String? get episodeLabel {
    final season = episode?.seasonNum;
    final number = episode?.episodeNum;
    return season == null || number == null ? null : 'S$season:E$number';
  }

  String get timeLeft => '${formatRuntime(Duration(seconds: remaining))} left';

  /// The latest progress for [item], or null when it has none worth resuming.
  ///
  /// Both lists come newest first, as the recently watched store keeps them.
  static TvResumePoint? forItem(
    TvMediaItem item, {
    required List<RecentMovie> movies,
    required List<RecentEpisode> episodes,
  }) {
    if (item.kind == TvMediaKind.movie) {
      for (final movie in movies) {
        if (movie.id != item.id) continue;
        final point = TvResumePoint(
          elapsed: movie.elapsed ?? 0,
          remaining: movie.remaining ?? 0,
          movie: movie,
        );
        // A finished movie just plays again from the start.
        return point.elapsed > 0 && !point.finished ? point : null;
      }
      return null;
    }
    for (final episode in episodes) {
      if (episode.seriesId != item.id ||
          episode.seasonNum == null ||
          episode.episodeNum == null) {
        continue;
      }
      return TvResumePoint(
        elapsed: episode.elapsed ?? 0,
        remaining: episode.remaining ?? 0,
        episode: episode,
      );
    }
    return null;
  }
}

/// The season a series page opens on: the one being watched, else the first
/// regular season.
int? initialSeasonNumber(List<Seasons> seasons, TvResumePoint? resume) {
  final watching = resume?.episode?.seasonNum;
  if (watching != null &&
      seasons.any((season) => season.seasonNumber == watching)) {
    return watching;
  }
  return seasons.firstOrNull?.seasonNumber;
}

/// The episode after [current] in [seasonEpisodes], if the season has one.
EpisodeList? episodeAfter(List<EpisodeList> seasonEpisodes, int current) {
  for (final episode in seasonEpisodes) {
    if ((episode.episodeNumber ?? 0) == current + 1) return episode;
  }
  return null;
}

/// Whether [episode] has aired by [now]; one without a date is assumed to
/// have.
bool hasAired(EpisodeList episode, {DateTime? now}) {
  final aired = DateTime.tryParse(episode.airDate ?? '');
  return aired == null || !aired.isAfter(now ?? DateTime.now());
}

class TvMediaDetailsController {
  const TvMediaDetailsController();

  Future<TvMediaDetailsData> load({
    required TvMediaItem item,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    if (item.kind == TvMediaKind.movie) {
      final results = await Future.wait<Object>([
        fetchMovieDetails(
          Endpoints.movieDetailsUrl(item.id, settings.appLanguage),
          settings.enableProxy,
          dependencies.tmdbProxy,
        ),
        fetchMovies(
          Endpoints.getMovieRecommendations(
            item.id,
            1,
            settings.appLanguage,
          ),
          settings.enableProxy,
          dependencies.tmdbProxy,
        ),
      ]);
      return TvMediaDetailsData(
        item: item,
        movieDetails: results[0] as MovieDetails,
        recommendations: (results[1] as List<Movie>)
            .map(TvMediaItem.fromMovie)
            .toList(growable: false),
      );
    }

    final results = await Future.wait<Object>([
      fetchTVDetails(
        Endpoints.tvDetailsUrl(item.id, settings.appLanguage),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ),
      fetchTV(
        Endpoints.getTVRecommendations(item.id, 1, settings.appLanguage),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ),
    ]);
    return TvMediaDetailsData(
      item: item,
      seriesDetails: results[0] as TVDetails,
      recommendations: (results[1] as List<TV>)
          .map(TvMediaItem.fromSeries)
          .toList(growable: false),
    );
  }

  Future<List<EpisodeList>> loadSeason({
    required int seriesId,
    required int seasonNumber,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final details = await fetchTVDetails(
      Endpoints.getSeasonDetails(
        seriesId,
        seasonNumber,
        settings.appLanguage,
      ),
      settings.enableProxy,
      dependencies.tmdbProxy,
    );
    return details.episodes ?? const <EpisodeList>[];
  }

  Future<bool> isBookmarked(TvMediaItem item) {
    return item.kind == TvMediaKind.movie
        ? MovieDatabaseController().contain(item.id)
        : TVDatabaseController().contain(item.id);
  }

  Future<bool> toggleBookmark(TvMediaItem item, bool isBookmarked) async {
    if (item.kind == TvMediaKind.movie) {
      final database = MovieDatabaseController();
      if (isBookmarked) {
        await database.deleteMovie(item.id);
        return false;
      }
      final movie = item.movie;
      if (movie == null) return false;
      await database.insertMovie(movie);
      return true;
    }

    final database = TVDatabaseController();
    if (isBookmarked) {
      await database.deleteTV(item.id);
      return false;
    }
    final series = item.series;
    if (series == null) return false;
    await database.insertTV(series);
    return true;
  }
}
