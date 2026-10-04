import 'package:sqflite/sqflite.dart';
import '../../core/time/server_clock.dart';
import '../../models/recently_watched.dart';
import '../repositories/recently_watched_repository.dart';

/// Captured database handles keep an in-flight sync in its original account.
class RecentSyncEngine {
  RecentSyncEngine(this.repository, this.clock);
  final RecentlyWatchedRepository repository;
  final ServerClock clock;

  Future<void> sync(String owner, Database movies, Database episodes,
      {bool Function()? isCurrent}) async {
    const movieTable = 'recently_watched_movies_table';
    const episodeTable = 'recently_watched_tv_shows_table';
    final movieRows = await movies.query(movieTable, where: 'synced = 0');
    final episodeRows = await episodes.query(episodeTable, where: 'synced = 0');
    final operations = [
      for (final row in movieRows) (movie: true, row: row),
      for (final row in episodeRows) (movie: false, row: row),
    ];
    // Even an empty upload performs the pull.
    for (var start = 0; start < operations.length || start == 0; start += 450) {
      if (isCurrent != null && !isCurrent()) return;
      final chunk = operations.skip(start).take(450).toList();
      final sentMovies =
          chunk.where((op) => op.movie).map((op) => op.row).toList();
      final sentEpisodes =
          chunk.where((op) => !op.movie).map((op) => op.row).toList();
      final result = await repository.sync(owner,
          movies: sentMovies
              .map((row) => RecentMovie.fromMapObject(row).toLaravelMap())
              .toList(),
          episodes: sentEpisodes
              .map((row) => RecentEpisode.fromMapObject(row).toLaravelMap())
              .toList());
      if (isCurrent != null && !isCurrent()) return;
      await _apply(
          movies,
          movieTable,
          sentMovies,
          result.uploads['movies'] as List,
          (result.data['movies'] as List)
              .map((row) =>
                  RecentMovie.fromLaravelMap(Map<String, dynamic>.from(row))
                      .toMap())
              .toList(),
          full: result.full);
      await _apply(
          episodes,
          episodeTable,
          sentEpisodes,
          result.uploads['episodes'] as List,
          (result.data['episodes'] as List)
              .map((row) =>
                  RecentEpisode.fromLaravelMap(Map<String, dynamic>.from(row))
                      .toMap())
              .toList(),
          full: result.full);
      await result.saveCursor();
      if (operations.isEmpty) break;
    }
    final cutoff = clock.nowUtcMs() - const Duration(days: 90).inMilliseconds;
    for (final target in [(movies, movieTable), (episodes, episodeTable)]) {
      await target.$1.delete(target.$2,
          where: 'deleted_at_utc < ? AND synced = 1', whereArgs: [cutoff]);
    }
  }

  static Future<void> _apply(
      Database db,
      String table,
      List<Map<String, dynamic>> original,
      List corrected,
      List<Map<String, dynamic>> remote,
      {required bool full}) async {
    await db.transaction((txn) async {
      for (var i = 0; i < original.length; i++) {
        final row = original[i];
        // Only acknowledge the version actually sent. Playback may have advanced.
        await txn.update(
            table,
            {
              'synced': 1,
              'updated_at_utc': corrected[i]['updated_at_utc'],
              'deleted_at_utc': corrected[i]['deleted_at_utc'],
            },
            where: 'id = ? AND updated_at_utc = ? AND synced = 0',
            whereArgs: [row['id'], row['updated_at_utc']]);
      }
      if (full) {
        final ids = remote.map((row) => row['id']).toSet();
        for (final row in await txn.query(table, where: 'synced = 1')) {
          if (!ids.contains(row['id'])) {
            await txn.delete(table, where: 'id = ?', whereArgs: [row['id']]);
          }
        }
      }
      for (final row in remote) {
        final existing = await txn.query(table,
            where: 'id = ?', whereArgs: [row['id']], limit: 1);
        if (existing.isNotEmpty &&
            (existing.first['updated_at_utc'] as num? ?? 0) >=
                (row['updated_at_utc'] as num)) {
          continue;
        }
        if (existing.isEmpty && row['deleted_at_utc'] != null) continue;
        await txn.insert(table, row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
