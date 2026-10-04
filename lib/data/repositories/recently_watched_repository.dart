import 'package:dio/dio.dart';
import '../../core/storage/kv_store.dart';
import '../../core/time/server_clock.dart';
import '../sync/sync_cursor.dart';
import '../sync/sync_transport.dart';

class RecentSyncResult {
  RecentSyncResult(this.data, this.uploads, this.full, this._save);
  final Map<String, dynamic> data;
  final Map<String, dynamic> uploads;
  final bool full;
  final Future<void> Function() _save;
  int get revision => data['server_revision'] as int;
  Future<void> saveCursor() => _save();
}

class RecentlyWatchedRepository {
  RecentlyWatchedRepository(Dio dio, this.store, this.clock)
      : _transport = SyncTransport(dio, clock);
  final KvStore store;
  final ServerClock clock;
  final SyncTransport _transport;

  Future<RecentSyncResult> sync(String owner,
      {List<Map<String, dynamic>> movies = const [],
      List<Map<String, dynamic>> episodes = const []}) async {
    final cursor = SyncCursor.load(store, owner, 'recent');
    final now =
        DateTime.fromMillisecondsSinceEpoch(clock.nowUtcMs(), isUtc: true);
    var full = cursor.needsFullPull(now);
    final payload = <String, dynamic>{
      'since_revision': full ? 0 : cursor.serverRevision,
      'movies': movies.map((m) => Map<String, dynamic>.from(m)).toList(),
      'episodes': episodes.map((e) => Map<String, dynamic>.from(e)).toList(),
    };
    Map<String, dynamic> data;
    try {
      data =
          await _transport.post('sync/recently-watched', payload, owner: owner);
    } on DioException catch (error) {
      if (!SyncTransport.revisionAhead(error) || full) rethrow;
      full = true;
      payload['since_revision'] = 0;
      data =
          await _transport.post('sync/recently-watched', payload, owner: owner);
    }
    if (data['requires_full_sync'] == true && !full) {
      full = true;
      payload['since_revision'] = 0;
      data =
          await _transport.post('sync/recently-watched', payload, owner: owner);
    }
    if (data['movies'] is! List || data['episodes'] is! List) {
      throw const FormatException('Missing recent collections');
    }
    final next = cursor.advance(
        data['server_revision'] as int, data['server_time_utc'] as int,
        full: full,
        now:
            DateTime.fromMillisecondsSinceEpoch(clock.nowUtcMs(), isUtc: true));
    return RecentSyncResult(
        data, payload, full, () => next.save(store, owner, 'recent'));
  }
}
