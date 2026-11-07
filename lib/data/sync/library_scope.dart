import '../../core/storage/kv_store.dart';
import '../../core/time/server_clock.dart';

/// Shared device-local database context.
abstract final class LibraryScope {
  static const enabled = false;
  static const owner = 'guest';
  static const generation = 0;
  static int bookmarkRevision = 0;
  static ServerClock? clock;
  static KvStore? store;
  static String filename(String path, String owner) => path;
  static int nowUtcMs() => DateTime.now().toUtc().millisecondsSinceEpoch;
}
