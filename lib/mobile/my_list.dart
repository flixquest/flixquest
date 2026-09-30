import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog/home_feed_controller.dart';
import '../catalog/media_item.dart';
import '../models/movie.dart';
import '../models/tv.dart';
import '../provider/bookmark_provider.dart';

/// My List, which the app stores as bookmarks.
abstract final class MyList {
  /// Whether [item] is saved; rebuilds [context] when the list changes.
  static bool contains(BuildContext context, MediaItem item) {
    final bookmarks = context.watch<BookmarkProvider?>();
    if (bookmarks == null) return false;
    return item.kind == MediaKind.movie
        ? bookmarks.isMovieBookmarked(item.id)
        : bookmarks.isTVBookmarked(item.id);
  }

  /// The saved titles of the kinds [filter] shows, newest first.
  static List<MediaItem> items(
    BuildContext context, {
    HomeFilter filter = HomeFilter.all,
  }) {
    final bookmarks = context.watch<BookmarkProvider?>();
    if (bookmarks == null) return const <MediaItem>[];
    final entries = <(String, MediaItem)>[
      if (filter.shows(MediaKind.movie))
        for (final movie in bookmarks.movies)
          (movie.dateAdded ?? '', MediaItem.fromMovie(movie)),
      if (filter.shows(MediaKind.series))
        for (final series in bookmarks.tvShows)
          (series.dateAdded ?? '', MediaItem.fromSeries(series)),
    ];
    // Stored as DateTime.toString(), which sorts as text.
    entries.sort((a, b) => b.$1.compareTo(a.$1));
    return entries
        .map((entry) => entry.$2)
        .where((item) => item.id >= 0)
        .toList(growable: false);
  }

  /// Adds or removes [item] and returns whether it is saved afterwards.
  static Future<bool> toggle(BuildContext context, MediaItem item) async {
    final bookmarks = context.read<BookmarkProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = item.kind == MediaKind.movie
        ? bookmarks.isMovieBookmarked(item.id)
        : bookmarks.isTVBookmarked(item.id);
    if (item.kind == MediaKind.movie) {
      saved
          ? await bookmarks.removeMovie(item.id)
          : await bookmarks.addMovie(_movieOf(item));
    } else {
      saved
          ? await bookmarks.removeTV(item.id)
          : await bookmarks.addTV(_seriesOf(item));
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(tr(saved ? 'removed_from_my_list' : 'added_to_my_list')),
          duration: const Duration(seconds: 2),
        ),
      );
    return !saved;
  }

  static Movie _movieOf(MediaItem item) => (item.movie ??
      Movie(
        id: item.id,
        title: item.title,
        posterPath: item.posterPath,
        backdropPath: item.backdropPath,
        overview: item.overview,
        releaseDate: item.releaseDate,
        voteAverage: item.rating,
      ))
    ..dateAdded = DateTime.now().toString();

  static TV _seriesOf(MediaItem item) => (item.series ??
      TV(
        id: item.id,
        name: item.title,
        originalName: item.title,
        posterPath: item.posterPath,
        backdropPath: item.backdropPath,
        overview: item.overview,
        firstAirDate: item.releaseDate,
        voteAverage: item.rating,
      ))
    ..dateAdded = DateTime.now().toString();
}
