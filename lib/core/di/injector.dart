import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/cache/response_cache_store.dart';
import 'package:flixquest/data/repositories/tmdb_repository.dart';
import 'package:flixquest/data/sources/tmdb_api.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/config/migration_flags.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/core/storage/secure_token_store.dart';
import 'package:flixquest/core/time/server_clock.dart';

/// Owns dependencies for one app lifecycle; pass this object through Provider.
class AppInjector {
  const AppInjector._({
    required this.environment,
    required this.migrationFlags,
    required this.kvStore,
    required this.tokenStore,
    required this.serverClock,
    required this.publicDio,
    required this.laravelDio,
    required this.httpCache,
    required this.tmdbRepository,
  });

  final AppEnvironment environment;
  final MigrationFlags migrationFlags;
  final KvStore kvStore;
  final SecureTokenStore tokenStore;
  final ServerClock serverClock;
  final Dio publicDio;
  final Dio laravelDio;
  final HttpCache httpCache;
  final TmdbRepository tmdbRepository;

  Future<void> dispose() async {
    publicDio.close(force: true);
    laravelDio.close(force: true);
    await httpCache.close();
  }
}

Future<AppInjector> buildInjector({
  AppEnvironment? environment,
  MigrationFlags? migrationFlags,
  KvStore? kvStore,
  SecureTokenStore? tokenStore,
  ServerClock? serverClock,
  Dio? publicDio,
  Dio? laravelDio,
  CacheStore? responseCacheStore,
}) async {
  if (publicDio != null && identical(publicDio, laravelDio)) {
    throw ArgumentError(
        'Public and Laravel clients must be separate instances.');
  }
  final config = environment ?? AppEnvironment.fromRuntime();
  final preferences = kvStore ?? await KvStore.create();
  CacheStore cacheStore;
  if (responseCacheStore != null) {
    cacheStore = responseCacheStore;
  } else {
    try {
      cacheStore = await ResponseCacheStore.open();
    } catch (_) {
      cacheStore = MemCacheStore(maxSize: 16 * 1024 * 1024);
    }
  }
  final cache = HttpCache(cacheStore);
  final publicClient = createPublicDio(config, dio: publicDio, httpCache: cache);
  final laravelClient = createLaravelDio(config, dio: laravelDio, httpCache: cache);
  return AppInjector._(
    environment: config,
    migrationFlags: migrationFlags ?? MigrationFlags.fromRuntime(),
    kvStore: preferences,
    tokenStore: tokenStore ?? SecureTokenStore(),
    serverClock: serverClock ?? ServerClock(preferences),
    publicDio: publicClient,
    laravelDio: laravelClient,
    httpCache: cache,
    tmdbRepository: TmdbRepository(TmdbApi(publicClient)),
  );
}
