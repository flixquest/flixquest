import 'dart:convert';

enum WellnessMediaType { movie, episode, live }

enum WellnessPlaybackSource { streaming, offline, live }

class WellnessPlaybackSegment {
  const WellnessPlaybackSegment({
    required this.startedAtUtc,
    required this.endedAtUtc,
  });

  final DateTime startedAtUtc;
  final DateTime endedAtUtc;

  int get watchedMs => endedAtUtc
      .difference(startedAtUtc)
      .inMilliseconds
      .clamp(0, 24 * 60 * 60 * 1000);

  Map<String, dynamic> toMap() => <String, dynamic>{
        'startedAtUtc': startedAtUtc.millisecondsSinceEpoch,
        'endedAtUtc': endedAtUtc.millisecondsSinceEpoch,
      };

  factory WellnessPlaybackSegment.fromMap(Map<String, dynamic> map) {
    return WellnessPlaybackSegment(
      startedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        (map['startedAtUtc'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      endedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        (map['endedAtUtc'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
    );
  }
}

/// An immutable, device-generated record of active playback.
///
/// Records are upserted while playback is in progress, then treated as
/// immutable once [endedAtUtc] is set. Deletion uses a tombstone so an offline
/// device cannot resurrect a record that was removed elsewhere.
class WellnessViewingSession {
  const WellnessViewingSession({
    required this.id,
    required this.ownerId,
    required this.deviceId,
    required this.mediaType,
    required this.source,
    required this.contentId,
    required this.title,
    required this.startedAtUtc,
    required this.endedAtUtc,
    required this.timezoneOffsetMinutes,
    required this.watchedMs,
    required this.durationMs,
    required this.progressEndMs,
    required this.completed,
    required this.segments,
    required this.updatedAtUtc,
    this.seriesId,
    this.subtitle,
    this.seasonNumber,
    this.episodeNumber,
    this.posterPath,
    this.backdropPath,
    this.releaseYear,
    this.provider,
    this.genres = const <String>[],
    this.languages = const <String>[],
    this.countries = const <String>[],
    this.networkBytes,
    this.deletedAtUtc,
    this.synced = false,
  });

  final String id;
  final String ownerId;
  final String deviceId;
  final WellnessMediaType mediaType;
  final WellnessPlaybackSource source;
  final String contentId;
  final String? seriesId;
  final String title;
  final String? subtitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final DateTime startedAtUtc;
  final DateTime endedAtUtc;
  final int timezoneOffsetMinutes;
  final int watchedMs;
  final int durationMs;
  final int progressEndMs;
  final bool completed;
  final List<WellnessPlaybackSegment> segments;
  final String? posterPath;
  final String? backdropPath;
  final int? releaseYear;
  final String? provider;
  final List<String> genres;
  final List<String> languages;
  final List<String> countries;

  /// Network bytes the player downloaded for this session, cache reads
  /// excluded. Null when it was not measured: sessions recorded before this
  /// was tracked, and platforms whose player does not report it.
  final int? networkBytes;
  final DateTime updatedAtUtc;
  final DateTime? deletedAtUtc;
  final bool synced;

  bool get isDeleted => deletedAtUtc != null;
  bool get qualifies => watchedMs >= const Duration(seconds: 30).inMilliseconds;
  String get viewingStatus {
    if (completed) return 'completed';
    if (watchedMs < const Duration(minutes: 2).inMilliseconds &&
        progress < .05) {
      return 'sampled';
    }
    return 'in progress';
  }

  double get progress =>
      durationMs <= 0 ? 0 : (progressEndMs / durationMs).clamp(0.0, 1.0);

  String get uniqueTitleKey => switch (mediaType) {
        WellnessMediaType.movie => 'movie:$contentId',
        WellnessMediaType.episode => 'episode:$contentId',
        WellnessMediaType.live => 'live:$contentId',
      };

  String get uniqueSeriesKey =>
      seriesId == null ? uniqueTitleKey : 'tv:$seriesId';

  WellnessViewingSession copyWith({
    String? ownerId,
    DateTime? deletedAtUtc,
    bool clearDeletedAt = false,
    bool? synced,
    DateTime? updatedAtUtc,
  }) {
    return WellnessViewingSession(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      deviceId: deviceId,
      mediaType: mediaType,
      source: source,
      contentId: contentId,
      seriesId: seriesId,
      title: title,
      subtitle: subtitle,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      startedAtUtc: startedAtUtc,
      endedAtUtc: endedAtUtc,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      watchedMs: watchedMs,
      durationMs: durationMs,
      progressEndMs: progressEndMs,
      completed: completed,
      segments: segments,
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseYear: releaseYear,
      provider: provider,
      genres: genres,
      languages: languages,
      countries: countries,
      networkBytes: networkBytes,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      deletedAtUtc: clearDeletedAt ? null : deletedAtUtc ?? this.deletedAtUtc,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'owner_id': ownerId,
        'device_id': deviceId,
        'media_type': mediaType.name,
        'source': source.name,
        'content_id': contentId,
        'series_id': seriesId,
        'title': title,
        'subtitle': subtitle,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        'started_at_utc': startedAtUtc.millisecondsSinceEpoch,
        'ended_at_utc': endedAtUtc.millisecondsSinceEpoch,
        'timezone_offset_minutes': timezoneOffsetMinutes,
        'watched_ms': watchedMs,
        'duration_ms': durationMs,
        'progress_end_ms': progressEndMs,
        'completed': completed ? 1 : 0,
        'segments_json': jsonEncode(
          segments.map((segment) => segment.toMap()).toList(growable: false),
        ),
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'release_year': releaseYear,
        'provider': provider,
        'genres_json': jsonEncode(genres),
        'languages_json': jsonEncode(languages),
        'countries_json': jsonEncode(countries),
        'network_bytes': networkBytes,
        'updated_at_utc': updatedAtUtc.millisecondsSinceEpoch,
        'deleted_at_utc': deletedAtUtc?.millisecondsSinceEpoch,
        'synced': synced ? 1 : 0,
      };

  Map<String, dynamic> toCloudMap() => <String, dynamic>{
        'schemaVersion': 1,
        'deviceId': deviceId,
        'mediaType': mediaType.name,
        'source': source.name,
        'contentId': contentId,
        if (seriesId != null) 'seriesId': seriesId,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (seasonNumber != null) 'seasonNumber': seasonNumber,
        if (episodeNumber != null) 'episodeNumber': episodeNumber,
        'startedAtUtc': startedAtUtc.millisecondsSinceEpoch,
        'endedAtUtc': endedAtUtc.millisecondsSinceEpoch,
        'timezoneOffsetMinutes': timezoneOffsetMinutes,
        'watchedMs': watchedMs,
        'durationMs': durationMs,
        'progressEndMs': progressEndMs,
        'completed': completed,
        'segments': segments.map((segment) => segment.toMap()).toList(),
        if (posterPath != null) 'posterPath': posterPath,
        if (backdropPath != null) 'backdropPath': backdropPath,
        if (releaseYear != null) 'releaseYear': releaseYear,
        if (provider != null) 'provider': provider,
        'genres': genres,
        'languages': languages,
        'countries': countries,
        // Optional so documents stay readable by builds that predate it.
        if (networkBytes != null) 'networkBytes': networkBytes,
        'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
        if (deletedAtUtc != null)
          'deletedAtUtc': deletedAtUtc!.millisecondsSinceEpoch,
      };

  factory WellnessViewingSession.fromMap(Map<String, dynamic> map) {
    List<String> decodeStrings(Object? raw) {
      if (raw is List) return raw.map((item) => item.toString()).toList();
      if (raw is! String || raw.isEmpty) return const <String>[];
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => item.toString())
          .toList(growable: false);
    }

    List<WellnessPlaybackSegment> decodeSegments(Object? raw) {
      final list = raw is String
          ? jsonDecode(raw) as List<dynamic>
          : raw as List<dynamic>? ?? const <dynamic>[];
      return list
          .whereType<Map>()
          .map((item) => WellnessPlaybackSegment.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false);
    }

    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      final name = raw?.toString();
      return values.firstWhere(
        (value) => value.name == name,
        orElse: () => fallback,
      );
    }

    int integer(String snake, String camel) =>
        (map[snake] as num?)?.toInt() ?? (map[camel] as num?)?.toInt() ?? 0;

    final deletedMillis = integer('deleted_at_utc', 'deletedAtUtc');
    return WellnessViewingSession(
      id: map['id']?.toString() ?? '',
      ownerId: map['owner_id']?.toString() ?? map['ownerId']?.toString() ?? '',
      deviceId:
          map['device_id']?.toString() ?? map['deviceId']?.toString() ?? '',
      mediaType: enumValue(
        WellnessMediaType.values,
        map['media_type'] ?? map['mediaType'],
        WellnessMediaType.movie,
      ),
      source: enumValue(
        WellnessPlaybackSource.values,
        map['source'],
        WellnessPlaybackSource.streaming,
      ),
      contentId:
          map['content_id']?.toString() ?? map['contentId']?.toString() ?? '',
      seriesId: map['series_id']?.toString() ?? map['seriesId']?.toString(),
      title: map['title']?.toString() ?? 'Unknown title',
      subtitle: map['subtitle']?.toString(),
      seasonNumber: integer('season_number', 'seasonNumber'),
      episodeNumber: integer('episode_number', 'episodeNumber'),
      startedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        integer('started_at_utc', 'startedAtUtc'),
        isUtc: true,
      ),
      endedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        integer('ended_at_utc', 'endedAtUtc'),
        isUtc: true,
      ),
      timezoneOffsetMinutes:
          integer('timezone_offset_minutes', 'timezoneOffsetMinutes'),
      watchedMs: integer('watched_ms', 'watchedMs'),
      durationMs: integer('duration_ms', 'durationMs'),
      progressEndMs: integer('progress_end_ms', 'progressEndMs'),
      completed: map['completed'] == true || map['completed'] == 1,
      segments: decodeSegments(map['segments_json'] ?? map['segments']),
      posterPath:
          map['poster_path']?.toString() ?? map['posterPath']?.toString(),
      backdropPath:
          map['backdrop_path']?.toString() ?? map['backdropPath']?.toString(),
      releaseYear: integer('release_year', 'releaseYear') == 0
          ? null
          : integer('release_year', 'releaseYear'),
      provider: map['provider']?.toString(),
      genres: decodeStrings(map['genres_json'] ?? map['genres']),
      languages: decodeStrings(map['languages_json'] ?? map['languages']),
      countries: decodeStrings(map['countries_json'] ?? map['countries']),
      networkBytes: ((map['network_bytes'] ?? map['networkBytes']) as num?)
          ?.toInt(),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        integer('updated_at_utc', 'updatedAtUtc'),
        isUtc: true,
      ),
      deletedAtUtc: deletedMillis == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deletedMillis, isUtc: true),
      synced: map['synced'] == true || map['synced'] == 1,
    );
  }
}

