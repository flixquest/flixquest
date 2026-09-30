import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server-assigned write time stamped on every synced document, so a pull can
/// ask Firestore for only the documents written since the previous pull.
///
/// A client clock would not do: a device whose clock runs behind would write
/// stamps older than another device's cursor and never be seen by it.
const String syncedAtField = 'syncedAt';

/// How often a pull reads the whole collection even though it has a cursor.
///
/// App versions from before [syncedAtField] still write documents without it,
/// and a merge write from them keeps an older stamp, so neither shows up in a
/// delta query. A periodic full read picks those up.
const Duration fullPullInterval = Duration(days: 7);

/// How far this device has read one synced Firestore collection.
class SyncCheckpoint {
  const SyncCheckpoint({this.stampMicros, this.fullPullAt});

  /// The newest [syncedAtField] this device has applied, in microseconds.
  /// Null until the first full pull.
  final int? stampMicros;

  /// When the collection was last read in full, by this device's clock.
  final DateTime? fullPullAt;

  bool needsFullPull(DateTime now) =>
      stampMicros == null ||
      fullPullAt == null ||
      now.difference(fullPullAt!) >= fullPullInterval ||
      now.isBefore(fullPullAt!);

  /// Reads everything on a [full] pull, otherwise only the documents stamped
  /// after this checkpoint. An empty delta still costs Firestore one read.
  Future<QuerySnapshot<Map<String, dynamic>>> pull(
    CollectionReference<Map<String, dynamic>> collection, {
    required bool full,
  }) {
    if (full) return collection.get();
    return collection
        .where(
          syncedAtField,
          isGreaterThan: Timestamp.fromMicrosecondsSinceEpoch(stampMicros!),
        )
        .get();
  }

  /// The checkpoint after applying [documents] from a pull.
  ///
  /// A full pull restarts from the newest stamp it saw, or from zero when no
  /// document has one yet, so the next delta still finds every stamped write.
  SyncCheckpoint advance(
    Iterable<Map<String, dynamic>> documents, {
    required bool full,
    required DateTime now,
  }) {
    var newest = full ? 0 : stampMicros ?? 0;
    for (final data in documents) {
      final stamp = data[syncedAtField];
      if (stamp is Timestamp && stamp.microsecondsSinceEpoch > newest) {
        newest = stamp.microsecondsSinceEpoch;
      }
    }
    return SyncCheckpoint(
      stampMicros: newest,
      fullPullAt: full ? now : fullPullAt,
    );
  }

  static String _stampKey(String scope) => 'sync_checkpoint.v1.$scope.stamp';
  static String _fullKey(String scope) => 'sync_checkpoint.v1.$scope.full_at';

  static Future<SyncCheckpoint> load(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final fullMillis = prefs.getInt(_fullKey(scope));
    return SyncCheckpoint(
      stampMicros: prefs.getInt(_stampKey(scope)),
      fullPullAt: fullMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fullMillis),
    );
  }

  Future<void> save(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    if (stampMicros != null) {
      await prefs.setInt(_stampKey(scope), stampMicros!);
    }
    if (fullPullAt != null) {
      await prefs.setInt(_fullKey(scope), fullPullAt!.millisecondsSinceEpoch);
    }
  }

  /// Forgets every checkpoint whose scope starts with [scopePrefix], so the
  /// next pull reads in full. Needed whenever the local copy is wiped.
  static Future<void> clear(String scopePrefix) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'sync_checkpoint.v1.$scopePrefix';
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      await prefs.remove(key);
    }
  }
}
