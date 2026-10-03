import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/config/migration_flags.dart';
import 'package:flixquest/core/di/injector.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/presentation/session/session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_dio.dart';
import '../support/session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'factory wires Bearer only to Laravel and never caches profile responses',
      () async {
    final h = await SessionHarness.create();
    addTearDown(h.dispose);
    final laravel = FakeDioAdapter()..enqueueJson(authFixture());
    final public = FakeDioAdapter()
      ..enqueueJson({'id': 7, 'title': 'Public title'});
    final injector = await buildInjector(
        environment: AppEnvironment.resolve(defineUrl: 'http://backend.test'),
        migrationFlags: MigrationFlags.parse('auth'),
        kvStore: h.preferences,
        tokenStore: h.tokens,
        responseCacheStore: MemCacheStore(),
        laravelDio: Dio()..httpClientAdapter = laravel,
        publicDio: Dio()..httpClientAdapter = public);
    addTearDown(injector.dispose);
    await injector.session.signIn(
        const LoginRequest(email: 'beamlak@example.com', password: 'password'));
    for (var request = 0; request < 2; request++) {
      laravel.enqueueJson(authFixture());
      await injector.authRepository.profile();
    }
    expect(laravel.requests.length, 3);
    expect(laravel.requests.last.headers['Authorization'],
        'Bearer 7|sanitized-test-token');
    expect(laravel.requests.last.extra['authScope'], 'user:7');
    expect(await injector.httpCache.sizeBytes(), 0);
    await injector.publicDio.get('https://api.themoviedb.org/3/movie/7');
    expect(public.requests.single.headers['Authorization'], null);
    laravel.enqueueJson({'success': false}, statusCode: 401);
    await injector.authRepository.profile();
    expect(injector.session.state, const SessionState.expired());
    expect(laravel.requests.length, 4);
    expect(await injector.tokenStore.read(), null);
  });
  test(
      'new injector restores a previous lifecycle session from persisted token and profile',
      () async {
    final h = await SessionHarness.create();
    addTearDown(h.dispose);
    final firstAdapter = FakeDioAdapter()..enqueueJson(authFixture());
    final first = await buildInjector(
        environment: AppEnvironment.resolve(defineUrl: 'http://backend.test'),
        kvStore: h.preferences,
        tokenStore: h.tokens,
        responseCacheStore: MemCacheStore(),
        laravelDio: Dio()..httpClientAdapter = firstAdapter);
    await first.session.signIn(
        const LoginRequest(email: 'beamlak@example.com', password: 'password'));
    await first.dispose();
    final restoredAdapter = FakeDioAdapter()..enqueueJson(authFixture());
    final next = await buildInjector(
        environment: AppEnvironment.resolve(defineUrl: 'http://backend.test'),
        kvStore: h.preferences,
        tokenStore: h.tokens,
        responseCacheStore: MemCacheStore(),
        laravelDio: Dio()..httpClientAdapter = restoredAdapter);
    addTearDown(next.dispose);
    expect(next.session.state, const SessionState.initializing());
    await next.session.restore();
    expect(next.session.ownerId.value, 'user:7');
    expect(next.session.user?.username, 'beamlak');
    expect(restoredAdapter.requests.single.uri.path, '/api/v1/user/profile');
    expect(restoredAdapter.requests.single.headers['Authorization'],
        'Bearer 7|sanitized-test-token');
  });
}
