import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/data/repositories/tmdb_repository.dart';
import 'package:flixquest/data/sources/tmdb_api.dart';
import 'dio_factory.dart';

/// Bridges existing top-level APIs to the one app-owned network dependency set.
/// Main installs the persistent injector before UI requests begin. Standalone
/// widgets/tests can use a volatile cache without invoking platform storage.
class NetworkRuntime {
  static HttpCache? _cache;
  static Dio? _dio;
  static TmdbRepository? _tmdb;
  static HttpCache get httpCache =>
      _cache ??= HttpCache(MemCacheStore(maxSize: 16 * 1024 * 1024));
  static Dio get publicDio => _dio ??= createPublicDio(
      AppEnvironment.resolve(defineUrl: 'http://localhost', isDebug: false),
      httpCache: httpCache);
  static TmdbRepository get tmdb =>
      _tmdb ??= TmdbRepository(TmdbApi(publicDio));

  static void configure(
      {required Dio publicDio,
      required HttpCache httpCache,
      TmdbRepository? tmdb}) {
    _dio = publicDio;
    _cache = httpCache;
    _tmdb = tmdb ?? TmdbRepository(TmdbApi(publicDio));
  }
}
