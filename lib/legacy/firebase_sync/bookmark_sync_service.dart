import '../../services/bookmark_sync_service.dart' show SyncStatus;
import '../../presentation/session/auth_runtime.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/bookmark_database_controller.dart';
import '../../models/movie.dart';
import '../../models/tv.dart';

class FirebaseBookmarkSyncService {
  FirebaseBookmarkSyncService._internal();
  static final FirebaseBookmarkSyncService instance =
      FirebaseBookmarkSyncService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MovieDatabaseController _movieDb = MovieDatabaseController();
  final TVDatabaseController _tvDb = TVDatabaseController();

  final ValueNotifier<SyncStatus> statusNotifier =
      ValueNotifier<SyncStatus>(SyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncedNotifier =
      ValueNotifier<DateTime?>(null);

  bool _isSyncing = false;
  static const String _lastSyncedKey = 'flixquest_last_bookmark_sync';

  /// The least time between automatic syncs for one account, e.g. each time
  /// the bookmarks screen opens.
  static const Duration _autoSyncInterval = Duration(minutes: 10);
  static const Duration _changeDebounceDelay = Duration(seconds: 3);

  Timer? _changeDebounce;
  String? _lastAutoSyncUid;
  DateTime? _lastAutoSyncAt;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastSyncedKey);
    if (millis != null) {
      lastSyncedNotifier.value = DateTime.fromMillisecondsSinceEpoch(millis);
    }

