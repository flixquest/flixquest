import 'package:sqflite/sqflite.dart';
import '../../models/movie.dart';
import '../../models/tv.dart';
import '../repositories/bookmark_repository.dart';
import 'library_scope.dart';

class BookmarkSyncEngine {
  BookmarkSyncEngine(this.repository);
  final BookmarkRepository repository;
  Future<void> sync(String owner, Database movies, Database tv,
      {bool Function()? isCurrent}) async {
    const movieTable = 'movie_bookmark_table';
    const tvTable = 'tv_bookmark_table';
    final localMovies =
        (await movies.query(movieTable)).map(Movie.fromMapObject).toList();
    final localTv = (await tv.query(tvTable)).map(TV.fromMapObject).toList();
    final version = LibraryScope.bookmarkRevision;
    if (isCurrent != null && !isCurrent()) return;
    final remote = await repository.sync(owner, localMovies, localTv);
    if ((isCurrent != null && !isCurrent()) ||
        version != LibraryScope.bookmarkRevision) {
      return;
    }
    await _apply(movies, movieTable, localMovies.map((m) => m.id).toSet(),
        remote.movies.map((m) => m.toMap()).toList());
    await _apply(tv, tvTable, localTv.map((t) => t.id).toSet(),
        remote.tvShows.map((t) => t.toMap()).toList());
  }

  Future<void> _apply(Database db, String table, Set<int?> original,
      List<Map<String, dynamic>> remote) async {
    final remoteIds = remote.map((row) => row['id']).toSet();
    await db.transaction((txn) async {
      for (final id in original.difference(remoteIds)) {
        await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      }
      for (final row in remote) {
        final current = await txn.query(table,
            where: 'id = ?', whereArgs: [row['id']], limit: 1);
        // A local removal made during the request must not be reinserted.
        if (current.isEmpty && original.contains(row['id'])) continue;
        if (current.isEmpty) {
          await txn.insert(table, row,
              conflictAlgorithm: ConflictAlgorithm.ignore);
        } else if ((current.first['genre_ids'] == null ||
                current.first['genre_ids'] == '') &&
            row['genre_ids'] != null) {
          await txn.update(table, {'genre_ids': row['genre_ids']},
              where: 'id = ?', whereArgs: [row['id']]);
        }
      }
    });
  }
}
