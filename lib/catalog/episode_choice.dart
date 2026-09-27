import '../models/tv.dart';
import '../models/recently_watched.dart';
import 'continue_watching.dart';
import 'details_controller.dart';
import 'media_item.dart';
import 'up_next.dart';

/// The episode Play starts for a series, with its season's episodes for the
/// player's episode list, and where to pick up if it was started.
class EpisodeChoice {
  const EpisodeChoice({
    required this.episode,
    required this.seasonEpisodes,
    this.elapsed,
  });

  final EpisodeList episode;
  final List<EpisodeList> seasonEpisodes;

  /// Seconds into [episode] to resume from, or null to play from the start.
  final int? elapsed;
}

/// What Play means for a series: [upNext] when given, else the episode in
/// progress, else the one after a finished episode (on into the next
/// season), else the very first.
///
/// [seasons] are in the order a series page offers them (specials last).
/// [loadSeason] fetches a season's episodes; its failure is passed on.
/// Returns null when there is nothing that can be played.
Future<EpisodeChoice?> chooseEpisode({
  required List<Seasons> seasons,
  required ResumePoint? resume,
  required Future<List<EpisodeList>> Function(int seasonNumber) loadSeason,
  UpNext? upNext,
  DateTime? now,
}) async {
  // The episode after one just finished, as Continue Watching offered it.
  if (upNext != null) {
    final season = await loadSeason(upNext.season);
    final next = season
        .where((episode) => episode.episodeNumber == upNext.episode)
        .firstOrNull;
    if (next != null && hasAired(next, now: now)) {
      return EpisodeChoice(episode: next, seasonEpisodes: season);
    }
  }
  final watched = resume?.episode;
  final watchedSeason = watched?.seasonNum;
  final watchedNumber = watched?.episodeNum;
  if (resume != null &&
      watched != null &&
      watchedSeason != null &&
      watchedNumber != null) {
    final season = await loadSeason(watchedSeason);
    if (!resume.finished) {
      final episode = season.firstWhere(
        (episode) => episode.episodeNumber == watchedNumber,
        orElse: () => EpisodeList(
          episodeId: watched.id,
          episodeNumber: watchedNumber,
          seasonNumber: watchedSeason,
          name: watched.episodeName,
        ),
      );
      return EpisodeChoice(
        episode: episode,
        seasonEpisodes: season,
        elapsed: resume.elapsed,
      );
    }
    final next = episodeAfter(season, watchedNumber);
    if (next != null && hasAired(next, now: now)) {
      return EpisodeChoice(episode: next, seasonEpisodes: season);
    }
    final nextSeason = seasons
        .map((season) => season.seasonNumber)
        .whereType<int>()
        .where((number) => number > watchedSeason)
        .firstOrNull;
    if (nextSeason != null) {
      final episodes = await loadSeason(nextSeason);
      if (episodes.isNotEmpty && hasAired(episodes.first, now: now)) {
        return EpisodeChoice(episode: episodes.first, seasonEpisodes: episodes);
      }
    }
  }
  final first = seasons.firstOrNull?.seasonNumber;
  if (first == null) return null;
  final episodes = await loadSeason(first);
  if (episodes.isEmpty) return null;
  return EpisodeChoice(episode: episodes.first, seasonEpisodes: episodes);
}

/// The next episode to start [item] from, if its latest is a finished
/// episode rather than one in progress: [item]'s own, from Continue
/// Watching, else the series' entry in [upNext], if newer than its latest
/// episode in [episodes].
UpNext? upNextFor(
  MediaItem item, {
  required List<RecentEpisode> episodes,
  required List<UpNext> upNext,
}) {
  if (item.kind != MediaKind.series) return null;
  final next = item.upNext ??
      upNext.where((entry) => entry.seriesId == item.id).firstOrNull;
  if (next == null) return null;
  final latest =
      episodes.where((episode) => episode.seriesId == item.id).firstOrNull;
  if (latest == null) return next;
  final played = lastWatched(latest.dateTime, latest.updatedAtUtc);
  return next.watchedAt.isAfter(played) ? next : null;
}
