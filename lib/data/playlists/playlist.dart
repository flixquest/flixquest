import 'dart:convert';

import '../../catalog/media_item.dart';
import '../../models/genre_ids.dart';
import '../../models/movie.dart';
import '../../models/tv.dart';

abstract final class PlaylistLimits {
  static const lists = 200;
  static const items = 2500;
  static const name = 80;
  static const description = 500;
}

/// The key a title has in every list: its kind and TMDB id, since a movie
/// and a series can share a number.
String playlistEntryKey(String mediaType, int mediaId) => '$mediaType:$mediaId';

String playlistMediaType(MediaKind kind) =>
    kind == MediaKind.movie ? 'movie' : 'tv';

/// One title in a list.
class PlaylistEntry {
  const PlaylistEntry({
    required this.playlistId,
    required this.mediaType,
    required this.mediaId,
    required this.position,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.voteAverage,
    this.releaseDate,
    this.genreIds = const <int>[],
    this.addedAt,
  });

  factory PlaylistEntry.fromItem(String playlistId, MediaItem item,
          {required int position, String? addedAt}) =>
      PlaylistEntry(
        playlistId: playlistId,
        mediaType: playlistMediaType(item.kind),
        mediaId: item.id,
        position: position,
        title: item.title,
        posterPath: item.posterPath,
        backdropPath: item.backdropPath,
        voteAverage: item.rating?.toDouble(),
        releaseDate: item.releaseDate,
        genreIds: item.genreIds,
        addedAt: addedAt,
      );

  factory PlaylistEntry.fromJson(Map<String, dynamic> json) => PlaylistEntry(
        playlistId: json['playlist_id'] as String,
        mediaType: json['media_type'] == 'tv' ? 'tv' : 'movie',
        mediaId: (json['media_id'] as num).toInt(),
        position: (json['position'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        posterPath: json['poster_path'] as String?,
        backdropPath: json['backdrop_path'] as String?,
        voteAverage: (json['vote_average'] as num?)?.toDouble(),
        releaseDate: json['release_date'] as String?,
        genreIds: parseGenreIds(json['genre_ids']) ?? const <int>[],
        addedAt: json['added_at'] as String?,
      );

  factory PlaylistEntry.fromRow(Map<String, Object?> row) => PlaylistEntry(
        playlistId: row['playlist_id'] as String,
        mediaType: row['media_type'] as String,
        mediaId: row['media_id'] as int,
        position: row['position'] as int,
        title: row['title'] as String? ?? '',
        posterPath: row['poster_path'] as String?,
        backdropPath: row['backdrop_path'] as String?,
        voteAverage: (row['vote_average'] as num?)?.toDouble(),
        releaseDate: row['release_date'] as String?,
        genreIds: parseGenreIds(row['genre_ids']) ?? const <int>[],
        addedAt: row['added_at'] as String?,
      );

  final String playlistId;

  final String mediaType;
  final int mediaId;
  final int position;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double? voteAverage;
  final String? releaseDate;

  final List<int> genreIds;
  final String? addedAt;

  String get key => playlistEntryKey(mediaType, mediaId);

  PlaylistEntry at(int position) => PlaylistEntry(
        playlistId: playlistId,
        mediaType: mediaType,
        mediaId: mediaId,
        position: position,
        title: title,
        posterPath: posterPath,
        backdropPath: backdropPath,
        voteAverage: voteAverage,
        releaseDate: releaseDate,
        genreIds: genreIds,
        addedAt: addedAt,
      );

  /// The title as the rest of the app opens it, genres included.
  MediaItem toMediaItem() => mediaType == 'tv'
      ? MediaItem.fromSeries(TV(
          id: mediaId,
          name: title,
          originalName: title,
          posterPath: posterPath,
          backdropPath: backdropPath,
          firstAirDate: releaseDate,
          voteAverage: voteAverage,
          genreIds: genreIds.isEmpty ? null : genreIds,
        ))
      : MediaItem.fromMovie(Movie(
          id: mediaId,
          title: title,
          originalTitle: title,
          posterPath: posterPath,
          backdropPath: backdropPath,
          releaseDate: releaseDate,
          voteAverage: voteAverage,
          genreIds: genreIds.isEmpty ? null : genreIds,
        ));

  Map<String, Object?> toRow() => <String, Object?>{
        'playlist_id': playlistId,
        'media_type': mediaType,
        'media_id': mediaId,
        'position': position,
        'title': title,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'vote_average': voteAverage,
        'release_date': releaseDate,
        'genre_ids': encodeGenreIds(genreIds),
        'added_at': addedAt,
      };
}

/// A list's own facts, without its titles.
class PlaylistRecord {
  const PlaylistRecord({
    required this.id,
    required this.name,
    this.description,
    this.version = 1,
    this.sourceProvider,
    this.sourceId,
    this.createdAt,
    this.shareCode,
    this.shareUrl,
  });

  factory PlaylistRecord.fromJson(Map<String, dynamic> json) {
    final source = json['source'];
    return PlaylistRecord(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      sourceProvider: source is Map ? source['provider'] as String? : null,
      sourceId: source is Map ? source['id']?.toString() : null,
      createdAt: json['created_at'] as String?,
      shareCode: json['share_code'] as String?,
      shareUrl:
          json['visibility'] == 'public' ? json['share_url'] as String? : null,
    );
  }

  factory PlaylistRecord.fromRow(Map<String, Object?> row) => PlaylistRecord(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        description: row['description'] as String?,
        version: row['version'] as int? ?? 1,
        sourceProvider: row['source_provider'] as String?,
        sourceId: row['source_id'] as String?,
        createdAt: row['created_at'] as String?,
        shareCode: row['share_code'] as String?,
        shareUrl: row['share_url'] as String?,
      );

  final String id;
  final String name;
  final String? description;

  /// Bumped by every rename and reorder; edits carry the one they saw.
  final int version;

  /// `tmdb` or `imdb` for an imported list.
  final String? sourceProvider;
  final String? sourceId;
  final String? createdAt;

  /// Made the first time the list is shared, and kept after.
  final String? shareCode;

  /// Set while anyone with the link can see the list.
  final String? shareUrl;

  bool get isPublic => shareUrl != null;

  PlaylistRecord copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    int? version,
  }) =>
      PlaylistRecord(
        id: id,
        name: name ?? this.name,
        description: clearDescription ? null : description ?? this.description,
        version: version ?? this.version,
        sourceProvider: sourceProvider,
        sourceId: sourceId,
        createdAt: createdAt,
        shareCode: shareCode,
        shareUrl: shareUrl,
      );

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'source_provider': sourceProvider,
        'source_id': sourceId,
        'created_at': createdAt,
        'share_code': shareCode,
        'share_url': shareUrl,
      };
}

