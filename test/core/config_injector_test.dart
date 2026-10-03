import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/di/injector.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/fake_dio.dart';
import '../support/session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'signed-in bootstrap remains public and its own snapshot handles real Dio 304',
      () async {
    dotenv.testLoad(
        fileInput:
            'TMDB_API_KEY=local\nMIXPANEL_API_KEY=test\nFLIXQUEST_API_URL=https://fallback.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    final adapter = FakeDioAdapter()..enqueueJson(authFixture());
    final fixture = jsonDecode(
        File('test/support/fixtures/bootstrap_config.json').readAsStringSync());
    final injector = await buildInjector(
        environment: AppEnvironment.resolve(defineUrl: 'http://backend.test'),
        kvStore: KvStore(sharedPrefsSingleton),
        tokenStore: MemoryTokens(),
        responseCacheStore: MemCacheStore(),
        laravelDio: Dio()..httpClientAdapter = adapter);
    addTearDown(injector.dispose);
    await injector.session.signIn(
        const LoginRequest(email: 'beamlak@example.com', password: 'password'));
    adapter.enqueueJson(fixture, headers: {
      'etag': ['"fixture"']
    });
    final config = await injector.configRepository.refresh();
    expect(config.updates.latestBuildNumber, 5);
    expect(adapter.requests.last.headers['Authorization'], isNull);
    expect(await injector.httpCache.sizeBytes(), 0);
    adapter.enqueueJson(null, statusCode: 304, headers: {
      'etag': ['"fixture"']
    });
    expect(
        (await injector.configRepository.refresh()).updates.latestBuildNumber,
        5);
    expect(adapter.requests.last.headers['If-None-Match'], '"fixture"');
    adapter.enqueueJson({'success': false}, statusCode: 401);
    expect(
        (await injector.configRepository.refresh()).updates.latestBuildNumber,
        5);
    expect(injector.session.token, '7|sanitized-test-token');
  });
}
