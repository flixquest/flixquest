import 'package:flixquest/core/storage/kv_store.dart';

/// UTC timestamps corrected using the most recently observed backend time.
class ServerClock {
  ServerClock(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _offsetMs = _store.getInt('clock.offset_ms') ?? 0;

  final KvStore _store;
  final DateTime Function() _now;
  int _offsetMs;

  int get offsetMs => _offsetMs;
  int nowUtcMs() => _now().toUtc().millisecondsSinceEpoch + _offsetMs;
  int toServerMs(DateTime time) =>
      time.toUtc().millisecondsSinceEpoch + _offsetMs;

  Future<void> recordServerTimeUtc(int serverTimeUtc) async {
    final offset = serverTimeUtc - _now().toUtc().millisecondsSinceEpoch;
    await _store.setInt('clock.offset_ms', offset);
    _offsetMs = offset;
  }
}
