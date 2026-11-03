import 'sync_cursor.dart';
import '../../controllers/wellness_database_controller.dart';
import '../../core/storage/kv_store.dart';
import '../../core/time/server_clock.dart';
import '../playlists/playlist_store.dart';
import '../repositories/bookmark_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/recently_watched_repository.dart';
import '../repositories/wellness_repository.dart';
import 'bookmark_sync_engine.dart';
import 'library_scope.dart';
import 'local_library.dart';
import 'playlist_sync_engine.dart';
import 'recent_sync_engine.dart';
import 'sync_runner.dart';
import 'wellness_sync_engine.dart';

class LaravelSyncCoordinator {
  LaravelSyncCoordinator(
      {required this.bookmarkRepository,
      required this.recentRepository,
      required this.wellnessRepository,
      required this.store,
      required this.clock,
      required this.authenticatedOwner,
      this.playlistRepository,
      WellnessDatabaseController? wellness,
      Future<LocalLibrary> Function(String)? openLibrary,
      Future<PlaylistStore> Function(String)? openPlaylists})
      : wellness = wellness ?? WellnessDatabaseController.instance,
        _openLibrary = openLibrary ?? LocalLibrary.open,
        _openPlaylists = openPlaylists ?? PlaylistStore.forOwner {
    // Every bookmark answer is the account's whole library.
    bookmarks = SyncRunner(
        canSync: () => canSync,
        autoInterval: const Duration(minutes: 30),
        debounce: const Duration(seconds: 10),
        run: (owner, current) async {
          final db = await _openLibrary(owner);
          await BookmarkSyncEngine(bookmarkRepository)
              .sync(owner, db.movies, db.tv, isCurrent: current);
          if (current()) {
            await store.setInt(
                'sync.$owner.bookmarks.last_synced', clock.nowUtcMs());
          }
        });
    // The player saves on every play and pause, and each upload locks the
    // account on Laravel; leaving the app flushes what is waiting.
    recents = SyncRunner(
        canSync: () => canSync,
        autoInterval: const Duration(minutes: 5),
        debounce: const Duration(seconds: 30),
        run: (owner, current) async {
          final db = await _openLibrary(owner);
          await RecentSyncEngine(recentRepository, clock).sync(
              owner, db.recentMovies, db.recentEpisodes,
              isCurrent: current);
        });
    playlists = SyncRunner(
        canSync: () => canSync && playlistRepository != null,
        autoInterval: const Duration(minutes: 15),
        debounce: const Duration(seconds: 2),
        run: (owner, current) async {
          final more = await PlaylistSyncEngine(playlistRepository!)
              .sync(owner, await _openPlaylists(owner), isCurrent: current);
          if (current()) {
            await store.setInt(
                'sync.$owner.playlists.last_synced', clock.nowUtcMs());
            if (more) playlists.changed();
          }
        });
    wellnessSync = SyncRunner(
        canSync: () => canSync,
        autoInterval: const Duration(minutes: 15),
        debounce: const Duration(seconds: 5),
        run: (owner, current) =>
            WellnessSyncEngine(wellnessRepository, this.wellness, clock)
                .sync(owner, isCurrent: current));
  }
  final BookmarkRepository bookmarkRepository;

  /// Null where the app is built without custom-list sync (some tests).
  final PlaylistRepository? playlistRepository;
  final RecentlyWatchedRepository recentRepository;
  final WellnessRepository wellnessRepository;
  final KvStore store;
  final ServerClock clock;
  final String? Function() authenticatedOwner;
  final WellnessDatabaseController wellness;
  final Future<LocalLibrary> Function(String) _openLibrary;
  final Future<PlaylistStore> Function(String) _openPlaylists;
  late final SyncRunner bookmarks, recents, wellnessSync, playlists;

  /// [owner]'s custom lists on this device.
  Future<PlaylistStore> openPlaylists(String owner) => _openPlaylists(owner);
  bool get canSync =>
      LibraryScope.enabled &&
      authenticatedOwner() == LibraryScope.owner &&
      LibraryScope.owner.startsWith('user:');

