import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/network/interceptors/error_interceptor.dart';
import '../sources/tmdb_api.dart';

class TmdbRepository {
  const TmdbRepository(this.api);
  final TmdbApi api;

  Future<Result<Map<String, dynamic>>> getJson(
    String url, {
    CachePolicy? policy,
    bool proxyEnabled = false,
    String proxyUrl = '',
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    try {
      return Result.ok(await api.getJson(url,
          policy: policy,
          proxyEnabled: proxyEnabled,
          proxyUrl: proxyUrl,
          cancelToken: cancelToken,
          timeout: timeout));
    } on DioException catch (error) {
      return Result.err(failureForDio(error));
    } on FormatException {
      return const Result.err(
          Failure.unknown(message: 'Invalid TMDB response.'));
    }
  }
}
