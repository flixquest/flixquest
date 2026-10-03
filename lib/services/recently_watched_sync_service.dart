import '../presentation/session/auth_runtime.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/recently_watched_database_controller.dart';
import '../models/recently_watched.dart';
import 'sync_checkpoint.dart';

enum RecentSyncStatus { idle, syncing, success, error }

/// Decides which cloud rows win a two-way last-write-wins merge.
///
/// A cloud row wins when its version stamp is newer than the local copy's, or
/// when this device has no copy at all. Cloud tombstones for ids the device has
/// never stored are skipped: there is no local row to suppress, so pulling them
/// would only accumulate dead rows on a device that never watched the title.
Set<int> resolveCloudWinners({
  required Map<int, int> cloudVersions,
  required Map<int, int> localVersions,
  Set<int> cloudDeleted = const <int>{},
}) {
  final winners = <int>{};
  for (final entry in cloudVersions.entries) {
    final localVersion = localVersions[entry.key];
    if (localVersion == null) {
      if (!cloudDeleted.contains(entry.key)) winners.add(entry.key);
      continue;
    }
    if (entry.value > localVersion) winners.add(entry.key);
  }
  return winners;
}

/// Keeps the home screen's "continue watching" rows in step across a signed-in
/// user's devices.
///
/// Progress is mutable state, so this cannot use the union merge that
/// [BookmarkSyncService] applies to bookmarks: every row carries a UTC version
/// stamp and the newest write for an id wins, while removals travel as
/// tombstones so a title finished on one device does not come back from
/// another. Each row is its own Firestore document, which keeps concurrent
/// progress writes from overwriting one another.
///
/// Pulls read only the documents written since the previous pull (see
/// [SyncCheckpoint]), so an app resume costs a couple of reads rather than the
/// user's whole history.
class RecentlyWatchedSyncService {
  RecentlyWatchedSyncService._internal();

  static final RecentlyWatchedSyncService instance =
      RecentlyWatchedSyncService._internal();

  static const String collectionName = 'recently-watched-v1';
  static const String _moviesCollection = 'movies';
  static const String _episodesCollection = 'episodes';
  static const String _lastSyncedKey = 'flixquest_last_recently_watched_sync';
  static const String _prunedAtKey = 'recently_watched.pruned_at.v1';

  /// Firestore rejects batches larger than 500 writes.
  static const int _batchLimit = 450;

  /// How long a tombstone is kept before both stores drop it. Long enough that
  /// a device which has been offline for weeks still learns about a removal.
  static const Duration _tombstoneRetention = Duration(days: 90);

  /// Progress is saved on discrete player events (exit, backgrounding,
  /// fullscreen changes), so a short debounce coalesces bursts without making
  /// the other devices wait.
  static const Duration _pushDebounce = Duration(seconds: 5);

  static const Duration _operationTimeout = Duration(seconds: 45);

  /// The least time between automatic merges. iOS reports a resume after
  /// every passing interruption, and each merge still costs a few reads.
  static const Duration _autoSyncInterval = Duration(minutes: 2);

  /// Tombstones live for [_tombstoneRetention], so looking for expired ones
  /// once a day is plenty and saves two queries on every other merge.
  static const Duration _pruneInterval = Duration(days: 1);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RecentlyWatchedMoviesController _movieDb =
      RecentlyWatchedMoviesController();
  final RecentlyWatchedEpisodeController _episodeDb =
      RecentlyWatchedEpisodeController();

  final ValueNotifier<RecentSyncStatus> statusNotifier =
      ValueNotifier<RecentSyncStatus>(RecentSyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncedNotifier =
      ValueNotifier<DateTime?>(null);

  Timer? _pushTimer;
  bool _isSyncing = false;
  String? _lastAutoSyncUid;
  DateTime? _lastAutoSyncAt;
  StreamSubscription<User?>? _authSubscription;

  User? get currentUser => _auth.currentUser;
  bool get canSync => !AuthRuntime.enabled && currentUser != null && !currentUser!.isAnonymous;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastSyncedKey);
    if (millis != null) {
      lastSyncedNotifier.value = DateTime.fromMillisecondsSinceEpoch(millis);
    }

