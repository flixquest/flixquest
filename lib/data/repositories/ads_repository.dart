import 'dart:async';
import '../../core/cache/cache_policy.dart';
import '../ads/ad_event_queue.dart';
import 'package:dio/dio.dart';
import '../../models/banner_ad.dart';
import '../models/banner_ad_dto.dart';

/// One catalog serves every placement. Persistent/offline caching belongs to
/// the shared Laravel HTTP cache, whose ads policy is 5 minutes / 24 hours.
class AdsRepository {
  AdsRepository(this._dio, {AdEventQueue? events, DateTime Function()? now})
      : events = events ?? AdEventQueue(),
        _now = now ?? DateTime.now;
  final AdEventQueue events;
  Future<void>? _flushing;
  final Dio _dio;
  final DateTime Function() _now;
  Future<List<BannerAd>>? _catalog;
  DateTime? _expiresAt;

  Future<List<BannerAd>> load() {
    if (_catalog != null &&
        (_expiresAt == null || _now().isBefore(_expiresAt!))) {
      return _catalog!;
    }
    _expiresAt = null;
    return _catalog = _fetch();
  }

  Future<List<BannerAd>> _fetch() async {
    var ads = <BannerAd>[];
    try {
      final response = await _dio.get<dynamic>('ads',
          options: Options(extra: {'authRequired': false}));
      final body = response.data;
      if (body is Map && body['success'] == true && body['ads'] is List) {
        for (final value in body['ads'] as List) {
          try {
            final ad =
                BannerAdDto.fromJson(Map<String, dynamic>.from(value as Map))
                    .toModel();
            if (ad.id.isNotEmpty &&
                _webUrl(ad.imageUrl) &&
                _webUrl(ad.targetUrl)) {
              ads.add(ad);
            }
          } catch (_) {/* One malformed campaign must not hide the others. */}
        }
      }
    } catch (_) {/* A missing catalog leaves Start.io available. */}
    _expiresAt = _now().add(Duration(minutes: ads.isEmpty ? 1 : 5));
    return List.unmodifiable(ads);
  }

  Future<void> reportImpression(String id) => _report(id, 'impression');
  Future<void> reportClick(String id) => _report(id, 'click');

  Future<void> _report(String id, String type) async {
    try {
      await events.enqueue(id, type, _now());
      unawaited(flush());
    } catch (_) {/* Storage errors must not interrupt browsing. */}
  }

  Future<void> flush() => _flushing ??= _drain();

  Future<void> _drain() async {
    try {
      await events.prune(_now().subtract(const Duration(days: 7)));
      while (true) {
        final pending = await events.pending();
        if (pending.isEmpty) return;
        for (final event in pending) {
          final response = await _dio.post<dynamic>(
            'ads/${Uri.encodeComponent(event.adId)}/${event.type}',
            options: Options(extra: {
              'authRequired': false,
              'cachePolicy': CachePolicy.noStore
            }, validateStatus: (status) => status == 200 || status == 404),
          );
          if (response.statusCode != 404 &&
              (response.data is! Map || response.data['success'] != true)) {
            return;
          }
          await events.markSent(event.id);
        }
      }
    } catch (_) {
      /* Retry pending events on boot, reconnect, resume or next event. */
    } finally {
      _flushing = null;
    }
  }

  Future<void> dispose() async {
    await _flushing;
    await events.close();
  }

  static bool _webUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
