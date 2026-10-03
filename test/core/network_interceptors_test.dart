import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/core/network/interceptors/logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/callback_dio.dart';
import '../support/fake_dio.dart';

void main() {
  test('GET transport/server retries use 300/600ms and stop after two retries',
      () async {
    final delays = <Duration>[];
    final adapter = FakeDioAdapter()
      ..enqueueError()
      ..enqueueJson({}, statusCode: 503)
      ..enqueueJson({'ok': true});
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        debugLogging: false,
        retryDelay: (duration) async => delays.add(duration));
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);
    expect((await dio.get<Object>('https://example.com')).data, {'ok': true});
    expect(delays,
        [const Duration(milliseconds: 300), const Duration(milliseconds: 600)]);
    for (var i = 0; i < 3; i++) {
      adapter.enqueueJson({}, statusCode: 503);
    }
    await expectLater(
        dio.get<Object>('https://example.com'),
        throwsA(isA<DioException>().having((e) => e.error, 'failure',
            const Failure.server(status: 503, message: 'Request failed.'))));
    expect(adapter.requests, hasLength(6));
  });

  for (final error in [
    const SocketException('offline'),
    TimeoutException('slow')
  ]) {
    test('legacy ${error.runtimeType} failures still retry', () async {
      var calls = 0;
      final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
          debugLogging: false, retryDelay: (_) async {});
      dio.httpClientAdapter = CallbackDioAdapter((request) async {
        calls++;
        if (calls < 3) {
          throw DioException(requestOptions: request, error: error);
        }
        return jsonResponse('{}', 200);
      });
      addTearDown(dio.close);
      await dio.get<Object>('https://example.com');
      expect(calls, 3);
    });
  }

  test('POST and 4xx are never retried and errors become typed Failures',
      () async {
    final adapter = FakeDioAdapter()
      ..enqueueError(type: DioExceptionType.receiveTimeout)
      ..enqueueJson({'message': 'Wait'},
          statusCode: 429,
          headers: {
            'retry-after': ['60']
          });
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        debugLogging: false, retryDelay: (_) async => fail('Unexpected retry'));
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);
    await expectLater(
        dio.post<Object>('https://example.com'),
        throwsA(isA<DioException>()
            .having((e) => e.error, 'failure', const Failure.timeout())));
    await expectLater(
        dio.get<Object>('https://example.com'),
        throwsA(isA<DioException>().having((e) => e.error, 'failure',
            const Failure.rateLimited(retryAfter: 60, message: 'Wait'))));
    expect(adapter.requests, hasLength(2));
  });

  test('logs omit API keys, bearer tokens, signed queries and payloads',
      () async {
    final logs = <String>[];
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        debugLogging: false);
    dio.interceptors.add(LoggingInterceptor(log: logs.add));
    dio.httpClientAdapter = FakeDioAdapter()
      ..enqueueJson({'secret': 'response-secret'});
    addTearDown(dio.close);
    await dio.post<Object>(
        'https://example.com/api?token=query-secret&api_key=key-secret',
        data: {'password': 'body-secret'},
        options: Options(headers: {'Authorization': 'Bearer bearer-secret'}));
    expect(logs.join(' '), contains('POST example.com/api'));
    expect(logs.join(' '), isNot(contains('secret')));
  });

  test(
      'public defaults preserve custom Accept headers; proxies only affect TMDB',
      () async {
    final adapter = FakeDioAdapter()..enqueueJson({});
    final dio = createPublicDio(AppEnvironment.resolve(isDebug: true),
        debugLogging: false);
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);
    await dio.get<Object>('https://scraper.example/api/v2/providers',
        options: Options(
          headers: {'accept': 'application/custom'},
          extra: {
            'tmdbProxyEnabled': true,
            'tmdbProxyUrl': 'https://proxy.example'
          },
        ));
    final request = adapter.requests.single;
    expect(request.uri.host, 'scraper.example');
    expect(request.headers['accept'], 'application/custom');
    expect(request.headers.keys.where((key) => key.toLowerCase() == 'accept'),
        hasLength(1));
    expect(request.headers['Accept-Encoding'], 'gzip');
    expect(request.headers['User-Agent'], startsWith('FlixQuest/'));
  });
}
