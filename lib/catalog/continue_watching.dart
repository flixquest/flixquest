import 'package:flutter/foundation.dart';

import '../provider/recently_watched_provider.dart';
import 'media_item.dart';

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
