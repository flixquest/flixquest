import 'package:better_player_plus/better_player_plus.dart';
import 'package:flixquest/models/movie_stream_metadata.dart';
import 'package:flixquest/models/tv_stream_metadata.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../catalog/up_next.dart';
import '../../../constants/app_constants.dart';
import '../../../controllers/recently_watched_database_controller.dart';
import '../../../functions/function.dart';
import '../../../models/recently_watched.dart';
import '../../../provider/recently_watched_provider.dart';

class PlayerDataManagement {
  final RecentlyWatchedMoviesController recentlyWatchedMoviesController =
      RecentlyWatchedMoviesController();
  final RecentlyWatchedEpisodeController recentlyWatchedEpisodeController =
      RecentlyWatchedEpisodeController();

  Future<void> insertRecentMovieData({
    required BuildContext context,
    required BetterPlayerController betterPlayerController,
    required int duration,
    required MovieStreamMetadata movieMetadata,
  }) async {
    int elapsed = await betterPlayerController.videoPlayerController!.position
        .then((value) => value!.inSeconds);

    int remaining = duration - elapsed;
    String dt = DateTime.now().toString();

    var isBookmarked =
        await recentlyWatchedMoviesController.contain(movieMetadata.movieId!);
    dynamic prv;
    if (context.mounted) {
      prv = Provider.of<RecentProvider>(context, listen: false);
    }

    RecentMovie rMov = RecentMovie(
        dateTime: dt,
        elapsed: elapsed,
        id: movieMetadata.movieId!,
        posterPath: movieMetadata.posterPath!,
        releaseYear: movieMetadata.releaseYear!,
        remaining: remaining,
        title: movieMetadata.movieName,
        backdropPath: movieMetadata.backdropPath!);

    double percentage = (elapsed / duration) * 100;

    // If completion is > 85%, remove from recents (if exists) and don't add
    if (percentage > 85) {
      if (isBookmarked) {
        prv.deleteMovie(movieMetadata.movieId!);
      }
      // Don't add to recents if already completed
    } else {
      // If completion <= 85%, add or update
      if (!isBookmarked) {
        prv.addMovie(rMov);
      } else {
        prv.updateMovie(rMov, movieMetadata.movieId!);
      }
    }
  }

  Future<void> insertRecentEpisodeData({
    required BuildContext context,
    required BetterPlayerController betterPlayerController,
    required int duration,
    required TVStreamMetadata tvMetadata,
  }) async {
    int elapsed = await betterPlayerController.videoPlayerController!.position
        .then((value) => value!.inSeconds);

    int remaining = duration - elapsed;
    String dt = DateTime.now().toString();

    var isBookmarked =
        await recentlyWatchedEpisodeController.contain(tvMetadata.episodeId!);

    dynamic prv;
    if (context.mounted) {
      prv = Provider.of<RecentProvider>(context, listen: false);
    }

    String? backdropPath = tvMetadata.backdropPath;
    if (backdropPath == null) {
      for (final episode
          in tvMetadata.seasonEpisodes ?? const <EpisodeMetadata>[]) {
        if (episode.episodeId == tvMetadata.episodeId) {
          backdropPath = episode.stillPath;
          break;
        }
      }
    }

    RecentEpisode rEpisode = RecentEpisode(
        dateTime: dt,
        elapsed: elapsed,
        id: tvMetadata.episodeId!,
        posterPath: tvMetadata.posterPath!,
        backdropPath: backdropPath ?? tvMetadata.posterPath,
        remaining: remaining,
        seriesName: tvMetadata.seriesName!,
        episodeName: tvMetadata.episodeName!,
        episodeNum: tvMetadata.episodeNumber!,
        seasonNum: tvMetadata.seasonNumber!,
        seriesId: tvMetadata.tvId!);

    double percentage = (elapsed / duration) * 100;

    // If completion is > 85%, remove from recents (if exists) and don't add
    if (percentage > 85) {
      if (isBookmarked) {
        prv.deleteEpisode(tvMetadata.episodeId!, tvMetadata.episodeNumber!,
            tvMetadata.seasonNumber!);
      }
      // Keep the series in Continue Watching, one episode on; a series with
      // nothing more to watch leaves it.
      if (prv is RecentProvider) {
        final next = UpNext.after(tvMetadata);
        next == null
            ? await prv.clearUpNext(tvMetadata.tvId!)
            : await prv.recordUpNext(next);
      }
      // Don't add to recents if already completed
    } else {
      // If completion <= 85%, add or update
      if (!isBookmarked) {
        prv.addEpisode(rEpisode);
      } else {
        prv.updateEpisode(rEpisode, tvMetadata.episodeId!,
            tvMetadata.episodeNumber!, tvMetadata.seasonNumber!);
      }
    }
  }

  /// Handles saving progress and analytics before switching to a new episode/movie
  Future<void> handleContentSwitch({
    required BuildContext context,
    required MediaType mediaType,
    required BetterPlayerController betterPlayerController,
    required int duration,
    required int playbackDurationInSeconds,
    MovieStreamMetadata? movieMetadata,
    TVStreamMetadata? tvMetadata,
  }) async {
    // Save current playback progress
    if (mediaType == MediaType.movie) {
      await insertRecentMovieData(
        context: context,
        betterPlayerController: betterPlayerController,
        duration: duration,
        movieMetadata: movieMetadata!,
      );
    } else {
      await insertRecentEpisodeData(
        context: context,
        betterPlayerController: betterPlayerController,
        duration: duration,
        tvMetadata: tvMetadata!,
      );
    }

    // Send analytics for current viewing session
    updateAndLogTotalStreamingDuration(playbackDurationInSeconds);
  }
}
