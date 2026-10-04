import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/repositories/announcement_repository.dart';
import 'package:flixquest/models/in_app_message_payload.dart';

typedef MessagePresenter = Future<bool> Function(
    InAppMessagePayload payload, Future<void> Function() acknowledge);

/// Coordinates public announcements and FCM through one presentation queue.
/// A presenter acknowledges when UI opens, rather than when it is dismissed.
class InAppMessageController {
  InAppMessageController(this.repository, this.store, this.present,
      {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _seen.addAll(store.getStringList(_seenKey) ?? const []);
  }
  final AnnouncementRepository repository;
  final KvStore store;
  final MessagePresenter present;
  final DateTime Function() _now;
  static const _seenKey = 'notifications.announcements.shown';
  final _seen = <String>{};
  final _pendingIds = <String>{};
  final _queue = <InAppMessagePayload>[];
  Future<void>? _polling;
  Future<void>? _draining;
  bool _disposed = false;

  Future<void> boot() {
    if (_disposed) return Future.value();
    return _polling ??= _poll().whenComplete(() => _polling = null);
  }

  Future<void> onResume() async {
    await onReady();
    await boot();
  }

  Future<void> _poll() async {
    final result = await repository.fetchActive();
    if (_disposed) return;
    for (final message in result.getOrElse((_) => [])) {
      _enqueue(message.toPayload());
    }
    await onReady();
  }

  Future<void> receive(Map<String, dynamic> data) {
    if (data['type'] != 'in_app_message' &&
        !data.containsKey('title') &&
        !data.containsKey('body') &&
        !data.containsKey('notification_title')) {
      return Future.value();
    }
    return offer(InAppMessagePayload.fromMap(data));
  }

  bool _active(InAppMessagePayload payload) {
    final now = _now();
    return (payload.startsAt == null || !now.isBefore(payload.startsAt!)) &&
        (payload.endsAt == null || !now.isAfter(payload.endsAt!));
  }

  void _enqueue(InAppMessagePayload payload) {
    if (_disposed ||
        !_active(payload) ||
        (payload.title.trim().isEmpty && payload.body.trim().isEmpty)) {
      return;
    }
    final id = payload.id;
    if (id != null && (_seen.contains(id) || !_pendingIds.add(id))) return;
    _queue.add(payload);
  }

  Future<void> offer(InAppMessagePayload payload) {
    _enqueue(payload);
    return onReady();
  }

  Future<void> onReady() {
    if (_disposed) return Future.value();
    return _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    while (!_disposed && _queue.isNotEmpty) {
      final payload = _queue.removeAt(0);
      if (!_active(payload)) {
        _pendingIds.remove(payload.id);
        continue;
      }
      var acknowledged = false;
      var displayed = false;
      try {
        displayed = await present(payload, () async {
          acknowledged = true;
          if (_disposed || payload.id == null) return;
          _seen.add(payload.id!);
          try {
            await store.setStringList(_seenKey, _seen.toList());
          } catch (_) {
            /* Keep session deduplication if storage is unavailable. */
          }
        });
      } catch (_) {
        /* An unavailable navigator retries on the next ready/resume. */
      }
      if (!displayed && !acknowledged && !_disposed) {
        _queue.insert(0, payload);
        return;
      }
      _pendingIds.remove(payload.id);
    }
  }

  void dispose() {
    _disposed = true;
    _queue.clear();
    _pendingIds.clear();
  }
}
