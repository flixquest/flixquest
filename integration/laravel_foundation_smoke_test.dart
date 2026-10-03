import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart' hide CachePolicy;
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/di/injector.dart';
import 'package:flixquest/data/models/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/fakes.dart';

/// Explicit invocation only; the ordinary test suite never depends on a server.
void main() {
  test('F0 clients read live Laravel contracts and revalidate bootstrap',
      () async {
    const url = String.fromEnvironment('LARAVEL_SMOKE_URL');
    if (url.isEmpty) {
      throw StateError('Provide --dart-define=LARAVEL_SMOKE_URL=<host URL>');
    }
    final injector = await buildInjector(
      environment: AppEnvironment.resolve(defineUrl: url),
      responseCacheStore: MemCacheStore(),
      kvStore: FakeKvStore(),
      tokenStore: FakeSecureTokenStore(),
    );
    addTearDown(injector.dispose);
    final client = injector.laravelDio;
    final bootstrap =
        await client.get<Map<String, dynamic>>('config/bootstrap');
    expect(bootstrap.data!['success'], isTrue);
    final data = bootstrap.data!['data'] as Map<String, dynamic>;
    expect(
        data.keys,
        containsAll([
          'features',
          'branding',
          'updates',
          'network',
          'ads',
          'banners',
          'occasional_theme'
        ]));
    final etag = bootstrap.headers.value('etag');
    expect(etag, isNotNull);
    final conditional = await client.get<Object>(
      'config/bootstrap',
      options: Options(
        headers: {'If-None-Match': etag},
        extra: {'cachePolicy': CachePolicy.noStore},
        validateStatus: (status) => status == 304,
      ),
    );
    expect(conditional.statusCode, 304);
    final cachedBootstrap = await client.get<Map<String, dynamic>>('config/bootstrap');
    expect(cachedBootstrap.statusCode, 200);
    expect(cachedBootstrap.data, bootstrap.data);
    expect(cachedBootstrap.extra['cache'], 'revalidated');
    final ads = await client.get<Map<String, dynamic>>('ads');
    expect(ads.data!['success'], isTrue);
    expect(ads.data!['ads'], isA<List>());
    final messages = await client.get<Map<String, dynamic>>('messages/active');
    expect(messages.data!['success'], isTrue);
    expect(messages.data!['messages'], isA<List>());
    try {
      await client.get<Object>('user/profile');
      fail('Profile must require authentication.');
    } on DioException catch (error) {
      expect(error.response?.statusCode, 401);
      final payload =
          ApiError.fromJson(error.response!.data as Map<String, dynamic>);
      expect(payload.message, 'Unauthenticated.');
    }
  });
}
