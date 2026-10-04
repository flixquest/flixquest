import 'dart:async';

import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/models/bootstrap_config.dart';
import 'package:flixquest/data/repositories/config_repository.dart';
import 'package:flixquest/data/sources/firebase_config_source.dart';

import 'bootstrap_view_model.dart';
import 'refresh_controller.dart';

/// Revalidates Laravel's provider decision independently of a slow Firebase
/// fetch, so switching to Laravel never waits for the old provider to finish.
class ConfigSourceController implements ConfigLifecycle {
  ConfigSourceController(
      this.repository, this.viewModel, this.store, this.firebase);
  final ConfigRepository repository;
  final BootstrapViewModel viewModel;
  final KvStore store;
  final FirebaseConfigSource firebase;

  static const _firebaseCacheKey = 'config.firebase.snapshot';
  BootstrapConfig? _firebaseSnapshot;
  StreamSubscription<void>? _subscription;
  Future<(BootstrapConfig, int)>? _validation;
  Future<void>? _sourceWork;
  int _generation = 0;
  int _workGeneration = -1;
  bool _hintPending = false;
  bool _disposed = false;

  void _listen() {
    if (_disposed || _subscription != null) return;
    try {
      _subscription = firebase.updates.listen((_) {
        unawaited(onPushData({'type': 'config_updated'}));
      }, onError: (_) {});
    } catch (_) {
      // Laravel config remains available on platforms without realtime config.
    }
  }

  BootstrapConfig? _cachedFirebase() {
    if (_firebaseSnapshot != null) return _firebaseSnapshot;
    final raw = store.getJson(_firebaseCacheKey);
    if (raw is! Map<String, dynamic> || raw['config_source'] != 'firebase') {
      return null;
    }
    try {
      return _firebaseSnapshot = BootstrapConfig.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  void _apply(BootstrapConfig config) =>
      viewModel.apply(config, preserveThemeSelection: true);

  Future<void> hydrate() async {
    final config = await repository.loadCached(requireSource: true);
    if (_disposed) return;
    _apply(config.configSource == 'firebase'
        ? _cachedFirebase() ?? const BootstrapConfig()
        : config);
    _listen();
  }

  Future<void> refresh() => _refresh();

  @override
  Future<void> boot() => _refresh();
  @override
  Future<void> onResume() => _refresh();
  @override
  Future<void> onPushData(Map<String, dynamic> data) {
    final hint = data['refresh_config'];
    if (!{'config_updated', 'config_refresh'}.contains(data['type']) &&
        hint != true &&
        hint != 'true' &&
        hint != '1') {
      return Future.value();
    }
    if (_validation != null) _hintPending = true;
    return _refresh();
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    _listen();
    final (config, generation) = await (_validation ??= _validate());
    if (_disposed || generation != _generation) return;
    if (_workGeneration != generation) {
      _workGeneration = generation;
      _sourceWork = _applySelection(config, generation);
    }
    await _sourceWork;
  }

  Future<(BootstrapConfig, int)> _validate() async {
    final generation = ++_generation;
    try {
      BootstrapConfig config;
      do {
        _hintPending = false;
        config =
            await repository.refresh(requireSource: true, persistLegacy: false);
      } while (_hintPending && !_disposed);
      return (config, generation);
    } finally {
      // Only the HTTP decision is coalesced; a slow previous Firebase fetch
      // must not block a subsequent resume or operator-directed source switch.
      _validation = null;
    }
  }

  Future<void> _applySelection(BootstrapConfig config, int generation) async {
    bool current() => !_disposed && generation == _generation;
    if (!current()) return;
    if (config.configSource != 'firebase') {
      _apply(config);
      return;
    }
    // Apply only the selected provider's cache while fetching fresh settings.
    _apply(_cachedFirebase() ?? const BootstrapConfig());
    BootstrapConfig? fresh;
    try {
      fresh = await firebase.refresh();
    } catch (_) {
      return;
    }
    if (!current() || fresh == null) return;
    fresh = fresh.copyWith(configSource: 'firebase');
    _firebaseSnapshot = fresh;
    try {
      await store.setJson(_firebaseCacheKey, fresh.toJson());
    } catch (_) {
      // The live snapshot can still be used if preference persistence fails.
    }
    if (current()) _apply(fresh);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    viewModel.dispose();
  }
}
