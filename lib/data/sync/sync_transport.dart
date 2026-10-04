import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/cache/cache_policy.dart';
import '../../core/time/server_clock.dart';

/// Sync writes never enter the HTTP cache or automatic POST retries.
class SyncTransport {
  SyncTransport(this.dio, this.clock);
  final Dio dio;
  final ServerClock clock;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> payload,
      {String? owner}) async {
    _correctFutureRows(payload, clock.offsetMs);
    var retried = false;
    while (true) {
      payload['client_time_utc'] = clock.nowUtcMs();
      try {
        final response = await dio.post<dynamic>(path,
            data: jsonDecode(jsonEncode(payload)),
            options: Options(extra: {
              'cachePolicy': CachePolicy.noStore,
              if (owner != null) 'syncOwner': owner
            }));
        final data = response.data;
        if (data is! Map<String, dynamic> ||
            data['success'] != true ||
            data['server_revision'] is! int ||
            data['server_time_utc'] is! int) {
          throw const FormatException('Invalid sync response');
        }
        await clock.recordServerTimeUtc(data['server_time_utc'] as int);
        return data;
      } on DioException catch (error) {
        final body = error.response?.data;
        if (retried ||
            error.response?.statusCode != 422 ||
            body is! Map ||
            body['error'] != 'clock_skew_detected' ||
            body['server_time_utc'] is! int) {
          rethrow;
        }
        final old = clock.offsetMs;
        await clock.recordServerTimeUtc(body['server_time_utc'] as int);
        final delta = clock.offsetMs - old;
        _correctFutureRows(payload, delta);
        retried = true;
      }
    }
  }

  void _correctFutureRows(Map<String, dynamic> payload, int delta) {
    if (delta >= 0) return;
    for (final field in ['movies', 'episodes', 'sessions', 'daily']) {
      for (final row in (payload[field] as List? ?? const [])) {
        for (final stamp in ['updated_at_utc', 'deleted_at_utc']) {
          if (row[stamp] is int &&
              row[stamp] >
                  clock.nowUtcMs() + const Duration(days: 1).inMilliseconds) {
            row[stamp] = row[stamp] + delta;
          }
        }
      }
    }
  }

  static bool revisionAhead(DioException error) {
    final body = error.response?.data;
    return error.response?.statusCode == 422 &&
        body is Map &&
        body['errors'] is Map &&
        (body['errors'] as Map).containsKey('since_revision');
  }
}