    // The stream replays the current user on subscription, so this covers both
    // a fresh sign-in and an app launch that is already signed in.
    _authSubscription ??= _auth.authStateChanges().listen((user) {
      if (user != null && !user.isAnonymous) {
        unawaited(autoSyncIfSignedIn());
      }
    });
  }

  /// Runs a full merge when a signed-in user is present. Safe to call often;
  /// concurrent runs are dropped, as are repeats within [_autoSyncInterval].
  Future<void> autoSyncIfSignedIn() async {
    if (!canSync || _isSyncing) return;
    final uid = currentUser!.uid;
    final lastAt = _lastAutoSyncAt;
    if (_lastAutoSyncUid == uid &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < _autoSyncInterval) {
      return;
    }
    if (await syncNow()) {
      _lastAutoSyncUid = uid;
      _lastAutoSyncAt = DateTime.now();
    }
  }

  /// Schedules a debounced push after the player or the user changes a row.
  void onRecentChanged() {
    if (!canSync) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(_pushDebounce, () => unawaited(pushPendingNow()));
  }

  /// Sends a scheduled push right away, e.g. when the app is backgrounded.
  ///
  /// A pending timer is the signal that something actually changed, and iOS
  /// reports a lifecycle change for every passing interruption, so without that
  /// check this would run on each of them for nothing.
  Future<void> flushPending() async {
    if (_pushTimer == null) return;
    _pushTimer!.cancel();
    _pushTimer = null;
    await pushPendingNow();
  }

  /// Uploads local rows that have not reached the cloud yet, tombstones
  /// included. Does not pull, so it stays cheap on the player's save path.
  Future<bool> pushPendingNow() async {
    if (!canSync || _isSyncing) return false;
    _isSyncing = true;
    statusNotifier.value = RecentSyncStatus.syncing;
    try {
      final uid = currentUser!.uid;
      await _pushMovies(uid).timeout(_operationTimeout);
      await _pushEpisodes(uid).timeout(_operationTimeout);
      await _recordSuccess();
      return true;
    } catch (error, stackTrace) {
      _recordFailure(error, stackTrace);
      return false;
    } finally {
      _finishRun();
    }
  }

  /// Full two-way merge: pull rows that other devices changed since the last
  /// pull, push local changes, then drop tombstones both stores have finished
  /// with.
  Future<bool> syncNow({bool force = false}) async {
    if (!canSync) return false;
    if (_isSyncing && !force) return false;

    _pushTimer?.cancel();
    _pushTimer = null;
    _isSyncing = true;
    statusNotifier.value = RecentSyncStatus.syncing;

    try {
      final uid = currentUser!.uid;
      await _pullMovies(uid).timeout(_operationTimeout);
      await _pullEpisodes(uid).timeout(_operationTimeout);
      await _pushMovies(uid).timeout(_operationTimeout);
      await _pushEpisodes(uid).timeout(_operationTimeout);
      await _pruneTombstones(uid).timeout(_operationTimeout);
      await _recordSuccess();
      return true;
    } catch (error, stackTrace) {
      _recordFailure(error, stackTrace);
      return false;
    } finally {
      _finishRun();
    }
  }

  CollectionReference<Map<String, dynamic>> _movies(String uid) => _firestore
      .collection(collectionName)
      .doc(uid)
      .collection(_moviesCollection);

  CollectionReference<Map<String, dynamic>> _episodes(String uid) => _firestore
      .collection(collectionName)
      .doc(uid)
      .collection(_episodesCollection);

  static String _checkpointScope(String uid, String collection) =>
      'recently_watched.$uid.$collection';

  Future<void> _pullMovies(String uid) async {
    final scope = _checkpointScope(uid, _moviesCollection);
    final checkpoint = await SyncCheckpoint.load(scope);
    final now = DateTime.now();
    final full = checkpoint.needsFullPull(now);
    final snapshot = await checkpoint.pull(_movies(uid), full: full);
    if (snapshot.docs.isNotEmpty) await _applyCloudMovies(snapshot.docs);
    await checkpoint
        .advance(snapshot.docs.map((doc) => doc.data()), full: full, now: now)
        .save(scope);
  }

  Future<void> _applyCloudMovies(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {

    final cloudById = <int, RecentMovie>{};
    for (final doc in docs) {
      final movie = RecentMovie.fromCloudMap(doc.data(), id: int.tryParse(doc.id));
      if (movie.id != null) cloudById[movie.id!] = movie;
    }

    final local = await _movieDb.allMovies();
    final winners = resolveCloudWinners(
      cloudVersions: <int, int>{
        for (final entry in cloudById.entries) entry.key: entry.value.updatedAtUtc,
      },
      localVersions: <int, int>{
        for (final movie in local)
          if (movie.id != null) movie.id!: movie.updatedAtUtc,
      },
      cloudDeleted: <int>{
        for (final entry in cloudById.entries)
          if (entry.value.isDeleted) entry.key,
      },
    );

    await _movieDb.upsertFromCloud(
      [for (final id in winners) cloudById[id]!],
    );
  }

  Future<void> _pullEpisodes(String uid) async {
    final scope = _checkpointScope(uid, _episodesCollection);
    final checkpoint = await SyncCheckpoint.load(scope);
    final now = DateTime.now();
    final full = checkpoint.needsFullPull(now);
    final snapshot = await checkpoint.pull(_episodes(uid), full: full);
    if (snapshot.docs.isNotEmpty) await _applyCloudEpisodes(snapshot.docs);
    await checkpoint
        .advance(snapshot.docs.map((doc) => doc.data()), full: full, now: now)
        .save(scope);
  }

  Future<void> _applyCloudEpisodes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {

    final cloudById = <int, RecentEpisode>{};
    for (final doc in docs) {
      final episode =
          RecentEpisode.fromCloudMap(doc.data(), id: int.tryParse(doc.id));
      if (episode.id != null) cloudById[episode.id!] = episode;
    }

    final local = await _episodeDb.allEpisodes();
    final winners = resolveCloudWinners(
      cloudVersions: <int, int>{
        for (final entry in cloudById.entries) entry.key: entry.value.updatedAtUtc,
      },
      localVersions: <int, int>{
        for (final episode in local)
          if (episode.id != null) episode.id!: episode.updatedAtUtc,
      },
      cloudDeleted: <int>{
        for (final entry in cloudById.entries)
          if (entry.value.isDeleted) entry.key,
      },
    );

    await _episodeDb.upsertFromCloud(
      [for (final id in winners) cloudById[id]!],
    );
  }

  Future<void> _pushMovies(String uid) async {
    final pending = await _movieDb.pendingMovies();
    final rows = pending.where((movie) => movie.id != null).toList();
    if (rows.isEmpty) return;

    final collection = _movies(uid);
    for (var offset = 0; offset < rows.length; offset += _batchLimit) {
      final chunk = rows.skip(offset).take(_batchLimit).toList(growable: false);
      final batch = _firestore.batch();
      for (final movie in chunk) {
        batch.set(
          collection.doc(movie.id!.toString()),
          <String, dynamic>{
            ...movie.toCloudMap(),
            syncedAtField: FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      await _movieDb.markSynced(chunk.map((movie) => movie.id!));
    }
  }

  Future<void> _pushEpisodes(String uid) async {
    final pending = await _episodeDb.pendingEpisodes();
    final rows = pending.where((episode) => episode.id != null).toList();
    if (rows.isEmpty) return;

    final collection = _episodes(uid);
    for (var offset = 0; offset < rows.length; offset += _batchLimit) {
      final chunk = rows.skip(offset).take(_batchLimit).toList(growable: false);
      final batch = _firestore.batch();
      for (final episode in chunk) {
        batch.set(
          collection.doc(episode.id!.toString()),
          <String, dynamic>{
            ...episode.toCloudMap(),
            syncedAtField: FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      await _episodeDb.markSynced(chunk.map((episode) => episode.id!));
    }
  }

  /// Cloud first, then local: dropping the local row while the cloud tombstone
  /// is still there would only make the next pull write it back.
  ///
  /// Runs at most once per [_pruneInterval] for each account.
  Future<void> _pruneTombstones(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final prunedKey = '$_prunedAtKey.$uid';
    final now = DateTime.now();
    final prunedAt = prefs.getInt(prunedKey);
    if (prunedAt != null) {
      final since =
          now.difference(DateTime.fromMillisecondsSinceEpoch(prunedAt));
      if (!since.isNegative && since < _pruneInterval) return;
    }

    final cutoff =
        now.toUtc().subtract(_tombstoneRetention).millisecondsSinceEpoch;

    for (final collection in <CollectionReference<Map<String, dynamic>>>[
      _movies(uid),
      _episodes(uid),
    ]) {
      // The lower bound matters: Firestore sorts null below every number, so
      // `deletedAtUtc < cutoff` on its own would also match live rows, whose
      // field is explicitly null. A page per sync is plenty for this volume.
      final stale = await collection
          .where('deletedAtUtc', isGreaterThan: 0)
          .where('deletedAtUtc', isLessThan: cutoff)
          .limit(_batchLimit)
          .get();
      if (stale.docs.isEmpty) continue;
      final batch = _firestore.batch();
      for (final doc in stale.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await _movieDb.prunedTombstones(cutoff);
    await _episodeDb.prunedTombstones(cutoff);
    await prefs.setInt(prunedKey, now.millisecondsSinceEpoch);
  }

  Future<void> _recordSuccess() async {
    final now = DateTime.now();
    lastSyncedNotifier.value = now;
    statusNotifier.value = RecentSyncStatus.success;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncedKey, now.millisecondsSinceEpoch);
  }

  void _recordFailure(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('Recently watched sync failed: $error\n$stackTrace');
    }
    statusNotifier.value = RecentSyncStatus.error;
  }

  void _finishRun() {
    _isSyncing = false;
    if (statusNotifier.value == RecentSyncStatus.syncing) {
      statusNotifier.value = RecentSyncStatus.idle;
    }
  }

  /// Removes the account's progress from the cloud and from this device, then
  /// nudges listeners so the home screens drop the rows they are still showing.
  /// Called while deleting an account, before the Firebase user goes away.
  Future<void> deleteAccountData(String uid) async {
    await deleteRemoteAccountData(uid);
    await _movieDb.clear();
    await _episodeDb.clear();
    await SyncCheckpoint.clear('recently_watched.$uid.');
    _lastAutoSyncUid = null;
    // A ValueNotifier stays quiet when the value does not change, so step
    // through idle to guarantee listeners see the success edge and reload.
    statusNotifier.value = RecentSyncStatus.idle;
    statusNotifier.value = RecentSyncStatus.success;
  }

  /// Removes the account's cloud progress but leaves this device untouched.
  Future<void> deleteRemoteAccountData(String uid) async {
    for (final child in const <String>[_moviesCollection, _episodesCollection]) {
      final collection =
          _firestore.collection(collectionName).doc(uid).collection(child);
      while (true) {
        final snapshot = await collection.limit(_batchLimit).get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _firestore.collection(collectionName).doc(uid).delete();
  }

  @visibleForTesting
  void dispose() {
    _pushTimer?.cancel();
    _authSubscription?.cancel();
    _authSubscription = null;
  }
}
