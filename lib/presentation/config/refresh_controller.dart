import 'bootstrap_view_model.dart';

/// One refresh path for boot, lifecycle resume and FCM config hints.
class RefreshController {
  RefreshController(this.viewModel, {DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final BootstrapViewModel viewModel;
  final DateTime Function() _now;
  Future<void>? _inFlight;
  bool _disposed = false;
  bool _hintPending = false;

  Future<void> boot() => _refresh();
  Future<void> onResume() {
    final validated = viewModel.lastValidatedAt;
    if (validated != null &&
        _now().toUtc().difference(validated) <= const Duration(hours: 1)) {
      return Future.value();
    }
    return _refresh();
  }

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

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    viewModel.dispose();
  }
}
