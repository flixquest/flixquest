import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tv_stream_metadata.dart';

/// The episode after the one a viewer just finished, so Continue Watching
/// can offer it.
///
/// The player drops an episode from recently watched once it's nearly done,
/// which on its own would drop the series from Continue Watching too. This
/// keeps the series there, one episode on.
class UpNext {
  const UpNext({
    required this.seriesId,
    required this.seriesName,
    required this.finishedSeason,
    required this.finishedEpisode,
    required this.season,
    required this.episode,
    required this.watchedAt,
    this.episodeId,
    this.episodeName,
    this.posterPath,
    this.backdropPath,
  });

  final int seriesId;
  final String seriesName;
  final int finishedSeason;
  final int finishedEpisode;

  /// The episode to play next.
  final int season;
  final int episode;

  /// Known when it's in the same season as the one finished.
  final int? episodeId;
  final String? episodeName;
  final String? posterPath;

  /// The next episode's still, else the series' backdrop.
  final String? backdropPath;

  /// When the previous episode was finished.
  final DateTime watchedAt;

  /// "S2:E5".
  String get label => 'S$season:E$episode';

  Map<String, Object?> toJson() => <String, Object?>{
        'seriesId': seriesId,
        'seriesName': seriesName,
        'finishedSeason': finishedSeason,
        'finishedEpisode': finishedEpisode,
        'season': season,
        'episode': episode,
        'episodeId': episodeId,
        'episodeName': episodeName,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'watchedAt': watchedAt.toIso8601String(),
      };

  static UpNext? fromJson(Object? json) {
    if (json is! Map) return null;
    final seriesId = json['seriesId'];
    final season = json['season'];
    final episode = json['episode'];
    final watchedAt = DateTime.tryParse('${json['watchedAt']}');
    if (seriesId is! int ||
        season is! int ||
        episode is! int ||
        watchedAt == null) {
      return null;
    }
    return UpNext(
      seriesId: seriesId,
      seriesName: json['seriesName'] as String? ?? '',
      finishedSeason: json['finishedSeason'] as int? ?? season,
      finishedEpisode: json['finishedEpisode'] as int? ?? episode - 1,
      season: season,
      episode: episode,
      episodeId: json['episodeId'] as int?,
      episodeName: json['episodeName'] as String?,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      watchedAt: watchedAt,
    );
  }

  /// What comes after the episode in [metadata], or null if nothing that has
  /// aired does: the next episode of its season, else the first of the next
  /// regular season that has episodes.
  static UpNext? after(TVStreamMetadata metadata, {DateTime? now}) {
    final seriesId = metadata.tvId;
    final season = metadata.seasonNumber;
    final number = metadata.episodeNumber;
    if (seriesId == null || season == null || number == null) return null;
    final today = now ?? DateTime.now();
    bool aired(String? date) {
      final day = DateTime.tryParse(date ?? '');
      return day == null || !day.isAfter(today);
    }

    UpNext make(int nextSeason, int nextEpisode, {EpisodeMetadata? known}) =>
        UpNext(
          seriesId: seriesId,
          seriesName: metadata.seriesName ?? '',
          finishedSeason: season,
          finishedEpisode: number,
          season: nextSeason,
          episode: nextEpisode,
          episodeId: known?.episodeId,
          episodeName: known?.episodeName,
          posterPath: metadata.posterPath,
          backdropPath: known?.stillPath ?? metadata.backdropPath,
          watchedAt: today,
        );

    final allSeasons = metadata.allSeasons ?? const <SeasonMetadata>[];
    final episodes = metadata.seasonEpisodes ?? const <EpisodeMetadata>[];
    if (episodes.isNotEmpty) {
      for (final episode in episodes) {
        if (episode.episodeNumber == number + 1) {
          return aired(episode.airDate)
              ? make(season, number + 1, known: episode)
              : null;
        }
      }
    } else {
      // Without the season's episodes, its count says whether there's more;
      // knowing nothing at all, assume there is.
      final current =
          allSeasons.where((known) => known.seasonNumber == season).firstOrNull;
      if (current == null || current.episodeCount > number) {
        return make(season, number + 1);
      }
    }
    // This season ends here: on to the first of the next one with episodes.
    final later = allSeasons
        .where(
          (next) =>
              next.seasonNumber > season &&
              next.seasonNumber > 0 &&
              next.episodeCount > 0,
        )
        .toList()
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    if (later.isNotEmpty) return make(later.first.seasonNumber, 1);
    return null;
  }
}

/// Where [UpNext]s are kept between launches: on this device only.
class UpNextStore {
  UpNextStore(this._preferences);

  static const key = 'up_next.v1';

  final SharedPreferences _preferences;

  Map<int, UpNext> load() {
    final raw = _preferences.getString(key);
    if (raw == null) return <int, UpNext>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <int, UpNext>{};
      return <int, UpNext>{
        for (final entry in decoded.map(UpNext.fromJson).whereType<UpNext>())
          entry.seriesId: entry,
      };
    } on FormatException {
      return <int, UpNext>{};
    }
  }

  Future<void> save(Map<int, UpNext> entries) => _preferences.setString(
        key,
        jsonEncode(
          entries.values.map((entry) => entry.toJson()).toList(),
        ),
      );
}

/// The series' next episodes, as recently watched keeps them: one per
/// series, the most recent [limit], saved through a [UpNextStore] if there
/// is one.
class UpNextBook {
  UpNextBook({this.store, this.limit = 50})
      : _entries = store?.load() ?? <int, UpNext>{};

  final UpNextStore? store;
  final int limit;
  Map<int, UpNext> _entries;

  List<UpNext> get entries => List<UpNext>.unmodifiable(_entries.values);

  void reload() => _entries = store?.load() ?? _entries;

  /// Keeps [entry] as its series' next episode, replacing any before, and
  /// lets the oldest go past [limit].
  Future<void> record(UpNext entry) async {
    _entries
      ..remove(entry.seriesId)
      ..[entry.seriesId] = entry;
    if (_entries.length > limit) {
      final oldest = _entries.values.toList()
        ..sort((a, b) => a.watchedAt.compareTo(b.watchedAt));
      for (final stale in oldest.take(_entries.length - limit)) {
        _entries.remove(stale.seriesId);
      }
    }
    await store?.save(_entries);
  }

  /// Forgets [seriesId]'s next episode; whether there was one.
  Future<bool> clear(int seriesId) async {
    if (_entries.remove(seriesId) == null) return false;
    await store?.save(_entries);
    return true;
  }
}
