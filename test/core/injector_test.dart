import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart' hide CachePolicy;
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/di/injector.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/core/storage/secure_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_dio.dart';
import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'injector isolates public client from Laravel credentials and configures API paths',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = KvStore(await SharedPreferences.getInstance());
    final tokens = SecureTokenStore();
    final publicDio = Dio();
    final laravelDio = Dio();
    final injector = await buildInjector(
      environment:
          AppEnvironment.resolve(defineUrl: 'https://backend.example/api/v1'),
      responseCacheStore: MemCacheStore(),
      kvStore: store,
      tokenStore: tokens,
      publicDio: publicDio,
      laravelDio: laravelDio,
    );
    addTearDown(injector.dispose);
    expect(injector.kvStore, same(store));
    expect(injector.tokenStore, same(tokens));
    expect(injector.publicDio, same(publicDio));
    expect(
        injector.laravelDio.options.baseUrl, 'https://backend.example/api/v1/');
    expect(injector.laravelDio.options.connectTimeout,
        const Duration(seconds: 10));
    expect(injector.publicDio.options.headers.containsKey('Authorization'),
        isFalse);
    expect(injector.migrationFlags.auth, isFalse);
  });

  test('dependency injection can construct without invoking platform storage',
      () async {
    final clock = FakeServerClock();
    final injector = await buildInjector(
      environment: AppEnvironment.resolve(defineUrl: 'http://localhost:8000'),
      responseCacheStore: MemCacheStore(),
      kvStore: FakeKvStore(),
      tokenStore: FakeSecureTokenStore(),
      serverClock: clock,
    );
    addTearDown(injector.dispose);
    final adapter = FakeDioAdapter()..enqueueJson({'success': true});
    injector.laravelDio.httpClientAdapter = adapter;
    expect(
        (await injector.laravelDio
                .get<Map<String, dynamic>>('config/bootstrap'))
            .data!['success'],
        isTrue);
    expect(injector.serverClock, same(clock));
    expect(await injector.tokenStore.read(), isNull);
  });

  test('one client cannot be reused for public and authenticated traffic',
      () async {
    final dio = Dio();
    addTearDown(dio.close);
    await expectLater(
        buildInjector(publicDio: dio, laravelDio: dio), throwsArgumentError);
  });
}
