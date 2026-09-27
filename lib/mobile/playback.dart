import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog/details_controller.dart';
import '../catalog/episode_choice.dart';
import '../catalog/media_item.dart';
import '../catalog/up_next.dart';
import '../functions/function.dart';
import '../models/movie.dart';
import '../models/movie_stream_metadata.dart';
import '../models/recently_watched.dart';
import '../models/tv.dart';
import '../models/tv_stream_metadata.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/recently_watched_provider.dart';
import '../provider/settings_provider.dart';
import '../screens/movie/movie_detail.dart';
import '../screens/movie/movie_video_loader.dart';
import '../screens/tv/tv_detail.dart';
import '../screens/tv/tv_video_loader.dart';

/// Opening and playing titles from the phone's browse pages.
abstract final class MobilePlayback {
  /// Whether Play is offered at all; the remote config can turn it off.
  static bool canPlay(BuildContext context) =>
      context.read<AppDependencyProvider?>()?.displayWatchNowButton ?? true;

  /// Where [item] would pick up, from what the viewer has watched.
  static ResumePoint? resumeFor(BuildContext context, MediaItem item) {
    final recent = context.read<RecentProvider?>();
    if (recent == null) return null;
    return ResumePoint.forItem(
      item,
      movies: recent.movies,
      episodes: recent.episodes,
    );
  }

  static Future<void> openDetails(BuildContext context, MediaItem item) {
    final heroId = 'mobile-${item.stableId}';
    final Widget page = item.kind == MediaKind.movie
        ? MovieDetailPage(
            movie: item.movie ??
                Movie(
                  id: item.id,
                  title: item.title,
                  posterPath: item.posterPath,
                  backdropPath: item.backdropPath,
                  overview: item.overview,
                  releaseDate: item.releaseDate,
                  voteAverage: item.rating,
                ),
            heroId: heroId,
          )
        : TVDetailPage(
            tvSeries: item.series ??
                TV(
                  id: item.id,
                  name: item.title,
                  originalName: item.title,
                  posterPath: item.posterPath,
                  backdropPath: item.backdropPath,
                  overview: item.overview,
                  firstAirDate: item.releaseDate,
                  voteAverage: item.rating,
                ),
            heroId: heroId,
          );
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  /// Plays [item] from where the viewer is: a movie part way through, a
  /// series at its episode in progress or the next one, else from the start.
  /// Opens the details page instead when playing is turned off.
  static Future<void> play(BuildContext context, MediaItem item) async {
    if (!canPlay(context)) return openDetails(context, item);
    final resume = resumeFor(context, item);
    if (!await _online(context) || !context.mounted) return;
    if (item.kind == MediaKind.movie) {
      return _playMovie(context, item, elapsed: resume?.elapsed);
    }
    final recent = context.read<RecentProvider?>();
    final next = upNextFor(
      item,
      episodes: recent?.episodes ?? const <RecentEpisode>[],
      upNext: recent?.upNext ?? const <UpNext>[],
    );
    return _playSeries(context, item, next == null ? resume : null, next);
  }

  static Future<bool> _online(BuildContext context) async {
    if (await checkConnection()) return true;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('check_connection'))),
      );
    }
    return false;
  }

  static Future<void> _playMovie(
    BuildContext context,
    MediaItem item, {
    int? elapsed,
  }) {
    final movie = item.movie;
    debugPrint(
      '[MovieRecommendationsDebug][MOBILE_PLAYBACK_PLAY] '
      'movieId=${item.id} title=${item.title} '
      'recommendationsProvided=false (fetched by MovieVideoLoader)',
    );
    final metadata = MovieStreamMetadata(
      backdropPath: item.backdropPath,
      elapsed: elapsed,
      movieId: item.id,
      movieName: item.title,
      posterPath: item.posterPath,
      releaseYear: int.tryParse(item.year ?? '') ??
          item.recentMovie?.releaseYear ??
          0,
      isAdult: movie?.adult,
      releaseDate: item.releaseDate ?? movie?.releaseDate,
    );
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MovieVideoLoader(
          download: false,
          metadata: metadata,
        ),
      ),
    );
  }

  static Future<void> _playSeries(
    BuildContext context,
    MediaItem item,
    ResumePoint? resume,
    UpNext? upNext,
  ) async {
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    const controller = MediaDetailsController();
    try {
      final details = await controller.load(
        item: item,
        settings: settings,
        dependencies: dependencies,
      );
      final choice = await chooseEpisode(
        seasons: details.seasons,
        resume: resume,
        upNext: upNext,
        loadSeason: (season) => controller.loadSeason(
          seriesId: item.id,
          seasonNumber: season,
          settings: settings,
          dependencies: dependencies,
        ),
      );
      if (choice == null || !context.mounted) return;
      final episode = choice.episode;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TVVideoLoader(
            download: false,
            metadata: TVStreamMetadata(
              elapsed: choice.elapsed,
              episodeId: episode.episodeId,
              episodeName: episode.name,
              episodeNumber: episode.episodeNumber,
              posterPath: item.posterPath,
              backdropPath: episode.stillPath ?? item.backdropPath,
              seasonNumber: episode.seasonNumber,
              seriesName: item.title,
              tvId: item.id,
              airDate: episode.airDate,
              seasonEpisodes: choice.seasonEpisodes
                  .where((episode) => episode.episodeId != null)
                  .map(EpisodeMetadata.fromEpisodeList)
                  .toList(growable: false),
              allSeasons: details.seriesDetails?.seasons
                  ?.where((season) => season.seasonNumber != null)
                  .map(SeasonMetadata.fromSeason)
                  .toList(growable: false),
            ),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('episodes_load_failed'))),
        );
      }
    }
  }
}
