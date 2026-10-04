import 'bootstrap_view_model.dart';

abstract interface class ConfigLifecycle {
  Future<void> boot();
  Future<void> onResume();
  Future<void> onPushData(Map<String, dynamic> data);
  void dispose();
}

/// One refresh path for boot, lifecycle resume and FCM config hints.
class RefreshController implements ConfigLifecycle {
  RefreshController(this.viewModel);
  final BootstrapViewModel viewModel;
  Future<void>? _inFlight;
  bool _disposed = false;
  bool _hintPending = false;

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
    if (_inFlight != null) _hintPending = true;
    return _refresh();
  }

  Future<void> _refresh() {
    if (_disposed) return Future.value();
    return _inFlight ??= _run();
  }

  Future<void> _run() async {
    try {
      do {
        _hintPending = false;
        await viewModel.refresh();
      } while (_hintPending && !_disposed);
    } finally {
      _inFlight = null;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    viewModel.dispose();
  }
}
