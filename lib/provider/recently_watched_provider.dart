import '../data/sync/library_scope.dart';
import 'package:flutter/material.dart';

import '../catalog/up_next.dart';
import '../constants/app_constants.dart';
import '../controllers/recently_watched_database_controller.dart';
import '../models/recently_watched.dart';
import '../services/recently_watched_sync_service.dart';

class RecentProvider extends ChangeNotifier {
  RecentProvider({UpNextStore? upNextStore}) : _upNextStore = upNextStore {
    RecentlyWatchedSyncService.instance.statusNotifier
        .addListener(_onSyncStatusChanged);
  }

  final RecentlyWatchedMoviesController _movieController =
      RecentlyWatchedMoviesController();
  final RecentlyWatchedEpisodeController _episodeController =
      RecentlyWatchedEpisodeController();

  List<RecentMovie> _movies = [];
  List<RecentMovie> get movies => _movies;

  List<RecentEpisode> _episodes = [];
  List<RecentEpisode> get episodes => _episodes;

  final UpNextStore? _upNextStore;
  UpNextBook? _upNextBook;

  /// The most series [upNext] remembers; the oldest go first.
  static const upNextLimit = 50;

  String? _bookOwner;
  UpNextBook get _book {
    final owner = LibraryScope.enabled ? LibraryScope.owner : 'guest';
    if (_bookOwner != owner && _upNextStore == null) _upNextBook = null;
    _bookOwner = owner;
    return _upNextBook ??= UpNextBook(
        store: _upNextStore ?? _defaultStore(),
        limit: upNextLimit,
      );
  }

  static UpNextStore? _defaultStore() {
    try {
      return UpNextStore(sharedPrefsSingleton, storageKey: LibraryScope.enabled
          ? 'sync.${LibraryScope.owner}.up_next' : UpNextStore.key,
          kvStore: LibraryScope.enabled ? LibraryScope.store : null);
    } catch (_) {
      // Preferences aren't ready: keep them in memory.
      return null;
    }
  }

  /// For each series whose latest episode was finished, the one after it.
  /// Kept on this device only.
  List<UpNext> get upNext => _book.entries;

  /// A finished merge may have pulled progress from another device, so reload
  /// both lists to show it.
  void _onSyncStatusChanged() {
    if (RecentlyWatchedSyncService.instance.statusNotifier.value !=
        RecentSyncStatus.success) {
      return;
    }
    fetchMovies();
    fetchEpisodes();
  }

  void resetForOwner() {
    _movies = []; _episodes = []; _upNextBook = null; notifyListeners();
  }

  Future<void> fetchMovies() async {
    final owner = LibraryScope.owner; final generation = LibraryScope.generation;
    final db = await _movieController.databaseForOwner(owner);
    final movies = (await db.query(_movieController.tableName,
        where: 'deleted_at_utc IS NULL', orderBy: 'date_watched DESC'))
        .map(RecentMovie.fromMapObject).toList();
    if (generation != LibraryScope.generation) return;
    _movies = movies;
    notifyListeners();
  }

  Future<void> addMovie(RecentMovie movie) async {
    await _movieController.insertMovie(movie);
    await fetchMovies();
    RecentlyWatchedSyncService.instance.onRecentChanged();
  }

  Future<void> updateMovie(RecentMovie movie, int id) async {
    await _movieController.updateMovie(movie, id);
    await fetchMovies();
    RecentlyWatchedSyncService.instance.onRecentChanged();
  }

  /// Keeps a tombstone instead of dropping the row so the removal reaches the
  /// user's other devices rather than being undone by their next sync.
  Future<void> deleteMovie(int id) async {
    await _movieController.tombstoneMovie(id);
    await fetchMovies();
    RecentlyWatchedSyncService.instance.onRecentChanged();
  }

  /// Episode

  Future<void> fetchEpisodes() async {
    final owner = LibraryScope.owner; final generation = LibraryScope.generation;
    final db = await _episodeController.databaseForOwner(owner);
    final episodes = (await db.query(_episodeController.tableName,
        where: 'deleted_at_utc IS NULL', orderBy: 'date_added DESC'))
        .map(RecentEpisode.fromMapObject).toList();
    if (generation != LibraryScope.generation) return;
    _episodes = episodes;
    _book.reload();
    notifyListeners();
  }

  /// Remembers [entry] as the series' next episode, replacing any before.
  Future<void> recordUpNext(UpNext entry) async {
    final saved = _book.record(entry);
    notifyListeners();
    await saved;
  }

  /// Forgets [seriesId]'s next episode: the series is done, or was taken off
  /// Continue Watching.
  Future<void> clearUpNext(int seriesId) async {
    if (await _book.clear(seriesId)) notifyListeners();
  }

  Future<void> addEpisode(RecentEpisode episode) async {
    await _episodeController.insertTV(episode);
    await fetchEpisodes();
    RecentlyWatchedSyncService.instance.onRecentChanged();
  }

  Future<void> updateEpisode(
      RecentEpisode episode, int id, int episodeNum, int seasonNum) async {
    await _episodeController.updateTV(episode, id, episodeNum, seasonNum);
    await fetchEpisodes();
    RecentlyWatchedSyncService.instance.onRecentChanged();
  }

  /// See [deleteMovie] for why this tombstones rather than deletes.
  Future<void> deleteEpisode(int id, int episodeNum, int seasonNum) async {
    await _episodeController.tombstoneTV(id, episodeNum, seasonNum);
    await fetchEpisodes();
    RecentlyWatchedSyncService.instance.onRecentChanged();
  }

  @override
  void dispose() {
    RecentlyWatchedSyncService.instance.statusNotifier
        .removeListener(_onSyncStatusChanged);
    super.dispose();
  }
}
