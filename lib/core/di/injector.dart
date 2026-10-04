import '../../data/repositories/bookmark_repository.dart';
import '../../data/repositories/recently_watched_repository.dart';
import '../../data/repositories/wellness_repository.dart';
import '../../data/sync/laravel_sync_coordinator.dart';
import '../../data/sync/library_scope.dart';
import 'package:flixquest/data/repositories/ads_repository.dart';
import 'package:flixquest/data/repositories/auth_repository.dart';
import 'package:flixquest/data/repositories/config_repository.dart';
import 'package:flixquest/data/sources/laravel_api.dart';
import 'package:flixquest/data/sources/google_identity_client.dart';
import 'package:flixquest/presentation/session/session_view_model.dart';
import 'package:flixquest/core/network/interceptors/auth_interceptor.dart';
import 'package:flixquest/services/local_account_data.dart';
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
    required this.authRepository,
    required this.configRepository,
    required this.adsRepository,
    required this.session,
    required this.syncCoordinator,
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

  final AuthRepository authRepository;
  final ConfigRepository configRepository;
  final AdsRepository adsRepository;
  final SessionViewModel session;
  final LaravelSyncCoordinator syncCoordinator;

  Future<void> dispose() async {
    session.dispose();
    syncCoordinator.dispose();
    await adsRepository.dispose();
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
  GoogleIdentityClient? googleIdentity,
  Future<void> Function(String)? deleteLocalData,
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
  final tokens = tokenStore ?? SecureTokenStore();
  final auth = AuthRepository(LaravelApi(laravelClient));
  final flags = migrationFlags ?? MigrationFlags.fromRuntime();
  final clock = serverClock ?? ServerClock(preferences);
  final syncEnabled = flags.auth && flags.sync;
  late final SessionViewModel session;
  final sync = LaravelSyncCoordinator(
    bookmarkRepository: BookmarkRepository(laravelClient, preferences),
    recentRepository: RecentlyWatchedRepository(laravelClient, preferences, clock),
    wellnessRepository: WellnessRepository(laravelClient, preferences, clock),
    store: preferences, clock: clock, authenticatedOwner: () => session.token == null ? null : session.ownerId.value);
  session = SessionViewModel(repository: auth, tokens: tokens,
      preferences: preferences, cache: cache, google: googleIdentity,
      deleteLocalData: (owner) async {
        if (syncEnabled) await sync.deleteLocal(owner);
        await (deleteLocalData ?? LocalAccountData.delete)(owner);
      },
      onOwnerChanged: syncEnabled ? (owner) {
        LibraryScope.enabled = true;
        LibraryScope.clock = clock;
        LibraryScope.store = preferences;
        sync.activateOwner(owner);
      } : null,
      mergeGuestData: syncEnabled ? (user) => sync.mergeGuest('user:${user.id}') : null);
  laravelClient.interceptors.insert(0, AuthInterceptor(session, config.laravelApiUrl));
  return AppInjector._(
    environment: config,
    migrationFlags: flags,
    kvStore: preferences,
    tokenStore: tokens,
    serverClock: clock,
    publicDio: publicClient,
    laravelDio: laravelClient,
    httpCache: cache,
    tmdbRepository: TmdbRepository(TmdbApi(publicClient)),
    authRepository: auth,
    configRepository: ConfigRepository(laravelClient, preferences),
    adsRepository: AdsRepository(laravelClient),
    session: session,
    syncCoordinator: sync,
  );
}
