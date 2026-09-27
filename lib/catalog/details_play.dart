import '../models/credits.dart';
import '../models/movie.dart' show MovieDetails;
import '../models/recently_watched.dart';
import '../models/tv.dart' show CreatedBy, EpisodeList, TVDetails;
import '../models/videos.dart';
import 'details_controller.dart';
import 'episode_choice.dart';
import 'media_item.dart';
import 'up_next.dart';

/// What a details page's main button says.
enum DetailsPlayKind {
  /// "Play": a movie not started, or finished and starting over.
  play,

  /// "Resume": a movie part way through.
  resume,

  /// "Play S2:E5": a series' next or first episode.
  playEpisode,

  /// "Resume S2:E4": an episode part way through.
  resumeEpisode,

  /// "Next Episode": the latest episode is finished and what follows is not
  /// known yet (the up-next record is missing).
  nextEpisode,
}

/// The main button of a details page: what it says, and for a title part
/// way through, where it picks up.
class DetailsPlay {
  const DetailsPlay(this.kind, {this.episode, this.resume, this.upNext});

  final DetailsPlayKind kind;

  /// "S2:E4", for the kinds that name an episode.
  final String? episode;

  /// Set when resuming: the progress bar under the button, and the time left.
  final ResumePoint? resume;

  /// The episode after one just finished, which Play starts.
  final UpNext? upNext;

  bool get resuming =>
      kind == DetailsPlayKind.resume || kind == DetailsPlayKind.resumeEpisode;
}

/// The viewer's history, as the recently watched store keeps it (newest
/// first).
class WatchHistory {
  const WatchHistory({
    this.movies = const <RecentMovie>[],
    this.episodes = const <RecentEpisode>[],
    this.upNext = const <UpNext>[],
  });

  final List<RecentMovie> movies;
  final List<RecentEpisode> episodes;
  final List<UpNext> upNext;
}

/// The main button for [item], by the same rules as the TV details page and
/// Home's Play: a series' up-next episode when that's newer than anything in
/// progress, else the episode in progress, else the first episode of
/// [firstSeason] (the first a series page offers; specials come last).
DetailsPlay detailsPlayFor(
  MediaItem item,
  WatchHistory history, {
  int? firstSeason,
}) {
  final resume = ResumePoint.forItem(
    item,
    movies: history.movies,
    episodes: history.episodes,
  );
  if (item.kind == MediaKind.movie) {
    // A finished movie has no resume point, and plays from the start.
    return resume == null
        ? const DetailsPlay(DetailsPlayKind.play)
        : DetailsPlay(DetailsPlayKind.resume, resume: resume);
  }
  final next = upNextFor(
    item,
    episodes: history.episodes,
    upNext: history.upNext,
  );
  if (next != null) {
    return DetailsPlay(
      DetailsPlayKind.playEpisode,
      episode: next.label,
      upNext: next,
    );
  }
  if (resume != null) {
    return resume.finished
        ? const DetailsPlay(DetailsPlayKind.nextEpisode)
        : DetailsPlay(
            DetailsPlayKind.resumeEpisode,
            episode: resume.episodeLabel,
            resume: resume,
          );
  }
  return DetailsPlay(
    DetailsPlayKind.playEpisode,
    episode: 'S${firstSeason ?? 1}:E1',
  );
}

/// How far into an episode the viewer is, or null if it isn't started.
double? episodeProgress(
  List<RecentEpisode> episodes, {
  required int seriesId,
  required int season,
  required int episode,
}) {
  for (final entry in episodes) {
    if (entry.seriesId != seriesId ||
        entry.seasonNum != season ||
        entry.episodeNum != episode) {
      continue;
    }
    final point = ResumePoint(
      elapsed: entry.elapsed ?? 0,
      remaining: entry.remaining ?? 0,
    );
    return point.elapsed > 0 ? point.progress : null;
  }
  return null;
}

/// The first few names in the cast, billing order.
List<String> starring(Credits? credits, {int limit = 3}) {
  final cast = List<Cast>.of(credits?.cast ?? const <Cast>[])
    ..sort((a, b) => (a.order ?? 1 << 20).compareTo(b.order ?? 1 << 20));
  return _names(cast.map((person) => person.name)).take(limit).toList();
}

/// A movie's directors.
List<String> directors(Credits? credits) => _names(
      (credits?.crew ?? const <Crew>[])
          .where((person) => person.job == 'Director')
          .map((person) => person.name),
    ).toList();

/// A series' creators.
List<String> creators(TVDetails? details) =>
    _names((details?.createdBy ?? const <CreatedBy>[]).map((c) => c.name))
        .toList();

Iterable<String> _names(Iterable<String?> names) {
  final seen = <String>{};
  return names
      .whereType<String>()
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty && seen.add(name));
}

/// The video the Trailer button plays: a YouTube trailer, else a teaser,
/// else any YouTube video. Null when there is none.
Results? pickTrailer(Videos? videos) {
  final playable = (videos?.result ?? const <Results>[])
      .where((video) => (video.videoLink ?? '').isNotEmpty)
      .where((video) => video.site == null || video.site == 'YouTube')
      .toList();
  bool named(Results video, String word) =>
      (video.name ?? '').toLowerCase().contains(word);
  return playable.where((video) => video.type == 'Trailer').firstOrNull ??
      playable.where((video) => named(video, 'trailer')).firstOrNull ??
      playable.where((video) => video.type == 'Teaser').firstOrNull ??
      playable.firstOrNull;
}

