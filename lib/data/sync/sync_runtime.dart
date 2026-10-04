import 'laravel_sync_coordinator.dart';
import 'library_scope.dart';

/// Compatibility seam for existing providers and player lifecycle callbacks.
class SyncRuntime {
  static LaravelSyncCoordinator? coordinator;
  static bool get enabled => LibraryScope.enabled;
  static void configure(LaravelSyncCoordinator value, {required bool enabled}) {
    coordinator = value;
    LibraryScope.enabled = enabled;
    LibraryScope.clock = value.clock;
    LibraryScope.store = value.store;
    LibraryScope.activate(value.authenticatedOwner());
  }
}
