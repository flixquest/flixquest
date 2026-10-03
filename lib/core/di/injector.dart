import 'package:dio/dio.dart';
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
  });

  final AppEnvironment environment;
  final MigrationFlags migrationFlags;
  final KvStore kvStore;
  final SecureTokenStore tokenStore;
  final ServerClock serverClock;
  final Dio publicDio;
  final Dio laravelDio;

  void dispose() {
    publicDio.close(force: true);
    laravelDio.close(force: true);
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
}) async {
  if (publicDio != null && identical(publicDio, laravelDio)) {
    throw ArgumentError(
        'Public and Laravel clients must be separate instances.');
  }
  final config = environment ?? AppEnvironment.fromRuntime();
  final preferences = kvStore ?? await KvStore.create();
  return AppInjector._(
    environment: config,
    migrationFlags: migrationFlags ?? MigrationFlags.fromRuntime(),
    kvStore: preferences,
    tokenStore: tokenStore ?? SecureTokenStore(),
    serverClock: serverClock ?? ServerClock(preferences),
    publicDio: createPublicDio(config, dio: publicDio),
    laravelDio: createLaravelDio(config, dio: laravelDio),
  );
}
