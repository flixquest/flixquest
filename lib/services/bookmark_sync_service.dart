import 'package:flutter/foundation.dart';
import '../data/sync/sync_runtime.dart';
import '../data/sync/sync_runner.dart';
import '../data/sync/library_scope.dart';
import '../legacy/firebase_sync/bookmark_sync_service.dart';
import '../presentation/session/auth_runtime.dart';

enum SyncStatus { idle, syncing, success, error }

/// Preserves the provider API while routing sync through Laravel repositories.
class BookmarkSyncService {
  BookmarkSyncService._();
  static final instance = BookmarkSyncService._();
  FirebaseBookmarkSyncService? _firebase;
  FirebaseBookmarkSyncService get _legacy => _firebase ??= FirebaseBookmarkSyncService.instance;
  final statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.idle);
  final lastSyncedNotifier = ValueNotifier<DateTime?>(null);
  SyncRunner? _runner;
  bool _legacyBound = false;
  void _bind() {
    if (SyncRuntime.enabled) {
      final runner = SyncRuntime.coordinator!.bookmarks;
      if (identical(runner, _runner)) return;
      _runner = runner;
      runner.status.addListener(() => statusNotifier.value = SyncStatus.values.byName(runner.status.value));
      runner.lastSynced.addListener(() => lastSyncedNotifier.value = runner.lastSynced.value);
    } else if (!AuthRuntime.enabled && !_legacyBound) {
      _legacyBound = true;
      _legacy.statusNotifier.addListener(() => statusNotifier.value = _legacy.statusNotifier.value);
      _legacy.lastSyncedNotifier.addListener(() => lastSyncedNotifier.value = _legacy.lastSyncedNotifier.value);
    }
  }
  bool get canSync {
    _bind();
    return SyncRuntime.enabled ? SyncRuntime.coordinator!.canSync : !AuthRuntime.enabled && _legacy.canSync;
  }
  Future<void> init() async {
    _bind();
    if (!SyncRuntime.enabled && !AuthRuntime.enabled) await _legacy.init();
  }
  Future<void> autoSyncIfSignedIn() async {
    if (!canSync) return;
    if (SyncRuntime.enabled) { await _runner!.autoSync(); } else { await _legacy.autoSyncIfSignedIn(); }
  }
  Future<void> onBookmarkChanged() async {
    if (!canSync) return;
    if (SyncRuntime.enabled) { _runner!.changed(); } else { await _legacy.onBookmarkChanged(); }
  }
  Future<bool> syncNow({bool force = false}) async {
    if (!canSync) return false;
    return SyncRuntime.enabled ? _runner!.sync() : _legacy.syncNow(force: force);
  }
  Future<bool> pushLocalToCloud() => syncNow();
  Future<bool> pullCloudToLocal() => syncNow();
  Future<bool> deleteMovieFromCloud(int id, {String? owner}) => _delete('movie', id, owner: owner);
  Future<bool> deleteTVFromCloud(int id, {String? owner}) => _delete('tv', id, owner: owner);
  Future<bool> _delete(String type, int id, {String? owner}) async {
    if (!SyncRuntime.enabled) {
      if (!canSync) return false;
      return type == 'movie' ? _legacy.deleteMovieFromCloud(id) : _legacy.deleteTVFromCloud(id);
    }
    final capturedOwner = owner ?? LibraryScope.owner;
    if (!capturedOwner.startsWith('user:')) return false;
    try {
      final repository = SyncRuntime.coordinator!.bookmarkRepository;
      await repository.recordDeletion(capturedOwner, type, id);
      if (capturedOwner != LibraryScope.owner || !canSync) return false;
      await repository.deleteMedia(type, id, owner: capturedOwner);
      return true;
    } catch (_) {
      if (capturedOwner == LibraryScope.owner && canSync) _runner!.changed();
      return false;
    }
  }
}
