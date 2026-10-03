import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';

class TmdbApi {
  const TmdbApi(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> getJson(
    String url, {
    CachePolicy? policy,
    bool proxyEnabled = false,
    String proxyUrl = '',
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    final response = await dio.get<Object>(
      url,
      cancelToken: cancelToken,
      options: Options(receiveTimeout: timeout, extra: {
        'cacheScope': 'tmdb',
        if (policy != null) 'cachePolicy': policy,
        'tmdbProxyEnabled': proxyEnabled,
        'tmdbProxyUrl': proxyUrl,
      }),
    );
    final body = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object from TMDB');
    }
    return body;
  }
}