class WellnessPlaybackTracker {
  WellnessPlaybackTracker({required this.id, DateTime? createdAt})
      : createdAtUtc = (createdAt ?? DateTime.now()).toUtc();

  final String id;
  final DateTime createdAtUtc;
  final List<WellnessPlaybackSegment> _segments = <WellnessPlaybackSegment>[];
  DateTime? _activeStartedAtUtc;

  void play([DateTime? now]) {
    _activeStartedAtUtc ??= (now ?? DateTime.now()).toUtc();
  }

  void pause([DateTime? now]) {
    final startedAt = _activeStartedAtUtc;
    if (startedAt == null) return;
    final endedAt = (now ?? DateTime.now()).toUtc();
    if (endedAt.isAfter(startedAt)) {
      _segments.add(WellnessPlaybackSegment(
        startedAtUtc: startedAt,
        endedAtUtc: endedAt,
      ));
    }
    _activeStartedAtUtc = null;
  }

  List<WellnessPlaybackSegment> snapshot([DateTime? now]) {
    final result = <WellnessPlaybackSegment>[..._segments];
    final startedAt = _activeStartedAtUtc;
    final endedAt = (now ?? DateTime.now()).toUtc();
    if (startedAt != null && endedAt.isAfter(startedAt)) {
      result.add(WellnessPlaybackSegment(
        startedAtUtc: startedAt,
        endedAtUtc: endedAt,
      ));
    }
    return List<WellnessPlaybackSegment>.unmodifiable(result);
  }

  int watchedMs([DateTime? now]) => snapshot(now).fold<int>(
        0,
        (total, segment) => total + segment.watchedMs,
      );
}
