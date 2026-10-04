import 'package:flutter/foundation.dart';
import '../data/sync/sync_runtime.dart';
import '../data/sync/sync_runner.dart';
import '../legacy/firebase_sync/recently_watched_sync_service.dart';
import '../presentation/session/auth_runtime.dart';

enum RecentSyncStatus { idle, syncing, success, error }

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

class RecentlyWatchedSyncService {
  RecentlyWatchedSyncService._();
  static final instance = RecentlyWatchedSyncService._();
  FirebaseRecentlyWatchedSyncService? _firebase;
  FirebaseRecentlyWatchedSyncService get _legacy => _firebase ??= FirebaseRecentlyWatchedSyncService.instance;
  final statusNotifier = ValueNotifier<RecentSyncStatus>(RecentSyncStatus.idle);
  final lastSyncedNotifier = ValueNotifier<DateTime?>(null);
  SyncRunner? _runner;
  bool _legacyBound = false;
  void _bind() {
    if (SyncRuntime.enabled) {
      final runner = SyncRuntime.coordinator!.recents;
      if (identical(runner, _runner)) return;
      _runner = runner;
      runner.status.addListener(() => statusNotifier.value = RecentSyncStatus.values.byName(runner.status.value));
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
  void onRecentChanged() {
    if (!canSync) return;
    if (SyncRuntime.enabled) { _runner!.changed(); } else { _legacy.onRecentChanged(); }
  }
  Future<void> flushPending() async {
    if (!canSync) return;
    if (SyncRuntime.enabled) { await _runner!.flush(); } else { await _legacy.flushPending(); }
  }
  Future<bool> pushPendingNow() => syncNow();
  Future<bool> syncNow({bool force = false}) async {
    if (!canSync) return false;
    return SyncRuntime.enabled ? _runner!.sync() : _legacy.syncNow(force: force);
  }
  Future<void> deleteAccountData(String uid) async {
    if (SyncRuntime.enabled) {
      await AuthRuntime.session.deleteAccount();
    } else { await _legacy.deleteAccountData(uid); }
  }
  Future<void> deleteRemoteAccountData(String uid) async {
    if (SyncRuntime.enabled) {
      final result = await AuthRuntime.session.deleteAccount();
      result.when(ok: (_) {}, err: (failure) => throw StateError(failure.message ?? 'Account deletion failed'));
    } else { await _legacy.deleteRemoteAccountData(uid); }
  }
  void dispose() { if (!SyncRuntime.enabled && !AuthRuntime.enabled) _firebase?.dispose(); }
}
