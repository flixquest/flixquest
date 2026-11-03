import 'dart:async';
import 'package:flutter/foundation.dart';
import 'library_scope.dart';

/// One serialized sync at a time, with a coalesced follow-up for local writes.
class SyncRunner {
  SyncRunner(
      {required this.canSync,
      required this.run,
      required this.autoInterval,
      required this.debounce});
  final bool Function() canSync;
  final Future<void> Function(String owner, bool Function() current) run;
  final Duration autoInterval, debounce;
  final status = ValueNotifier<String>('idle');
  final lastSynced = ValueNotifier<DateTime?>(null);
  Future<bool>? _running;
  Timer? _timer;
  bool _followUp = false;
  bool _disposed = false;

  void ownerChanged() {
    _timer?.cancel();
    _timer = null;
    _followUp = false;
    lastSynced.value = null;
    status.value = 'idle';
  }

  void changed() {
    if (!canSync()) return;
    if (_running != null) _followUp = true;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(sync());
    });
  }

  Future<void> flush() async {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    await sync();
  }

  /// A sync nobody asked for, skipped while any sync for this account landed
  /// within [autoInterval]. [lastSynced] is restored from storage when the
  /// account is activated, so a relaunch counts the previous session's sync.
  Future<void> autoSync() async {
    if (!canSync() || isFresh) return;
    await sync();
  }

  bool get isFresh {
    final last = lastSynced.value;
    if (last == null) return false;
    final age = DateTime.now().difference(last);
    // A clock set back would otherwise hold off syncing until it caught up.
    return !age.isNegative && age < autoInterval;
  }

  Future<bool> sync() {
    if (_disposed || !canSync()) return Future.value(false);
    if (_running != null) {
      _followUp = true;
      return _running!;
    }
    final owner = LibraryScope.owner;
    final generation = LibraryScope.generation;
    bool current() =>
        !_disposed &&
        canSync() &&
        LibraryScope.owner == owner &&
        LibraryScope.generation == generation;
    final completer = Completer<bool>();
    _running = completer.future;
    () async {
      var success = false;
      try {
        status.value = 'syncing';
        await run(owner, current);
        if (current()) {
          lastSynced.value = DateTime.now();
          status.value = 'success';
          success = true;
        }
      } catch (_) {
        if (current()) status.value = 'error';
      } finally {
        _running = null;
        completer.complete(success);
        if (_followUp && !_disposed && canSync()) {
          _followUp = false;
          _timer?.cancel();
          _timer = null;
          unawaited(sync());
        }
      }
    }();
    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    status.dispose();
    lastSynced.dispose();
  }
}