/// More Like This: recommendations and similar titles taken in turn, each
/// once, never the title itself.
List<MediaItem> moreLikeThis(
  MediaItem item,
  List<MediaItem> recommendations,
  List<MediaItem> similar,
) {
  final seen = <String>{item.stableId};
  final merged = <MediaItem>[];
  for (var i = 0; i < recommendations.length || i < similar.length; i++) {
    for (final list in <List<MediaItem>>[recommendations, similar]) {
      if (i >= list.length) continue;
      final candidate = list[i];
      if (candidate.id >= 0 && seen.add(candidate.stableId)) {
        merged.add(candidate);
      }
    }
  }
  return merged;
}

/// Genres, languages and countries for Viewing Insights, as the player
/// records them with each watch.
typedef InsightsMetadata = ({
  List<String> genres,
  List<String> languages,
  List<String> countries,
});

/// [InsightsMetadata] from what the details say, else the original
/// language.
InsightsMetadata insightsMetadata({
  required List<String> genres,
  MovieDetails? movie,
  TVDetails? series,
  String? originalLanguage,
}) {
  // Each model has its own language and country types; only the names
  // matter here.
  final spoken = movie != null
      ? movie.spokenLanguages?.map((language) => language.englishName)
      : series?.spokenLanguages?.map((language) => language.englishName);
  final countries = movie != null
      ? movie.productionCountries?.map((country) => country.name)
      : series?.productionCountries?.map((country) => country.name);
  final languages = _names(spoken ?? const <String?>[]).toList();
  return (
    genres: _names(genres).toList(),
    languages: languages.isNotEmpty || spoken != null
        ? languages
        : <String>[
            if ((originalLanguage ?? '').trim().isNotEmpty)
              originalLanguage!.trim(),
          ],
    countries: _names(countries ?? const <String?>[]).toList(),
  );
}

/// What a season's page offers to play, and how far into it the viewer is.
class EpisodePlay {
  const EpisodePlay(this.episode, {this.resume});

  final EpisodeList episode;

  /// Set when the episode is part way through.
  final ResumePoint? resume;

  bool get resuming => resume != null;

  /// "S2:E4".
  String get label => 'S${episode.seasonNumber}:E${episode.episodeNumber}';
}

/// The episode a season's page offers: the one of [episodes] (a season, in
/// order) the viewer is part way through, else the one after the last they
/// finished, else the first. Only episodes that have aired count; null when
/// none has.
EpisodePlay? seasonPlayFor(
  List<EpisodeList> episodes,
  WatchHistory history, {
  required int seriesId,
  DateTime? now,
}) {
  final aired = episodes
      .where((episode) => episode.episodeNumber != null)
      .where((episode) => hasAired(episode, now: now))
      .toList(growable: false);
  if (aired.isEmpty) return null;
  final season = aired.first.seasonNumber;
  // Newest first: the latest episode of this season the viewer touched.
  for (final entry in history.episodes) {
    if (entry.seriesId != seriesId || entry.seasonNum != season) continue;
    final index = aired.indexWhere(
      (episode) => episode.episodeNumber == entry.episodeNum,
    );
    if (index < 0) continue;
    final point = ResumePoint(
      elapsed: entry.elapsed ?? 0,
      remaining: entry.remaining ?? 0,
      episode: entry,
    );
    if (point.elapsed > 0 && !point.finished) {
      return EpisodePlay(aired[index], resume: point);
    }
    return index + 1 < aired.length
        ? EpisodePlay(aired[index + 1])
        : EpisodePlay(aired.first);
  }
  return EpisodePlay(aired.first);
}

/// Where [episode] of [seriesId] picks up, or null when it isn't started or
/// is finished.
ResumePoint? episodeResume(
  List<RecentEpisode> episodes, {
  required int seriesId,
  required EpisodeList episode,
}) {
  for (final entry in episodes) {
    if (entry.seriesId != seriesId ||
        entry.seasonNum != episode.seasonNumber ||
        entry.episodeNum != episode.episodeNumber) {
      continue;
    }
    final point = ResumePoint(
      elapsed: entry.elapsed ?? 0,
      remaining: entry.remaining ?? 0,
      episode: entry,
    );
    return point.elapsed > 0 && !point.finished ? point : null;
  }
  return null;
}

/// The people in [credits] who did [jobs], each once.
List<String> crewWith(Credits? credits, Set<String> jobs) => _names(
      (credits?.crew ?? const <Crew>[])
          .where((person) => jobs.contains(person.job))
          .map((person) => person.name),
    ).toList();

/// An episode's guest stars, then the series' regulars, as one cast.
List<Cast> episodeCast(Credits? credits) {
  final seen = <int>{};
  return <Cast>[
    for (final guest in credits?.episodeGuestStars ?? const [])
      if (guest.id == null || seen.add(guest.id!))
        Cast(
          id: guest.id,
          name: guest.name,
          character: guest.character,
          profilePath: guest.profilePath,
          order: guest.order,
        ),
    for (final regular in credits?.cast ?? const <Cast>[])
      if (regular.id == null || seen.add(regular.id!)) regular,
  ];
}
