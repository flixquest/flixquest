import 'package:flutter/foundation.dart';
import '../controllers/wellness_database_controller.dart';
import '../data/sync/sync_runtime.dart';
import '../data/sync/sync_runner.dart';
import '../legacy/firebase_sync/wellness_sync_service.dart';
import '../presentation/session/auth_runtime.dart';
export '../data/sync/daily_write_plan.dart' show planDailyWrites;

enum WellnessSyncStatus { idle, syncing, success, error }

class WellnessSyncService {
  WellnessSyncService({WellnessDatabaseController? database}) : _database = database ?? WellnessDatabaseController.instance;
  final WellnessDatabaseController _database;
  FirebaseWellnessSyncService? _firebase;
  FirebaseWellnessSyncService get _legacy => _firebase ??= FirebaseWellnessSyncService(database: _database);
  final status = ValueNotifier<WellnessSyncStatus>(WellnessSyncStatus.idle);
  final lastSynced = ValueNotifier<DateTime?>(null);
  SyncRunner? _runner;
  bool _legacyBound = false;
  void bind() {
    if (SyncRuntime.enabled) {
      final runner = SyncRuntime.coordinator!.wellnessSync;
      if (identical(runner, _runner)) return;
      _runner = runner;
      runner.status.addListener(() => status.value = WellnessSyncStatus.values.byName(runner.status.value));
      runner.lastSynced.addListener(() => lastSynced.value = runner.lastSynced.value);
    } else if (!AuthRuntime.enabled && !_legacyBound) {
      _legacyBound = true;
      _legacy.status.addListener(() => status.value = _legacy.status.value);
      _legacy.lastSynced.addListener(() => lastSynced.value = _legacy.lastSynced.value);
    }
  }
  bool get canSync {
    bind();
    return SyncRuntime.enabled ? SyncRuntime.coordinator!.canSync : !AuthRuntime.enabled && _legacy.canSync;
  }
  Future<bool> syncNow() async {
    if (!canSync) return false;
    return SyncRuntime.enabled ? _runner!.sync() : _legacy.syncNow();
  }
  Future<bool> pushPending() => syncNow();
  Future<void> deleteRemoteAccountData(String uid) async {
    if (SyncRuntime.enabled) {
      final result = await AuthRuntime.session.deleteAccount();
      result.when(ok: (_) {}, err: (failure) => throw StateError(failure.message ?? 'Account deletion failed'));
    } else { await _legacy.deleteRemoteAccountData(uid); }
  }
}
