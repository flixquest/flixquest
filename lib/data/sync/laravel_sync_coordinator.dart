import 'sync_cursor.dart';
import '../../controllers/wellness_database_controller.dart';
import '../../core/storage/kv_store.dart';
import '../../core/time/server_clock.dart';
import '../repositories/bookmark_repository.dart';
import '../repositories/recently_watched_repository.dart';
import '../repositories/wellness_repository.dart';
import 'bookmark_sync_engine.dart';
import 'library_scope.dart';
import 'local_library.dart';
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
      WellnessDatabaseController? wellness,
      Future<LocalLibrary> Function(String)? openLibrary})
      : wellness = wellness ?? WellnessDatabaseController.instance,
        _openLibrary = openLibrary ?? LocalLibrary.open {
    bookmarks = SyncRunner(
        canSync: () => canSync,
        autoInterval: const Duration(minutes: 10),
        debounce: const Duration(seconds: 3),
        run: (owner, current) async {
          final db = await _openLibrary(owner);
          await BookmarkSyncEngine(bookmarkRepository)
              .sync(owner, db.movies, db.tv, isCurrent: current);
          if (current()) {
            await store.setInt(
                'sync.$owner.bookmarks.last_synced', clock.nowUtcMs());
          }
        });
    recents = SyncRunner(
        canSync: () => canSync,
        autoInterval: const Duration(minutes: 2),
        debounce: const Duration(seconds: 5),
        run: (owner, current) async {
          final db = await _openLibrary(owner);
          await RecentSyncEngine(recentRepository, clock).sync(
              owner, db.recentMovies, db.recentEpisodes,
              isCurrent: current);
        });
    wellnessSync = SyncRunner(
        canSync: () => canSync,
        autoInterval: const Duration(minutes: 2),
        debounce: const Duration(seconds: 5),
        run: (owner, current) =>
            WellnessSyncEngine(wellnessRepository, this.wellness, clock)
                .sync(owner, isCurrent: current));
  }
  final BookmarkRepository bookmarkRepository;
  final RecentlyWatchedRepository recentRepository;
  final WellnessRepository wellnessRepository;
  final KvStore store;
  final ServerClock clock;
  final String? Function() authenticatedOwner;
  final WellnessDatabaseController wellness;
  final Future<LocalLibrary> Function(String) _openLibrary;
  late final SyncRunner bookmarks, recents, wellnessSync;
  bool get canSync =>
      LibraryScope.enabled &&
      authenticatedOwner() == LibraryScope.owner &&
      LibraryScope.owner.startsWith('user:');

  void activateOwner(String? owner) {
    if (LibraryScope.owner != (owner ?? 'guest')) {
      bookmarks.ownerChanged();
      recents.ownerChanged();
      wellnessSync.ownerChanged();
    }
    LibraryScope.activate(owner);
    if (owner != null) {
      final stamp = store.getInt('sync.$owner.bookmarks.last_synced');
      bookmarks.lastSynced.value = stamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(stamp, isUtc: true);
      recents.lastSynced.value =
          SyncCursor.load(store, owner, 'recent').lastSyncAt;
      wellnessSync.lastSynced.value =
          SyncCursor.load(store, owner, 'wellness').lastSyncAt;
    }
  }

  Future<bool> syncAll() async {
    final owner = authenticatedOwner();
    final bookmarkSuccess = await bookmarks.sync();
    final recentSuccess = await recents.sync();
    final wellnessSuccess = await wellnessSync.sync();
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
    await wellness.permanentlyDeleteOwner(owner);
    await store.removePrefix('sync.$owner.');
    if (store.getString('sync.guest.claimed_by') == owner) {
      await _clearGuestCopy(owner);
      await store.remove('sync.guest.claimed_by');
    }
  }

  void dispose() {
    bookmarks.dispose();
    recents.dispose();
    wellnessSync.dispose();
  }
}
