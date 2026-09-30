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

  UpNextBook get _book => _upNextBook ??= UpNextBook(
        store: _upNextStore ?? _defaultStore(),
        limit: upNextLimit,
      );

  static UpNextStore? _defaultStore() {
    try {
      return UpNextStore(sharedPrefsSingleton);
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

  Future<void> fetchMovies() async {
    _movies = await _movieController.getRecentMovieList();
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
    _episodes = await _episodeController.getEpisodeList();
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
