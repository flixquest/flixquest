import '../data/sync/library_scope.dart';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/wellness.dart';

class WellnessDatabaseController {
  WellnessDatabaseController._();
  WellnessDatabaseController.forDatabase(Database database) : _database = database;

  static final WellnessDatabaseController instance =
      WellnessDatabaseController._();

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    return _database = await (_opening ??= initializeDatabase());
  }

  Future<Database> initializeDatabase({String? databasePath}) async {
    final path = databasePath ?? join(await getDatabasesPath(), 'flixquest_wellness_v1.db');
    return openDatabase(
      path,
      // Columns added since version 1 are nullable and added in [onOpen]
      // rather than by a version bump, so a build that predates them can
      // still open the database after the app is downgraded.
      version: 1,
      onOpen: _addMissingColumns,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE wellness_sessions(
            id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            device_id TEXT NOT NULL,
            media_type TEXT NOT NULL,
            source TEXT NOT NULL,
            content_id TEXT NOT NULL,
            series_id TEXT,
            title TEXT NOT NULL,
            subtitle TEXT,
            season_number INTEGER,
            episode_number INTEGER,
            started_at_utc INTEGER NOT NULL,
            ended_at_utc INTEGER NOT NULL,
            timezone_offset_minutes INTEGER NOT NULL,
            watched_ms INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL,
            progress_end_ms INTEGER NOT NULL,
            completed INTEGER NOT NULL,
            segments_json TEXT NOT NULL,
            poster_path TEXT,
            backdrop_path TEXT,
            release_year INTEGER,
            provider TEXT,
            genres_json TEXT NOT NULL,
            languages_json TEXT NOT NULL,
            countries_json TEXT NOT NULL,
            network_bytes INTEGER,
            updated_at_utc INTEGER NOT NULL,
            deleted_at_utc INTEGER,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE INDEX wellness_sessions_owner_started
          ON wellness_sessions(owner_id, started_at_utc DESC)
        ''');
        await db.execute('''
          CREATE INDEX wellness_sessions_owner_sync
          ON wellness_sessions(owner_id, synced, updated_at_utc)
        ''');
        await db.execute('''
          CREATE TABLE wellness_daily_summaries(
            owner_id TEXT NOT NULL,
            local_day TEXT NOT NULL,
            timezone_offset_minutes INTEGER NOT NULL,
            watched_ms INTEGER NOT NULL,
            movie_ms INTEGER NOT NULL,
            episode_ms INTEGER NOT NULL,
            live_ms INTEGER NOT NULL,
            completed_movies INTEGER NOT NULL,
            completed_episodes INTEGER NOT NULL,
            session_count INTEGER NOT NULL,
            updated_at_utc INTEGER NOT NULL,
            PRIMARY KEY(owner_id, local_day)
          )
        ''');
      },
    );
  }

  static Future<void> _addMissingColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(wellness_sessions)');
    final names = columns.map((column) => column['name']).toSet();
    if (!names.contains('network_bytes')) {
      await db.execute(
        'ALTER TABLE wellness_sessions ADD COLUMN network_bytes INTEGER',
      );
    }
  }

  Future<void> upsertSession(WellnessViewingSession session) async {
    final db = await database;
    await db.insert(
      'wellness_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await rebuildDailySummaries(session.ownerId);
  }

  Future<void> upsertSessions(
    Iterable<WellnessViewingSession> sessions, {
    required String ownerId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final session in sessions) {
        await txn.insert(
          'wellness_sessions',
          session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await rebuildDailySummaries(ownerId);
  }

  Future<List<WellnessViewingSession>> sessionsForOwner(
    String ownerId, {
    bool includeDeleted = false,
  }) async {
    final db = await database;
    final rows = await db.query(
      'wellness_sessions',
      where: includeDeleted
          ? 'owner_id = ?'
          : 'owner_id = ? AND deleted_at_utc IS NULL',
      whereArgs: <Object?>[ownerId],
      orderBy: 'started_at_utc DESC',
    );
    return rows
        .map((row) => WellnessViewingSession.fromMap(row))
        .toList(growable: false);
  }

  Future<List<WellnessViewingSession>> pendingSessions(String ownerId) async {
    final db = await database;
    final rows = await db.query(
      'wellness_sessions',
      where: 'owner_id = ? AND synced = 0',
      whereArgs: <Object?>[ownerId],
      orderBy: 'updated_at_utc ASC',
    );
    return rows
        .map((row) => WellnessViewingSession.fromMap(row))
        .toList(growable: false);
  }

  Future<WellnessViewingSession?> sessionById(String id) async {
    final db = await database;
    final rows = await db.query(
      'wellness_sessions',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : WellnessViewingSession.fromMap(rows.first);
  }

  Future<void> markSynced(String ownerId, Iterable<String> ids) async {
    final values = ids.toList(growable: false);
    if (values.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final id in values) {
        await txn.update(
          'wellness_sessions',
          <String, Object?>{'synced': 1},
          where: 'owner_id = ? AND id = ?',
          whereArgs: <Object?>[ownerId, id],
        );
      }
    });
  }

  Future<void> tombstoneSession(String ownerId, String id) async {
    final db = await database;
    final now = LibraryScope.nowUtcMs();
    await db.update(
      'wellness_sessions',
      <String, Object?>{
        'deleted_at_utc': now,
        'updated_at_utc': now,
        'synced': 0,
      },
      where: 'owner_id = ? AND id = ?',
      whereArgs: <Object?>[ownerId, id],
    );
    await rebuildDailySummaries(ownerId);
  }

  Future<void> tombstoneAll(String ownerId) async {
    final db = await database;
    final now = LibraryScope.nowUtcMs();
    await db.update(
      'wellness_sessions',
      <String, Object?>{
        'deleted_at_utc': now,
        'updated_at_utc': now,
        'synced': 0,
      },
      where: 'owner_id = ? AND deleted_at_utc IS NULL',
      whereArgs: <Object?>[ownerId],
    );
    await rebuildDailySummaries(ownerId);
  }

  Future<int> ownerSessionCount(String ownerId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM wellness_sessions '
      'WHERE owner_id = ? AND deleted_at_utc IS NULL',
      <Object?>[ownerId],
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> moveOwner({
    required String fromOwnerId,
    required String toOwnerId,
  }) async {
    final db = await database;
    final now = LibraryScope.nowUtcMs();
    await db.update(
      'wellness_sessions',
      <String, Object?>{
        'owner_id': toOwnerId,
        'updated_at_utc': now,
        'synced': 0,
      },
      where: 'owner_id = ?',
      whereArgs: <Object?>[fromOwnerId],
    );
    await rebuildDailySummaries(fromOwnerId);
    await rebuildDailySummaries(toOwnerId);
  }

  Future<void> permanentlyDeleteOwner(String ownerId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'wellness_sessions',
        where: 'owner_id = ?',
        whereArgs: <Object?>[ownerId],
      );
      await txn.delete(
        'wellness_daily_summaries',
        where: 'owner_id = ?',
        whereArgs: <Object?>[ownerId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> dailySummaries(String ownerId) async {
    final db = await database;
    return db.query(
      'wellness_daily_summaries',
      where: 'owner_id = ?',
      whereArgs: <Object?>[ownerId],
      orderBy: 'local_day ASC',
    );
  }

  Future<void> rebuildDailySummaries(String ownerId) async {
    final db = await database;
    final rows = await db.query(
      'wellness_sessions',
      where: 'owner_id = ? AND deleted_at_utc IS NULL AND watched_ms >= ?',
      whereArgs: <Object?>[
        ownerId,
        const Duration(seconds: 30).inMilliseconds,
      ],
    );
    final sessions = rows.map(WellnessViewingSession.fromMap).toList();
    final buckets = <String, _MutableDailySummary>{};
    for (final session in sessions) {
      final localStart = session.startedAtUtc.add(
        Duration(minutes: session.timezoneOffsetMinutes),
      );
      final startKey = _dayKey(localStart);
      final startSummary = buckets.putIfAbsent(
        startKey,
        () => _MutableDailySummary(
          timezoneOffsetMinutes: session.timezoneOffsetMinutes,
        ),
      );
      startSummary.includeUpdatedAt(session.updatedAtUtc);
      startSummary.sessionCount++;
      for (final allocation in _dailyAllocations(session).entries) {
        final summary = buckets.putIfAbsent(
          allocation.key,
          () => _MutableDailySummary(
            timezoneOffsetMinutes: session.timezoneOffsetMinutes,
          ),
        );
        summary.includeUpdatedAt(session.updatedAtUtc);
        summary.watchedMs += allocation.value;
        switch (session.mediaType) {
          case WellnessMediaType.movie:
            summary.movieMs += allocation.value;
          case WellnessMediaType.episode:
            summary.episodeMs += allocation.value;
          case WellnessMediaType.live:
            summary.liveMs += allocation.value;
        }
      }
      if (session.completed) {
        final localEnd = session.endedAtUtc.add(
          Duration(minutes: session.timezoneOffsetMinutes),
        );
        final completionSummary = buckets.putIfAbsent(
          _dayKey(localEnd),
          () => _MutableDailySummary(
            timezoneOffsetMinutes: session.timezoneOffsetMinutes,
          ),
        );
        completionSummary.includeUpdatedAt(session.updatedAtUtc);
        if (session.mediaType == WellnessMediaType.movie) {
          completionSummary.completedMovies++;
        } else if (session.mediaType == WellnessMediaType.episode) {
          completionSummary.completedEpisodes++;
        }
      }
    }

    await db.transaction((txn) async {
      await txn.delete(
        'wellness_daily_summaries',
        where: 'owner_id = ?',
        whereArgs: <Object?>[ownerId],
      );
      for (final entry in buckets.entries) {
        await txn.insert('wellness_daily_summaries', <String, Object?>{
          'owner_id': ownerId,
          'local_day': entry.key,
          'timezone_offset_minutes': entry.value.timezoneOffsetMinutes,
          'watched_ms': entry.value.watchedMs,
          'movie_ms': entry.value.movieMs,
          'episode_ms': entry.value.episodeMs,
          'live_ms': entry.value.liveMs,
          'completed_movies': entry.value.completedMovies,
          'completed_episodes': entry.value.completedEpisodes,
          'session_count': entry.value.sessionCount,
          'updated_at_utc': entry.value.updatedAtUtc,
        });
      }
    });
  }

  static String encodeExport(List<WellnessViewingSession> sessions) {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'schemaVersion': 1,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'sessions': sessions
          .where((session) => !session.isDeleted)
          .map((session) => session.toCloudMap())
          .toList(growable: false),
    });
  }

  static String encodeCsv(List<WellnessViewingSession> sessions) {
    String cell(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final rows = <List<Object?>>[
      <Object?>[
        'session_id',
        'media_type',
        'source',
        'content_id',
        'series_id',
        'title',
        'subtitle',
        'started_at_utc',
        'ended_at_utc',
        'watched_seconds',
        'duration_seconds',
        'progress_percent',
        'completed',
        'provider',
        'genres',
        'languages',
        'countries',
        'network_bytes',
      ],
      for (final session in sessions.where((session) => !session.isDeleted))
        <Object?>[
          session.id,
          session.mediaType.name,
          session.source.name,
          session.contentId,
          session.seriesId,
          session.title,
          session.subtitle,
          session.startedAtUtc.toIso8601String(),
          session.endedAtUtc.toIso8601String(),
          (session.watchedMs / 1000).round(),
          (session.durationMs / 1000).round(),
          (session.progress * 100).toStringAsFixed(1),
          session.completed,
          session.provider,
          session.genres.join('|'),
          session.languages.join('|'),
          session.countries.join('|'),
          session.networkBytes,
        ],
    ];
    return rows.map((row) => row.map(cell).join(',')).join('\n');
  }
}

class _MutableDailySummary {
  _MutableDailySummary({required this.timezoneOffsetMinutes});

  final int timezoneOffsetMinutes;
  int watchedMs = 0;
  int movieMs = 0;
  int episodeMs = 0;
  int liveMs = 0;
  int completedMovies = 0;
  int completedEpisodes = 0;
  int sessionCount = 0;
  int updatedAtUtc = 0;

  void includeUpdatedAt(DateTime value) {
    final milliseconds = value.millisecondsSinceEpoch;
    if (milliseconds > updatedAtUtc) updatedAtUtc = milliseconds;
  }
}

String _dayKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Map<String, int> _dailyAllocations(WellnessViewingSession session) {
  if (session.segments.isEmpty) {
    final local = session.startedAtUtc.add(
      Duration(minutes: session.timezoneOffsetMinutes),
    );
    return <String, int>{_dayKey(local): session.watchedMs};
  }
  final allocations = <String, int>{};
  for (final segment in session.segments) {
    var cursor = segment.startedAtUtc.add(
      Duration(minutes: session.timezoneOffsetMinutes),
    );
    final end = segment.endedAtUtc.add(
      Duration(minutes: session.timezoneOffsetMinutes),
    );
    while (cursor.isBefore(end)) {
      final midnight = DateTime.utc(
        cursor.year,
        cursor.month,
        cursor.day + 1,
      );
      final sliceEnd = midnight.isBefore(end) ? midnight : end;
      final value = sliceEnd.difference(cursor).inMilliseconds;
      allocations.update(
        _dayKey(cursor),
        (existing) => existing + value,
        ifAbsent: () => value,
      );
      cursor = sliceEnd;
    }
  }
  return allocations;
}
