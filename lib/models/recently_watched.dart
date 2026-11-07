import '../data/sync/library_scope.dart';

/// Local and cloud representations of the "recently watched" (continue
/// watching) rows shown on the home screens.
///
/// Unlike bookmarks, these rows are mutable progress state that any signed-in
/// device can change, so each row carries a UTC version stamp used for
/// last-write-wins merges, a tombstone stamp so removals (dismissed or
/// finished titles) propagate instead of being resurrected by another device,
/// and a pending-push flag.
int _nowUtcMillis() => LibraryScope.nowUtcMs();

int? _asInt(Object? value) => (value as num?)?.toInt();

bool _asBool(Object? value) {
  if (value is bool) return value;
  return (_asInt(value) ?? 0) == 1;
}

class RecentMovie {
  RecentMovie({
    required this.backdropPath,
    required this.dateTime,
    required this.elapsed,
    required this.id,
    required this.posterPath,
    required this.releaseYear,
    required this.remaining,
    required this.title,
    int? updatedAtUtc,
    this.deletedAtUtc,
    this.synced = false,
    this.syncRevision,
    this.syncedAtUtc,
  }) : updatedAtUtc = updatedAtUtc ?? _nowUtcMillis();

  int? id;
  String? title;
  int? releaseYear;
  int? elapsed;
  int? remaining;
  String? dateTime;
  String? posterPath;
  String? backdropPath;

  /// Version stamp for cloud merges: the newest write for an id wins.
  int updatedAtUtc;

  /// Set when the title was dismissed or finished. Tombstones live in both
  /// stores until they are pruned so the removal can reach other devices.
  int? deletedAtUtc;

  /// False while the row still has to be uploaded.
  bool synced;
  int? syncRevision;
  int? syncedAtUtc;

  bool get isDeleted => deletedAtUtc != null;

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};
    map['id'] = id;
    map['title'] = title;
    map['release_year'] = releaseYear;
    map['elapsed'] = elapsed;
    map['remaining'] = remaining;
    map['date_watched'] = dateTime;
    map['poster_path'] = posterPath;
    map['backdrop_path'] = backdropPath;
    map['updated_at_utc'] = updatedAtUtc;
    map['deleted_at_utc'] = deletedAtUtc;
    map['synced'] = synced ? 1 : 0;
    return map;
  }

  RecentMovie.fromMapObject(Map<String, dynamic> map)
      : updatedAtUtc = _asInt(map['updated_at_utc']) ?? _nowUtcMillis(),
        deletedAtUtc = _asInt(map['deleted_at_utc']),
        synced = _asBool(map['synced']) {
    id = map['id'];
    title = map['title'];
    releaseYear = map['release_year'];
    elapsed = map['elapsed'];
    remaining = map['remaining'];
    dateTime = map['date_watched'];
    posterPath = map['poster_path'];
    backdropPath = map['backdrop_path'];
  }
}

class RecentEpisode {
  RecentEpisode({
    required this.dateTime,
    required this.elapsed,
    required this.episodeName,
    required this.episodeNum,
    required this.id,
    required this.posterPath,
    required this.remaining,
    required this.seasonNum,
    required this.seriesName,
    required this.seriesId,
    this.backdropPath,
    int? updatedAtUtc,
    this.deletedAtUtc,
    this.synced = false,
    this.syncRevision,
    this.syncedAtUtc,
  }) : updatedAtUtc = updatedAtUtc ?? _nowUtcMillis();

  int? id;
  String? seriesName;
  String? episodeName;
  int? episodeNum;
  int? seasonNum;
  String? posterPath;
  String? dateTime;
  int? elapsed;
  int? remaining;
  int? seriesId;
  String? backdropPath;

  /// Version stamp for cloud merges: the newest write for an id wins.
  int updatedAtUtc;

  /// Set when the episode was dismissed or finished.
  int? deletedAtUtc;

  /// False while the row still has to be uploaded.
  bool synced;
  int? syncRevision;
  int? syncedAtUtc;

  bool get isDeleted => deletedAtUtc != null;

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};
    map['id'] = id;
    map['series_name'] = seriesName;
    map['episode_name'] = episodeName;
    map['episode_num'] = episodeNum;
    map['season_num'] = seasonNum;
    map['poster_path'] = posterPath;
    map['backdrop_path'] = backdropPath;
    map['elapsed'] = elapsed;
    map['remaining'] = remaining;
    map['date_added'] = dateTime;
    map['series_id'] = seriesId;
    map['updated_at_utc'] = updatedAtUtc;
    map['deleted_at_utc'] = deletedAtUtc;
    map['synced'] = synced ? 1 : 0;
    return map;
  }

  RecentEpisode.fromMapObject(Map<String, dynamic> map)
      : updatedAtUtc = _asInt(map['updated_at_utc']) ?? _nowUtcMillis(),
        deletedAtUtc = _asInt(map['deleted_at_utc']),
        synced = _asBool(map['synced']) {
    id = map['id'];
    seriesName = map['series_name'];
    episodeName = map['episode_name'];
    episodeNum = map['episode_num'];
    seasonNum = map['season_num'];
    posterPath = map['poster_path'];
    backdropPath = map['backdrop_path'];
    elapsed = map['elapsed'];
    remaining = map['remaining'];
    dateTime = map['date_added'];
    seriesId = map['series_id'];
    backdropPath = map['backdrop_path'];
  }
}
