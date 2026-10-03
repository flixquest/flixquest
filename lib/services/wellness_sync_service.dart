import '../presentation/session/auth_runtime.dart';
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/wellness_database_controller.dart';
import '../models/wellness.dart';
import 'sync_checkpoint.dart';

enum WellnessSyncStatus { idle, syncing, success, error }

/// The daily-summary writes that bring the cloud in line with [local], given
/// the `updatedAtUtc` of each day the cloud holds according to [ledger].
///
/// Days missing locally are deleted; days whose stamp differs are written.
({List<String> deletes, List<String> sets}) planDailyWrites({
  required Map<String, int?> ledger,
  required Map<String, int?> local,
}) =>
    (
      deletes: <String>[
        for (final day in ledger.keys)
          if (!local.containsKey(day)) day,
      ],
      sets: <String>[
        for (final entry in local.entries)
          if (!ledger.containsKey(entry.key) || ledger[entry.key] != entry.value)
            entry.key,
      ],
    );

/// Keeps a signed-in user's Viewing Insights in step across devices.
///
/// Sessions are pulled as a delta since the previous pull (see
/// [SyncCheckpoint]), and the daily summaries are diffed against a local
/// ledger of what was last written, so a routine sync reads next to nothing
/// however long the user's history is.
class WellnessSyncService {
  WellnessSyncService({
    WellnessDatabaseController? database,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _database = database ?? WellnessDatabaseController.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final WellnessDatabaseController _database;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _syncing = false;
  bool _pushRequested = false;

  static const String _dailyLedgerKey = 'wellness.daily_ledger.v1';

  final ValueNotifier<WellnessSyncStatus> status =
      ValueNotifier<WellnessSyncStatus>(WellnessSyncStatus.idle);
  final ValueNotifier<DateTime?> lastSynced = ValueNotifier<DateTime?>(null);

  User? get currentUser => _auth.currentUser;
  bool get canSync => !AuthRuntime.enabled && currentUser != null && !currentUser!.isAnonymous;
  String? get currentUid => canSync ? currentUser!.uid : null;

  /// Pulls sessions other devices wrote since the last pull, then pushes this
  /// device's changes.
  Future<bool> syncNow() => _run(pull: true);

  /// Pushes this device's changes without pulling. Costs no reads once the
  /// daily ledger exists, so it suits the player's save path.
  Future<bool> pushPending() => _run(pull: false);

  Future<bool> _run({required bool pull}) async {
    if (!canSync) return false;
    if (_syncing) {
      // Whatever prompted this call has already been written locally; make
      // sure it goes up once the current run is done.
      _pushRequested = true;
      return false;
    }
    _syncing = true;
    status.value = WellnessSyncStatus.syncing;
    final uid = currentUser!.uid;
    final ownerId = 'user:$uid';
    debugPrint('[WellnessSync] sync start uid=$uid pull=$pull');
    try {
      final collection =
          _firestore.collection('wellness-v1').doc(uid).collection('sessions');
      final pulledFull = pull && await _pullSessions(uid, ownerId, collection);

      final pending = await _database.pendingSessions(ownerId);
      debugPrint('[WellnessSync] uploading ${pending.length} pending sessions');
      for (var offset = 0; offset < pending.length; offset += 450) {
        final chunk = pending.skip(offset).take(450).toList(growable: false);
        final batch = _firestore.batch();
        for (final session in chunk) {
          batch.set(
            collection.doc(session.id),
            <String, dynamic>{
              ...session.toCloudMap(),
              syncedAtField: FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
        await _database.markSynced(
          ownerId,
          chunk.map((session) => session.id),
        );
      }
      debugPrint('[WellnessSync] sessions uploaded to cloud');
      await _syncDailySummaries(uid, ownerId, reseed: pulledFull);
      lastSynced.value = DateTime.now();
      status.value = WellnessSyncStatus.success;
      debugPrint('[WellnessSync] sync success');
      return true;
    } catch (error, stackTrace) {
      debugPrint('[WellnessSync] sync FAILED: $error');
      debugPrintStack(stackTrace: stackTrace, label: '[WellnessSync]');
      status.value = WellnessSyncStatus.error;
      return false;
    } finally {
      _syncing = false;
      if (status.value == WellnessSyncStatus.syncing) {
        status.value = WellnessSyncStatus.idle;
      }
      if (_pushRequested) {
        _pushRequested = false;
        unawaited(pushPending());
      }
    }
  }

  /// Applies cloud sessions written since the last pull. Returns whether the
  /// whole collection was read.
  Future<bool> _pullSessions(
    String uid,
    String ownerId,
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final scope = 'wellness.$uid.sessions';
    final checkpoint = await SyncCheckpoint.load(scope);
    final now = DateTime.now();
    final full = checkpoint.needsFullPull(now);
    final cloudSnapshot = await checkpoint.pull(collection, full: full);
    debugPrint(
      '[WellnessSync] read cloud sessions: ${cloudSnapshot.docs.length} '
      '(${full ? 'full' : 'delta'})',
    );
    if (cloudSnapshot.docs.isNotEmpty) {
      final localSessions = await _database.sessionsForOwner(
        ownerId,
        includeDeleted: true,
      );
      final localById = <String, WellnessViewingSession>{
        for (final session in localSessions) session.id: session,
      };
      final pulled = <WellnessViewingSession>[];
      for (final doc in cloudSnapshot.docs) {
        final cloud = WellnessViewingSession.fromMap(<String, dynamic>{
          ...doc.data(),
          'id': doc.id,
          'ownerId': ownerId,
          'synced': true,
        });
        final local = localById[cloud.id];
        if (local == null || !local.updatedAtUtc.isAfter(cloud.updatedAtUtc)) {
          pulled.add(cloud.copyWith(synced: true));
        }
      }
      if (pulled.isNotEmpty) {
        await _database.upsertSessions(pulled, ownerId: ownerId);
        debugPrint('[WellnessSync] applied ${pulled.length} pulled sessions');
      }
    }
    await checkpoint
        .advance(cloudSnapshot.docs.map((doc) => doc.data()), full: full, now: now)
        .save(scope);
    return full;
  }

  /// Writes the daily summaries that changed since the last run.
  ///
  /// What the cloud holds is remembered in a local ledger, so the remote
  /// collection is only read when there is no ledger yet or on a [reseed],
  /// which follows each periodic full session pull and catches writes from
  /// other devices the ledger missed.
  Future<void> _syncDailySummaries(
    String uid,
    String ownerId, {
    required bool reseed,
  }) async {
    final summaries = await _database.dailySummaries(ownerId);
    final collection =
        _firestore.collection('wellness-v1').doc(uid).collection('daily');
    var ledger = reseed ? null : await _loadDailyLedger(uid);
    if (ledger == null) {
      final remote = await collection.get();
      ledger = <String, int?>{
        for (final doc in remote.docs)
          doc.id: (doc.data()['updatedAtUtc'] as num?)?.toInt(),
      };
    }
    final summaryByDay = <String, Map<String, dynamic>>{
      for (final summary in summaries) summary['local_day'].toString(): summary,
    };
    final plan = planDailyWrites(
      ledger: ledger,
      local: <String, int?>{
        for (final entry in summaryByDay.entries)
          entry.key: (entry.value['updated_at_utc'] as num?)?.toInt(),
      },
    );
    final operations = <_DailyWrite>[
      for (final day in plan.deletes) _DailyWrite.delete(collection.doc(day)),
      for (final day in plan.sets)
        if (summaryByDay[day] case final summary?)
          _DailyWrite.set(
            collection.doc(day),
            <String, dynamic>{
              'localDay': summary['local_day'],
              'timezoneOffsetMinutes': summary['timezone_offset_minutes'],
              'watchedMs': summary['watched_ms'],
              'movieMs': summary['movie_ms'],
              'episodeMs': summary['episode_ms'],
              'liveMs': summary['live_ms'],
              'completedMovies': summary['completed_movies'],
              'completedEpisodes': summary['completed_episodes'],
              'sessionCount': summary['session_count'],
              'updatedAtUtc': summary['updated_at_utc'],
            },
          ),
    ];
    for (var offset = 0; offset < operations.length; offset += 450) {
      final batch = _firestore.batch();
      for (final operation in operations.skip(offset).take(450)) {
        if (operation.data == null) {
          batch.delete(operation.reference);
        } else {
          batch.set(operation.reference, operation.data!);
        }
      }
      await batch.commit();
    }
    await _saveDailyLedger(uid, <String, int?>{
      for (final entry in summaryByDay.entries)
        entry.key: (entry.value['updated_at_utc'] as num?)?.toInt(),
    });
  }

  Future<Map<String, int?>?> _loadDailyLedger(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_dailyLedgerKey.$uid');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (day, stamp) => MapEntry(day, (stamp as num?)?.toInt()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDailyLedger(String uid, Map<String, int?> ledger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_dailyLedgerKey.$uid', jsonEncode(ledger));
  }

  Future<void> deleteRemoteAccountData(String uid) async {
    for (final child in const <String>['sessions', 'daily']) {
      final collection =
          _firestore.collection('wellness-v1').doc(uid).collection(child);
      while (true) {
        final snapshot = await collection.limit(450).get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _firestore.collection('wellness-v1').doc(uid).delete();
    await SyncCheckpoint.clear('wellness.$uid.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_dailyLedgerKey.$uid');
  }
}

class _DailyWrite {
  const _DailyWrite._(this.reference, this.data);

  factory _DailyWrite.delete(DocumentReference<Map<String, dynamic>> ref) =>
      _DailyWrite._(ref, null);

  factory _DailyWrite.set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) =>
      _DailyWrite._(ref, data);

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic>? data;
}
