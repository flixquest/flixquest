import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../repositories/ads_repository.dart';

/// Connectivity is a retry hint; HTTP failures still leave durable events queued.
class AdEventsController {
  AdEventsController(this.repository, {Stream<bool>? connections})
      : _connections = connections ??
            Connectivity().onConnectivityChanged.map((results) =>
                results.any((result) => result != ConnectivityResult.none));
  final AdsRepository repository;
  final Stream<bool> _connections;
  StreamSubscription<bool>? _subscription;
  bool _disposed = false;

  Future<void> boot() async {
    if (_disposed) return;
    _subscription ??= _connections.listen((connected) {
      if (connected && !_disposed) unawaited(repository.flush());
    }, onError: (Object _) {});
    await repository.flush();
  }

  Future<void> onResume() => _disposed ? Future.value() : repository.flush();
  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
  }
}