/// A list as the app shows it: its facts and its titles, in order.
class Playlist {
  const Playlist(this.record, this.entries);

  final PlaylistRecord record;
  final List<PlaylistEntry> entries;

  String get id => record.id;
  String get name => record.name;
  String? get description => record.description;
  int get version => record.version;
  bool get imported => record.sourceProvider != null;
  bool get isPublic => record.isPublic;
  String? get shareUrl => record.shareUrl;

  bool contains(MediaItem item) =>
      entries.any((entry) => entry.key == keyOf(item));

  List<MediaItem> get items =>
      entries.map((entry) => entry.toMediaItem()).toList(growable: false);

  static String keyOf(MediaItem item) =>
      playlistEntryKey(playlistMediaType(item.kind), item.id);
}

class PlaylistOperation {
  const PlaylistOperation({
    required this.id,
    required this.action,
    required this.playlistId,
    this.fields = const <String, Object?>{},
    this.createdAt,
  });

  factory PlaylistOperation.decode(String body) {
    final json = Map<String, dynamic>.from(jsonDecode(body) as Map);
    return PlaylistOperation(
      id: json.remove('operation_id') as String,
      action: json.remove('action') as String,
      playlistId: json.remove('playlist_id') as String,
      createdAt: json.remove('created_at') as String?,
      fields: json,
    );
  }

  static const create = 'playlist.create';
  static const update = 'playlist.update';
  static const delete = 'playlist.delete';
  static const reorder = 'playlist.reorder';
  static const add = 'item.add';
  static const remove = 'item.remove';

  final String id;
  final String action;
  final String playlistId;
  final Map<String, Object?> fields;

  final String? createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'operation_id': id,
        'action': action,
        'playlist_id': playlistId,
        ...fields,
      };

  String encode() => jsonEncode(<String, Object?>{
        ...toJson(),
        if (createdAt != null) 'created_at': createdAt,
      });
}
