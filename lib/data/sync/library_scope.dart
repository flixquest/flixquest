import '../../core/storage/kv_store.dart';
import '../../core/time/server_clock.dart';

/// Guest files retain their historical paths. Account libraries are isolated.
class LibraryScope {
  static bool enabled = false;
  static String owner = 'guest';
  static int generation = 0;
  static int bookmarkRevision = 0;
  static ServerClock? clock;
  static KvStore? store;

  static void activate(String? value) {
    final next = value ?? 'guest';
    if (owner != next) generation++;
    owner = next;
  }

  static String filename(String path, String owner) =>
      !enabled || owner == 'guest'
          ? path
          : '$path.laravel.${Uri.encodeComponent(owner)}';

  static int nowUtcMs() => enabled && clock != null
      ? clock!.nowUtcMs()
      : DateTime.now().toUtc().millisecondsSinceEpoch;
}
