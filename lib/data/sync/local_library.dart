import 'package:sqflite/sqflite.dart';
import '../../controllers/bookmark_database_controller.dart';
import '../../controllers/recently_watched_database_controller.dart';

class LocalLibrary {
  const LocalLibrary(
      this.movies, this.tv, this.recentMovies, this.recentEpisodes);
  final Database movies, tv, recentMovies, recentEpisodes;
  static Future<LocalLibrary> open(String owner) async => LocalLibrary(
      await MovieDatabaseController().databaseForOwner(owner),
      await TVDatabaseController().databaseForOwner(owner),
      await RecentlyWatchedMoviesController().databaseForOwner(owner),
      await RecentlyWatchedEpisodeController().databaseForOwner(owner));
  List<(Database, String)> get tables => [
        (movies, 'movie_bookmark_table'),
        (tv, 'tv_bookmark_table'),
        (recentMovies, 'recently_watched_movies_table'),
        (recentEpisodes, 'recently_watched_tv_shows_table')
      ];
  Future<void> clear() async {
    for (final target in tables) {
      await target.$1.delete(target.$2);
    }
  }

  /// Returns the copied snapshot. Guest rows are removed only after successful
  /// synchronization, and only if they have not changed since they were copied.
  Future<List<List<Map<String, dynamic>>>> copyInto(
      LocalLibrary account) async {
    final snapshots = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < tables.length; i++) {
      final source = tables[i];
      final target = account.tables[i];
      final rows = await source.$1.query(source.$2);
      snapshots.add(rows);
      await target.$1.transaction((txn) async {
        for (final row in rows) {
          if (i < 2) {
            await txn.insert(target.$2, row,
                conflictAlgorithm: ConflictAlgorithm.ignore);
          } else {
            final local = await txn.query(target.$2,
                where: 'id = ?', whereArgs: [row['id']], limit: 1);
            if (local.isNotEmpty &&
                (local.first['updated_at_utc'] as int? ?? 0) >=
                    (row['updated_at_utc'] as int? ?? 0)) {
              continue;
            }
            await txn.insert(target.$2, {...row, 'synced': 0},
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
    }
    return snapshots;
  }

  Future<void> clearCopied(List<List<Map<String, dynamic>>> snapshots) async {
    for (var i = 0; i < tables.length; i++) {
      final target = tables[i];
      await target.$1.transaction((txn) async {
        for (final row in snapshots[i]) {
          final current = await txn.query(target.$2,
              where: 'id = ?', whereArgs: [row['id']], limit: 1);
          if (current.isNotEmpty &&
              row.entries
                  .every((entry) => current.first[entry.key] == entry.value)) {
            await txn
                .delete(target.$2, where: 'id = ?', whereArgs: [row['id']]);
          }
        }
      });
    }
  }
}
