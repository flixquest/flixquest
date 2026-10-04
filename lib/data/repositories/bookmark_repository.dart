import 'package:dio/dio.dart';
import '../../core/cache/cache_policy.dart';
import '../../core/storage/kv_store.dart';
import '../../models/movie.dart';
import '../../models/tv.dart';

/// Uploads local additions/deletions and consumes Laravel's complete union.
/// An acknowledged title is not uploaded again merely because it remains local.
class BookmarkRepository {
  BookmarkRepository(this._dio, this._store);
  final Dio _dio;
  final KvStore _store;
  Future<void> _journalWork = Future.value();
  Future<void> _requestWork = Future.value();
  Future<T> _serialized<T>(Future<T> Function() action) {
    final work = _requestWork.then((_) => action());
    _requestWork =
        work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return work;
  }

  Set<String> _pending(String owner) =>
      (_store.getJson('sync.$owner.bookmarks.deleted') as List?)
          ?.cast<String>()
          .toSet() ??
      {};
  Future<void> _journal(String owner, void Function(Set<String>) edit) {
    final work = _journalWork.then((_) async {
      final pending = _pending(owner);
      edit(pending);
      await _store.setJson('sync.$owner.bookmarks.deleted', pending.toList());
    });
    _journalWork = work.catchError((Object _) {});
    return work;
  }

  Future<({List<Movie> movies, List<TV> tvShows})> sync(
          String owner, List<Movie> movies, List<TV> tvShows,
          {List<Map<String, dynamic>> deletedMedia = const []}) =>
      _serialized(
          () => _sync(owner, movies, tvShows, deletedMedia: deletedMedia));

  Future<({List<Movie> movies, List<TV> tvShows})> _sync(
      String owner, List<Movie> movies, List<TV> tvShows,
      {List<Map<String, dynamic>> deletedMedia = const []}) async {
    final key = 'sync.$owner.bookmarks.known';
    final known =
        (_store.getJson(key) as List?)?.cast<String>().toSet() ?? <String>{};
    final pending = _pending(owner);
    final uploadKnown = known.difference(pending);
    final local = {
      for (final m in movies) 'movie:${m.id}',
      for (final t in tvShows) 'tv:${t.id}'
    };
    final deletions = <Map<String, dynamic>>[
      ...deletedMedia,
      for (final id in pending.difference(local))
        {
          'media_type': id.split(':').first,
          'media_id': int.parse(id.split(':').last)
        },
      for (final id in known.difference(local))
        {
          'media_type': id.split(':').first,
          'media_id': int.parse(id.split(':').last)
        },
    ];
    final response = await _dio.post<dynamic>('sync/bookmarks',
        data: {
          'movies': [
            for (final m in movies)
              if (m.id != null && !uploadKnown.contains('movie:${m.id}'))
                {...m.toMap(), 'genre_ids': m.genreIds ?? []}
          ],
          'tvShows': [
            for (final t in tvShows)
              if (t.id != null && !uploadKnown.contains('tv:${t.id}'))
                {...t.toMap(), 'genre_ids': t.genreIds ?? []}
          ],
          'deleted_media': deletions,
        },
        options: Options(
            extra: {'cachePolicy': CachePolicy.noStore, 'syncOwner': owner}));
    final body = response.data;
    if (body is! Map ||
        body['success'] != true ||
        body['movies'] is! List ||
        body['tvShows'] is! List) {
      throw const FormatException('Invalid bookmark sync response');
    }
    final mergedMovies = (body['movies'] as List)
        .map((row) => _movie(Map<String, dynamic>.from(row as Map)))
        .toList();
    final mergedTv = (body['tvShows'] as List)
        .map((row) => _tv(Map<String, dynamic>.from(row as Map)))
        .toList();
    for (final remote in mergedMovies) {
      final matching = movies.where((m) => m.id == remote.id);
      if ((remote.genreIds?.isEmpty ?? true) && matching.isNotEmpty) {
        remote.genreIds = matching.first.genreIds;
      }
    }
    for (final remote in mergedTv) {
      final matching = tvShows.where((t) => t.id == remote.id);
      if ((remote.genreIds?.isEmpty ?? true) && matching.isNotEmpty) {
        remote.genreIds = matching.first.genreIds;
      }
    }
    await _store.setJson(key, [
      for (final m in mergedMovies) 'movie:${m.id}',
      for (final t in mergedTv) 'tv:${t.id}'
    ]);
    await _journal(owner, (current) => current.removeAll(pending));
    return (movies: mergedMovies, tvShows: mergedTv);
  }

  static Movie _movie(Map<String, dynamic> map) {
    final movie = Movie.fromJson(map);
    movie.dateAdded =
        map['date_added'] as String? ?? map['created_at'] as String?;
    return movie;
  }

  static TV _tv(Map<String, dynamic> map) {
    final tv = TV.fromJson({
      ...map,
      'original_name': map['original_name'] ?? map['original_title']
    });
    tv.dateAdded = map['date_added'] as String? ?? map['created_at'] as String?;
    return tv;
  }

  Future<void> deleteMedia(String type, int id, {String? owner}) =>
      _serialized(() => _deleteMedia(type, id, owner: owner));

  Future<void> recordDeletion(String owner, String type, int id) {
    if (!{'movie', 'tv'}.contains(type) || id <= 0) {
      throw ArgumentError('Invalid bookmark');
    }
    return _journal(owner, (pending) => pending.add('$type:$id'));
  }

  Future<void> _deleteMedia(String type, int id, {String? owner}) async {
    if (!{'movie', 'tv'}.contains(type) || id <= 0) {
      throw ArgumentError('Invalid bookmark');
    }
    if (owner != null) {
      await recordDeletion(owner, type, id);
    }
    await _dio.delete<dynamic>('sync/bookmarks/$type/$id',
        options: Options(extra: {
          'cachePolicy': CachePolicy.noStore,
          if (owner != null) 'syncOwner': owner
        }));
  }
}
