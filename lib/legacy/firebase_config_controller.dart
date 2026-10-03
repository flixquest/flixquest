import 'dart:async';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/app_remote_config.dart';

/// Temporary rollback path while FLIXQUEST_MIGRATION omits `config`.
class FirebaseConfigController {
  FirebaseConfigController(this.dependencies);
  final AppDependencyProvider dependencies;
  final FirebaseRemoteConfig _remote = FirebaseRemoteConfig.instance;
  StreamSubscription<RemoteConfigUpdate>? _subscription;
  bool _disposed = false;

  Future<void> start() async {
    try {
      await AppRemoteConfig.configure(_remote);
      try {
        await _remote.fetchAndActivate();
      } catch (_) {/* Cached defaults. */}
      if (!_disposed) AppRemoteConfig.apply(_remote, dependencies);
    } catch (_) {
      /* Retain persisted configuration if Firebase is unavailable. */
    }
    if (_disposed) return;
    _subscription = _remote.onConfigUpdated.listen((_) async {
      try {
        await _remote.activate();
        if (!_disposed) AppRemoteConfig.apply(_remote, dependencies);
      } catch (_) {/* Retain the last activated configuration. */}
    }, onError: (_) {});
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
  }
}