    _auth.authStateChanges().listen((user) {
      if (user != null && !user.isAnonymous) {
        autoSyncIfSignedIn();
      }
    });
  }

  User? get currentUser => _auth.currentUser;
  bool get canSync =>
      !AuthRuntime.enabled && currentUser != null && !currentUser!.isAnonymous;

  Future<bool> checkIfDocExists(String uid) async {
    try {
      final doc = await _firestore.collection('bookmarks-v2.0').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Unions this device's bookmarks into the cloud document and returns the
  /// merged lists. The document is read once and only written when the merge
  /// changed it, so a sync with nothing new costs a single read.
  Future<({List<Movie> movies, List<TV> tvShows})> _mergeLocalIntoCloud(
    String uid,
  ) async {
    final docRef = _firestore.collection('bookmarks-v2.0').doc(uid);
    final docSnapshot = await docRef.get();
    final docData = docSnapshot.data() ?? {};

    final cloudMovies = List<Map<String, dynamic>>.from(
      (docData['movies'] as List?) ?? [],
    ).map((m) => Movie.fromJson(m)).toList();
    final cloudTvs = List<Map<String, dynamic>>.from(
      (docData['tvShows'] as List?) ?? [],
    ).map((m) => TV.fromJson(m)).toList();

    final localMovies = await _movieDb.getMovieList();
    final localTvs = await _tvDb.getTVList();

    var changed = !docSnapshot.exists ||
        !docData.containsKey('movies') ||
        !docData.containsKey('tvShows');

    // Union by id, cloud first.
    final mergedMovies = <Movie>[...cloudMovies];
    for (final local in localMovies) {
      if (local.id != null &&
          !mergedMovies.any((item) => item.id == local.id)) {
        mergedMovies.add(local);
        changed = true;
      }
    }
    if (_keepGenres(mergedMovies, localMovies, (m) => m.id, (m) => m.genreIds,
        (m, ids) => m.genreIds = ids)) {
      changed = true;
    }

    final mergedTvs = <TV>[...cloudTvs];
    for (final local in localTvs) {
      if (local.id != null && !mergedTvs.any((item) => item.id == local.id)) {
        mergedTvs.add(local);
        changed = true;
      }
    }
    if (_keepGenres(mergedTvs, localTvs, (t) => t.id, (t) => t.genreIds,
        (t, ids) => t.genreIds = ids)) {
      changed = true;
    }

    if (changed) {
      await docRef.set({
        'movies': mergedMovies.map((m) => m.toMap()).toList(),
        'tvShows': mergedTvs.map((t) => t.toMap()).toList(),
      }, SetOptions(merge: true));
    }
    return (movies: mergedMovies, tvShows: mergedTvs);
  }

  /// Triggers a background 2-way sync if the user is signed in and not
  /// anonymous. Repeats for the same account within [_autoSyncInterval] are
  /// skipped; a bookmark change pushes on its own.
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

  /// Schedules a sync after local bookmarks change, coalescing quick toggles
  /// into one.
  Future<void> onBookmarkChanged() async {
    if (!canSync) return;
    _changeDebounce?.cancel();
    _changeDebounce = Timer(_changeDebounceDelay, () => unawaited(syncNow()));
  }

  /// Performs a full 2-way merge sync between local SQLite DB and Firestore.
  Future<bool> syncNow({bool force = false}) async {
    if (!canSync) return false;
    if (_isSyncing && !force) return false;

    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;

    try {
      final uid = currentUser!.uid;
      final merged = await _mergeLocalIntoCloud(uid);

      // Insert missing cloud items into Local SQLite
      for (final movie in merged.movies) {
        if (movie.id != null) {
          final exists = await _movieDb.contain(movie.id!);
          if (!exists) {
            await _movieDb.insertMovie(movie);
          } else {
            await _movieDb.backfillGenreIds(movie.id!, movie.genreIds);
          }
        }
      }

      for (final tv in merged.tvShows) {
        if (tv.id != null) {
          final exists = await _tvDb.contain(tv.id!);
          if (!exists) {
            await _tvDb.insertTV(tv);
          } else {
            await _tvDb.backfillGenreIds(tv.id!, tv.genreIds);
          }
        }
      }

      final now = DateTime.now();
      lastSyncedNotifier.value = now;
      statusNotifier.value = SyncStatus.success;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncedKey, now.millisecondsSinceEpoch);

      return true;
    } catch (e, stack) {
      if (kDebugMode) {
        print('FirebaseBookmarkSyncService Error: $e\n$stack');
      }
      statusNotifier.value = SyncStatus.error;
      return false;
    } finally {
      _isSyncing = false;
      if (statusNotifier.value == SyncStatus.syncing) {
        statusNotifier.value = SyncStatus.idle;
      }
    }
  }

  /// Syncs only offline/local bookmarks up to cloud.
  Future<bool> pushLocalToCloud() async {
    if (!canSync) return false;
    try {
      await _mergeLocalIntoCloud(currentUser!.uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Syncs cloud bookmarks down to local SQLite DB.
  Future<bool> pullCloudToLocal() async {
    if (!canSync) return false;
    try {
      final uid = currentUser!.uid;
      final docRef = _firestore.collection('bookmarks-v2.0').doc(uid);
      final docSnapshot = await docRef.get();
      final docData = docSnapshot.data() ?? {};

      final cloudMovieMaps = List<Map<String, dynamic>>.from(
        (docData['movies'] as List?) ?? [],
      );
      final cloudTvMaps = List<Map<String, dynamic>>.from(
        (docData['tvShows'] as List?) ?? [],
      );

      for (final map in cloudMovieMaps) {
        final movie = Movie.fromJson(map);
        if (movie.id != null) {
          final exists = await _movieDb.contain(movie.id!);
          if (!exists) {
            await _movieDb.insertMovie(movie);
          } else {
            await _movieDb.backfillGenreIds(movie.id!, movie.genreIds);
          }
        }
      }

      for (final map in cloudTvMaps) {
        final tv = TV.fromJson(map);
        if (tv.id != null) {
          final exists = await _tvDb.contain(tv.id!);
          if (!exists) {
            await _tvDb.insertTV(tv);
          } else {
            await _tvDb.backfillGenreIds(tv.id!, tv.genreIds);
          }
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes a movie from Firestore cloud document array.
  Future<bool> deleteMovieFromCloud(int movieId) async {
    if (!canSync) return false;
    try {
      final uid = currentUser!.uid;
      final docRef = _firestore.collection('bookmarks-v2.0').doc(uid);
      final docSnapshot = await docRef.get();
      final docData = docSnapshot.data() ?? {};

      final movies = List<Map<String, dynamic>>.from(
        (docData['movies'] as List?) ?? [],
      );

      movies.removeWhere((item) => item['id'] == movieId);
      await docRef.update({'movies': movies});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes a TV show from Firestore cloud document array.
  Future<bool> deleteTVFromCloud(int tvId) async {
    if (!canSync) return false;
    try {
      final uid = currentUser!.uid;
      final docRef = _firestore.collection('bookmarks-v2.0').doc(uid);
      final docSnapshot = await docRef.get();
      final docData = docSnapshot.data() ?? {};

      final tvShows = List<Map<String, dynamic>>.from(
        (docData['tvShows'] as List?) ?? [],
      );

      tvShows.removeWhere((item) => item['id'] == tvId);
      await docRef.update({'tvShows': tvShows});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A cloud copy written before genres were kept has none; take them from
  /// the same title's local row, so the merge doesn't drop them. Returns
  /// whether any item gained genres.
  bool _keepGenres<T>(
    List<T> merged,
    List<T> local,
    int? Function(T item) idOf,
    List<int>? Function(T item) genresOf,
    void Function(T item, List<int> ids) setGenres,
  ) {
    final known = <int, List<int>>{
      for (final item in local)
        if (idOf(item) case final id?)
          if (genresOf(item) case final ids? when ids.isNotEmpty) id: ids,
    };
    var changed = false;
    for (final item in merged) {
      final ids = known[idOf(item)];
      if (ids != null && (genresOf(item)?.isEmpty ?? true)) {
        setGenres(item, ids);
        changed = true;
      }
    }
    return changed;
  }
}
