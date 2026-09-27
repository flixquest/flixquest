import 'package:flutter/foundation.dart';

import '../models/recently_watched.dart';
import '../provider/recently_watched_provider.dart';
import 'details_controller.dart';
import 'home_feed_controller.dart';
import 'media_item.dart';
import 'up_next.dart';

/// The Continue Watching row: movies part way through and each series at its
/// latest episode, newest first, narrowed to [filter].
///
/// A series shows whichever is newer: its episode in progress, or the
/// episode after one it finished ([upNext]). The store keeps a row per
/// episode, newest first, so only a series' first row counts. Movies within
/// [ResumePoint.finishedWithin] of the end are left out; the player drops
/// most of those itself.
List<MediaItem> continueWatchingItems({
  required List<RecentMovie> movies,
  required List<RecentEpisode> episodes,
  List<UpNext> upNext = const <UpNext>[],
  HomeFilter filter = HomeFilter.all,
  int limit = 16,
}) {
  final entries = <(DateTime, int, MediaItem)>[];
  var order = 0;
  if (filter.shows(MediaKind.movie)) {
    for (final movie in movies) {
      if (movie.id == null) continue;
      final remaining = movie.remaining ?? 0;
      if ((movie.elapsed ?? 0) > 0 &&
          remaining <= ResumePoint.finishedWithin.inSeconds) {
        continue;
      }
      entries.add((
        lastWatched(movie.dateTime, movie.updatedAtUtc),
        order++,
        MediaItem.fromRecentMovie(movie),
      ));
    }
  }
  if (filter.shows(MediaKind.series)) {
    final latest = <int, (DateTime, MediaItem)>{};
    for (final episode in episodes) {
      final seriesId = episode.seriesId;
      if (seriesId == null || latest.containsKey(seriesId)) continue;
      latest[seriesId] = (
        lastWatched(episode.dateTime, episode.updatedAtUtc),
        MediaItem.fromRecentEpisode(episode),
      );
    }
    for (final next in upNext) {
      final current = latest[next.seriesId];
      if (current == null || next.watchedAt.isAfter(current.$1)) {
        latest[next.seriesId] = (next.watchedAt, MediaItem.fromUpNext(next));
      }
    }
    for (final entry in latest.values) {
      entries.add((entry.$1, order++, entry.$2));
    }
  }
  entries.sort((a, b) {
    final byTime = b.$1.compareTo(a.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  });
  return entries.map((entry) => entry.$3).take(limit).toList(growable: false);
}

/// When a recently watched row was last played: the local time the player
/// wrote, else the sync timestamp.
DateTime lastWatched(String? dateTime, int updatedAtUtc) =>
    DateTime.tryParse(dateTime ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(updatedAtUtc, isUtc: true).toLocal();

/// When [item], a Continue Watching entry, was last played.
DateTime? lastWatchedItem(MediaItem item) {
  if (item.recentMovie case final movie?) {
    return lastWatched(movie.dateTime, movie.updatedAtUtc);
  }
  if (item.recentEpisode case final episode?) {
    return lastWatched(episode.dateTime, episode.updatedAtUtc);
  }
  return item.upNext?.watchedAt;
}

/// The recently watched keys a Continue watching removal needs.
///
/// A movie row is keyed by its own id; an episode row needs the episode, season
/// and episode number together, because the store keeps one row per episode.
@immutable
class ContinueWatchingRemoval {
  const ContinueWatchingRemoval.movie(this.movieId)
      : episodeId = null,
        seasonNumber = null,
        episodeNumber = null;

  const ContinueWatchingRemoval.episode({
    required this.episodeId,
    required this.seasonNumber,
    required this.episodeNumber,
  }) : movieId = null;

  final int? movieId;
  final int? episodeId;
  final int? seasonNumber;
  final int? episodeNumber;

  /// The removal [item] needs, or null when it did not come from the recently
  /// watched store and so carries no keys to remove it by.
  static ContinueWatchingRemoval? forItem(MediaItem item) {
    final movie = item.recentMovie;
    if (movie != null) {
      final id = movie.id;
      return id == null ? null : ContinueWatchingRemoval.movie(id);
    }
    final episode = item.recentEpisode;
    if (episode == null) return null;
    final id = episode.id;
    final seasonNumber = episode.seasonNum;
    final episodeNumber = episode.episodeNum;
    if (id == null || seasonNumber == null || episodeNumber == null) {
      return null;
    }
    return ContinueWatchingRemoval.episode(
      episodeId: id,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }

  /// Tombstones the row so the removal reaches the user's other devices instead
  /// of being undone by their next sync.
  Future<void> apply(RecentProvider recent) {
    final movieId = this.movieId;
    if (movieId != null) return recent.deleteMovie(movieId);
    return recent.deleteEpisode(episodeId!, episodeNumber!, seasonNumber!);
  }

  @override
  bool operator ==(Object other) =>
      other is ContinueWatchingRemoval &&
      other.movieId == movieId &&
      other.episodeId == episodeId &&
      other.seasonNumber == seasonNumber &&
      other.episodeNumber == episodeNumber;

  @override
  int get hashCode =>
      Object.hash(movieId, episodeId, seasonNumber, episodeNumber);

  @override
  String toString() => movieId != null
      ? 'ContinueWatchingRemoval.movie($movieId)'
      : 'ContinueWatchingRemoval.episode($episodeId, '
          'S$seasonNumber E$episodeNumber)';
}

/// Takes [item] off Continue Watching and returns what puts it back.
///
/// A movie loses its row; a series loses every episode row it has and its
/// next episode, so an older episode doesn't surface in its place. Rows are
/// tombstoned, so the removal reaches the viewer's other devices. Undo
/// brings them back as they were, newer than the tombstones so it wins on
/// the next sync too, and in the same place in the row.
Future<Future<void> Function()> removeFromContinueWatching(
  RecentProvider recent,
  MediaItem item,
) async {
  if (item.kind == MediaKind.movie) {
    final rows = recent.movies
        .where((movie) => movie.id == item.id)
        .toList(growable: false);
    for (final row in rows) {
      await recent.deleteMovie(row.id!);
    }
    return () async {
      for (final row in rows) {
        await recent.addMovie(_restoredMovie(row));
      }
    };
  }
  final rows = recent.episodes
      .where(
        (episode) =>
            episode.seriesId == item.id &&
            episode.id != null &&
            episode.episodeNum != null &&
            episode.seasonNum != null,
      )
      .toList(growable: false);
  final next =
      recent.upNext.where((entry) => entry.seriesId == item.id).firstOrNull;
  for (final row in rows) {
    await recent.deleteEpisode(row.id!, row.episodeNum!, row.seasonNum!);
  }
  if (next != null) await recent.clearUpNext(item.id);
  return () async {
    for (final row in rows) {
      await recent.addEpisode(_restoredEpisode(row));
    }
    if (next != null) await recent.recordUpNext(next);
  };
}

RecentMovie _restoredMovie(RecentMovie row) => RecentMovie(
      backdropPath: row.backdropPath,
      dateTime: row.dateTime,
      elapsed: row.elapsed,
      id: row.id,
      posterPath: row.posterPath,
      releaseYear: row.releaseYear,
      remaining: row.remaining,
      title: row.title,
    );

RecentEpisode _restoredEpisode(RecentEpisode row) => RecentEpisode(
      dateTime: row.dateTime,
      elapsed: row.elapsed,
      episodeName: row.episodeName,
      episodeNum: row.episodeNum,
      id: row.id,
      posterPath: row.posterPath,
      remaining: row.remaining,
      seasonNum: row.seasonNum,
      seriesName: row.seriesName,
      seriesId: row.seriesId,
      backdropPath: row.backdropPath,
    );
