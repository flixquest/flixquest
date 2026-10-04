import '../../core/storage/kv_store.dart';

const fullPullInterval = Duration(days: 7);

class SyncCursor {
  const SyncCursor(
      {this.serverRevision,
      this.lastServerTimeUtc,
      this.lastSyncAt,
      this.lastFullPullAt});
  final int? serverRevision, lastServerTimeUtc;
  final DateTime? lastSyncAt, lastFullPullAt;
  bool needsFullPull(DateTime now) =>
      serverRevision == null ||
      lastFullPullAt == null ||
      now.isBefore(lastFullPullAt!) ||
      now.difference(lastFullPullAt!) >= fullPullInterval;
  SyncCursor advance(int revision, int serverTime,
          {required bool full, required DateTime now}) =>
      SyncCursor(
          serverRevision: full
              ? revision
              : (revision > (serverRevision ?? 0) ? revision : serverRevision),
          lastServerTimeUtc: serverTime,
          lastSyncAt: now,
          lastFullPullAt: full ? now : lastFullPullAt);
  static SyncCursor load(KvStore store, String owner, String kind) {
    final raw = store.getJson('sync.$owner.$kind.cursor');
    if (raw is! Map) return const SyncCursor();
    DateTime? time(String key) => raw[key] is int
        ? DateTime.fromMillisecondsSinceEpoch(raw[key] as int, isUtc: true)
        : null;
    return SyncCursor(
        serverRevision: raw['revision'] is int ? raw['revision'] as int : null,
        lastServerTimeUtc:
            raw['server_time'] is int ? raw['server_time'] as int : null,
        lastSyncAt: time('sync_at'),
        lastFullPullAt: time('full_at'));
  }

  Future<void> save(KvStore store, String owner, String kind) =>
      store.setJson('sync.$owner.$kind.cursor', {
        'revision': serverRevision,
        'server_time': lastServerTimeUtc,
        'sync_at': lastSyncAt?.millisecondsSinceEpoch,
        'full_at': lastFullPullAt?.millisecondsSinceEpoch
      });
}
