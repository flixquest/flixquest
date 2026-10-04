import 'package:sqflite/sqflite.dart';
import '../../controllers/wellness_database_controller.dart';
import '../../core/time/server_clock.dart';
import '../../models/wellness.dart';
import '../repositories/wellness_repository.dart';
import 'daily_write_plan.dart';

class WellnessSyncEngine {
  WellnessSyncEngine(this.repository, this.database, this.clock);
  final WellnessRepository repository;
  final WellnessDatabaseController database;
  final ServerClock clock;

  Future<void> sync(String owner, {bool Function()? isCurrent}) async {
    final pending = await database.pendingSessions(owner);
    final summaries = {
      for (final row in await database.dailySummaries(owner))
        row['local_day'] as String: row
    };
    final ledger = repository.dailyLedger(owner);
    final plan = planDailyWrites(ledger: ledger, local: {
      for (final entry in summaries.entries)
        entry.key: entry.value['updated_at_utc'] as int?
    });
    final daily = <Map<String, dynamic>>[
      for (final day in plan.sets) {...summaries[day]!}..remove('owner_id'),
      // The API stores daily aggregates, so a removed day travels as a newer
      // zero aggregate. A null ledger stamp denotes an acknowledged zero day.
      for (final day in plan.deletes)
        if (ledger[day] != null)
          {
            'local_day': day,
            'timezone_offset_minutes': 0,
            'watched_ms': 0,
            'movie_ms': 0,
            'episode_ms': 0,
            'live_ms': 0,
            'completed_movies': 0,
            'completed_episodes': 0,
            'session_count': 0,
            'updated_at_utc': clock.nowUtcMs(),
          },
    ];
    if (isCurrent != null && !isCurrent()) return;
    final result = await repository.sync(owner,
        sessions: pending.map((row) => row.toLaravelMap()).toList(),
        daily: daily);
    if (isCurrent != null && !isCurrent()) return;
    // Parse before the transaction; malformed pages leave the cursor untouched.
    final remote = result.sessions
        .map((row) => WellnessViewingSession.fromMap({
              ...row,
              'owner_id': owner,
              'synced': 1,
            }))
        .toList();
    final db = await database.database;
    await db.transaction((txn) async {
      for (var i = 0; i < pending.length; i++) {
        final original = pending[i];
        final corrected = result.uploadedSessions[i];
        await txn.update(
            'wellness_sessions',
            {
              'synced': 1,
              'updated_at_utc': corrected['updated_at_utc'],
              'deleted_at_utc': corrected['deleted_at_utc'],
            },
            where:
                'owner_id = ? AND id = ? AND updated_at_utc = ? AND synced = 0',
            whereArgs: [
              owner,
              original.id,
              original.updatedAtUtc.millisecondsSinceEpoch
            ]);
      }
      if (result.full) {
        final ids = remote.map((row) => row.id).toSet();
        for (final row in await txn.query('wellness_sessions',
            where: 'owner_id = ? AND synced = 1', whereArgs: [owner])) {
          if (!ids.contains(row['id'])) {
            await txn.delete('wellness_sessions',
                where: 'owner_id = ? AND id = ?',
                whereArgs: [owner, row['id']]);
          }
        }
      }
      for (final row in remote) {
        final existing = await txn.query('wellness_sessions',
            where: 'id = ?', whereArgs: [row.id], limit: 1);
        if (existing.isNotEmpty) {
          if (existing.first['owner_id'] != owner) {
            throw const FormatException('Session owner conflict');
          }
          if ((existing.first['updated_at_utc'] as int) >=
              row.updatedAtUtc.millisecondsSinceEpoch) {
            continue;
          }
        }
        await txn.insert('wellness_sessions', row.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.delete('wellness_sessions',
          where: 'owner_id = ? AND deleted_at_utc < ? AND synced = 1',
          whereArgs: [
            owner,
            clock.nowUtcMs() - const Duration(days: 90).inMilliseconds
          ]);
    });
    // Daily summaries shown in the app are derived from the merged sessions.
    await database.rebuildDailySummaries(owner);
    await result.save();
  }
}
