import 'package:flutter/foundation.dart';
import '../data/sync/sync_runtime.dart';
import '../data/sync/sync_runner.dart';
export '../data/sync/daily_write_plan.dart' show planDailyWrites;

enum WellnessSyncStatus { idle, syncing, success, error }

/// Adapts Laravel's sync runner to existing provider and player callbacks.
class WellnessSyncService {
  WellnessSyncService();
  final status = ValueNotifier<WellnessSyncStatus>(WellnessSyncStatus.idle);
  final lastSynced = ValueNotifier<DateTime?>(null);
  SyncRunner? _runner;

  void bind() {
    final next =
        SyncRuntime.enabled ? SyncRuntime.coordinator?.wellnessSync : null;
    if (identical(next, _runner)) return;
    _runner?.status.removeListener(_onStatus);
    _runner?.lastSynced.removeListener(_onSynced);
    _runner = next;
    next?.status.addListener(_onStatus);
    next?.lastSynced.addListener(_onSynced);
    _onStatus();
    _onSynced();
  }

  void _onStatus() => status.value = _runner == null
      ? WellnessSyncStatus.idle
      : WellnessSyncStatus.values.byName(_runner!.status.value);
  void _onSynced() => lastSynced.value = _runner?.lastSynced.value;
  bool get canSync {
    bind();
    return SyncRuntime.enabled && (SyncRuntime.coordinator?.canSync ?? false);
  }

  Future<bool> syncNow({bool force = false}) async {
    if (!canSync) return false;
    return _runner!.sync();
  }

  Future<bool> pushPending() => syncNow();

  /// Whether this account synced recently enough to skip an automatic pull.
  bool get isFresh {
    bind();
    return _runner?.isFresh ?? false;
  }

  void dispose() {
    _runner?.status.removeListener(_onStatus);
    _runner?.lastSynced.removeListener(_onSynced);
    _runner = null;
    status.dispose();
    lastSynced.dispose();
  }
}
