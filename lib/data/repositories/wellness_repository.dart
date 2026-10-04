import 'package:dio/dio.dart';
import '../../core/storage/kv_store.dart';
import '../../core/time/server_clock.dart';
import '../sync/sync_cursor.dart';
import '../sync/sync_transport.dart';

class WellnessSyncResult {
  WellnessSyncResult(
      {required this.sessions,
      required this.daily,
      required this.uploadedSessions,
      required this.full,
      required Future<void> Function() save})
      : _save = save;
  final List<Map<String, dynamic>> sessions, daily, uploadedSessions;
  final bool full;
  final Future<void> Function() _save;
  Future<void> save() => _save();
}

class WellnessRepository {
  WellnessRepository(Dio dio, this.store, this.clock)
      : _transport = SyncTransport(dio, clock);
  final KvStore store;
  final ServerClock clock;
  final SyncTransport _transport;

  Map<String, int?> dailyLedger(String owner) {
    final raw = store.getJson('sync.$owner.wellness.daily');
    return raw is Map
        ? raw.map((key, value) =>
            MapEntry(key.toString(), value is num ? value.toInt() : null))
        : {};
  }

  Future<WellnessSyncResult> sync(String owner,
      {List<Map<String, dynamic>> sessions = const [],
      List<Map<String, dynamic>> daily = const []}) async {
    final baseline = SyncCursor.load(store, owner, 'wellness');
    var full = baseline.needsFullPull(
        DateTime.fromMillisecondsSinceEpoch(clock.nowUtcMs(), isUtc: true));
    final uploaded = <Map<String, dynamic>>[];
    final ledger = dailyLedger(owner);
    final operations = [
      for (final row in sessions) (session: true, row: row),
      for (final row in daily) (session: false, row: row)
    ];
    // Finish every upload before opening the paginated snapshot. Upload
    // responses are deliberately not used as checkpoints or page cursors.
    for (var offset = 0; offset < operations.length; offset += 450) {
      final chunk = operations.skip(offset).take(450);
      final payload = <String, dynamic>{
        'sessions': chunk
            .where((op) => op.session)
            .map((op) => Map<String, dynamic>.from(op.row))
            .toList(),
        'daily': chunk
            .where((op) => !op.session)
            .map((op) => Map<String, dynamic>.from(op.row))
            .toList(),
        'limit': 450,
      };
      await _transport.post('sync/wellness', payload, owner: owner);
      uploaded
          .addAll((payload['sessions'] as List).cast<Map<String, dynamic>>());
      for (final row in payload['daily'] as List) {
        ledger[row['local_day'] as String] = row['updated_at_utc'] as int;
      }
    }
    final pulled = <Map<String, dynamic>>[];
    final days = <String, Map<String, dynamic>>{};
    final seen = <String>{};
    String? cursor;
    Map<String, dynamic> page;
    do {
      final payload = <String, dynamic>{
        'sessions': [],
        'daily': [],
        'limit': 450,
        'since_revision': full ? 0 : baseline.serverRevision,
        if (cursor != null) 'cursor': cursor
      };
      try {
        page = await _transport.post('sync/wellness', payload, owner: owner);
      } on DioException catch (error) {
        if (cursor != null || full || !SyncTransport.revisionAhead(error)) {
          rethrow;
        }
        full = true;
        payload['since_revision'] = 0;
        page = await _transport.post('sync/wellness', payload, owner: owner);
      }
      if (page['requires_full_sync'] == true && !full && cursor == null) {
        full = true;
        payload['since_revision'] = 0;
        page = await _transport.post('sync/wellness', payload, owner: owner);
      }
      if (page['sessions'] is! List ||
          page['daily'] is! List ||
          page['has_more'] is! bool) {
        throw const FormatException('Invalid wellness page');
      }
      pulled.addAll((page['sessions'] as List)
          .map((row) => Map<String, dynamic>.from(row)));
      for (final row in page['daily'] as List) {
        final map = Map<String, dynamic>.from(row);
        days[map['local_day'] as String] = map;
      }
      if (page['has_more'] == false) break;
      cursor = page['next_cursor'] as String?;
      if (cursor == null || cursor.isEmpty || !seen.add(cursor)) {
        throw const FormatException('Invalid wellness cursor');
      }
    } while (true);
    final next = baseline.advance(
        page['server_revision'] as int, page['server_time_utc'] as int,
        full: full,
        now:
            DateTime.fromMillisecondsSinceEpoch(clock.nowUtcMs(), isUtc: true));
    final nextLedger = <String, int?>{
      if (!full) ...ledger,
      for (final row in days.values)
        row['local_day'] as String:
            (row['session_count'] == 0 && row['watched_ms'] == 0)
                ? null
                : row['updated_at_utc'] as int?
    };
    return WellnessSyncResult(
        sessions: pulled,
        daily: days.values.toList(),
        uploadedSessions: uploaded,
        full: full,
        save: () async {
          await store.setJson('sync.$owner.wellness.daily', nextLedger);
          await next.save(store, owner, 'wellness');
        });
  }
}