  void activateOwner(String? owner) {
    if (LibraryScope.owner != (owner ?? 'guest')) {
      bookmarks.ownerChanged();
      playlists.ownerChanged();
      recents.ownerChanged();
      wellnessSync.ownerChanged();
    }
    LibraryScope.activate(owner);
    if (owner != null) {
      final stamp = store.getInt('sync.$owner.bookmarks.last_synced');
      bookmarks.lastSynced.value = stamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(stamp, isUtc: true);
      final listsStamp = store.getInt('sync.$owner.playlists.last_synced');
      playlists.lastSynced.value = listsStamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(listsStamp, isUtc: true);
      recents.lastSynced.value =
          SyncCursor.load(store, owner, 'recent').lastSyncAt;
      wellnessSync.lastSynced.value =
          SyncCursor.load(store, owner, 'wellness').lastSyncAt;
    }
  }

  /// What launch asks for: each kind syncs unless it did within its interval.
  /// A guest library still waiting to be cleared takes the full [syncAll].
  Future<void> autoSyncAll() async {
    if (store.getString('sync.guest.claimed_by') != null) {
      await syncAll();
      return;
    }
    await bookmarks.autoSync();
    await recents.autoSync();
    await wellnessSync.autoSync();
    await playlists.autoSync();
  }

  Future<bool> syncAll() async {
    final owner = authenticatedOwner();
    final bookmarkSuccess = await bookmarks.sync();
    final recentSuccess = await recents.sync();
    final wellnessSuccess = await wellnessSync.sync();
    // Lists are not part of the guest copy below, so they do not hold it up.
    await playlists.sync();
    final success = bookmarkSuccess && recentSuccess && wellnessSuccess;
    if (success && owner != null && authenticatedOwner() == owner) {
      await _clearGuestCopy(owner);
    }
    return success;
  }

  Future<void> mergeGuest(String owner) async {
    final claimed = store.getString('sync.guest.claimed_by');
    // Failed/offline merges remain assigned to the account that claimed them.
    if (claimed != null && claimed != owner) {
      await syncAll();
      return;
    }
    await store.setString('sync.guest.claimed_by', owner);
    final guest = await _openLibrary('guest');
    final account = await _openLibrary(owner);
    final copied = await guest.copyInto(account);
    await store.setJson('sync.guest.copied', copied);
    // Guest lists are only queued edits; they move as edits, keyed by id.
    if (playlistRepository != null) {
      await (await _openPlaylists('guest'))
          .moveInto(await _openPlaylists(owner));
    }
    await wellness.moveOwner(fromOwnerId: 'guest', toOwnerId: owner);
    await syncAll();
  }

  Future<void> _clearGuestCopy(String owner) async {
    if (store.getString('sync.guest.claimed_by') != owner) return;
    final raw = store.getJson('sync.guest.copied');
    if (raw is! List || raw.length != 4) return;
    final snapshots = raw
        .map((rows) => (rows as List)
            .map((row) => Map<String, dynamic>.from(row))
            .toList())
        .toList();
    await (await _openLibrary('guest')).clearCopied(snapshots);
    await store.remove('sync.guest.copied');
    await store.remove('sync.guest.claimed_by');
  }

  Future<void> deleteLocal(String owner) async {
    // Invalidate an old request before wiping its captured database handles.
    LibraryScope.generation++;
    await (await _openLibrary(owner)).clear();
    if (playlistRepository != null) await (await _openPlaylists(owner)).clear();
    await wellness.permanentlyDeleteOwner(owner);
    await store.removePrefix('sync.$owner.');
    if (store.getString('sync.guest.claimed_by') == owner) {
      await _clearGuestCopy(owner);
      await store.remove('sync.guest.claimed_by');
    }
  }

  void dispose() {
    bookmarks.dispose();
    playlists.dispose();
    recents.dispose();
    wellnessSync.dispose();
  }
}
