import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog/details_controller.dart';
import '../catalog/media_item.dart';
import '../models/movie.dart';
import '../models/tv.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/recently_watched_provider.dart';
import '../screens/movie/movie_detail.dart';
import '../screens/tv/tv_detail.dart';

/// Opening and playing titles from the phone's browse pages.
abstract final class MobilePlayback {
  /// Whether Play is offered at all; the remote config can turn it off.
  static bool canPlay(BuildContext context) =>
      context.read<AppDependencyProvider?>()?.displayWatchNowButton ?? false;

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

  static Future<void> play(BuildContext context, MediaItem item,
      {bool Function()? onReady}) async {
    if (onReady?.call() == false) return;
    await openDetails(context, item);
  }
}
