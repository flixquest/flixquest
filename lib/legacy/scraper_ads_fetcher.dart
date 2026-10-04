import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/cache/cache_policy.dart';
import '../core/network/network_runtime.dart';
import '../models/banner_ad.dart';

/// Temporary flag-off rollback path, retained until F7.
class ScraperAdsFetcher {
  ScraperAdsFetcher({Dio? dio}) : _dio = dio ?? NetworkRuntime.publicDio;
  final Dio _dio;
  Future<List<BannerAd>> load(String baseUrl) async {
    try {
      final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
      if (base.isEmpty) return const [];
      final root = base.endsWith('/api/v2') ? base : '$base/api/v2';
      final response = await _dio.get<String>('$root/ads',
          options: Options(
              responseType: ResponseType.plain,
              receiveTimeout: const Duration(seconds: 10),
              extra: {
                'cachePolicy': CachePolicy.noStore,
                'cacheScope': 'scraper'
              }));
      final body = jsonDecode(response.data ?? '');
      if (body is! Map || body['success'] != true || body['ads'] is! List) {
        return const [];
      }
      return (body['ads'] as List)
          .whereType<Map>()
          .map((value) => BannerAd.fromJson(Map<String, dynamic>.from(value)))
          .where((ad) => ad.imageUrl.isNotEmpty && ad.targetUrl.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
