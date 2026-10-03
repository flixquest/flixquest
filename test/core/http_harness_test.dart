import 'package:dio/dio.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/data/models/api_error.dart';
import 'package:flixquest/data/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_dio.dart';
import '../support/fixtures.dart';

void main() {
  test(
      'scripted HTTP delivers Laravel user envelopes and validation errors through Dio',
      () async {
    final adapter = FakeDioAdapter();
    final dio = createLaravelDio(
        AppEnvironment.resolve(defineUrl: 'https://backend.example'));
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);
    adapter.enqueueJson(fixture('auth'));
    adapter.enqueueJson(fixture('validation_error'), statusCode: 422);
    final response = await dio.post<Map<String, dynamic>>('auth/login');
    expect(
        AppUser.fromJson(response.data!['user'] as Map<String, dynamic>).email,
        'beamlak@example.com');
    try {
      await dio.post<Object>('auth/register');
      fail('Validation must fail the HTTP request.');
    } on DioException catch (error) {
      final payload =
          ApiError.fromJson(error.response!.data as Map<String, dynamic>);
      expect(payload.errors['email'], ['The email field is required.']);
    }
    expect(adapter.requests.first.uri.toString(),
        'https://backend.example/api/v1/auth/login');
  });

  test('scripted conditional responses preserve headers and have no JSON body',
      () async {
    final adapter = FakeDioAdapter()
      ..enqueueJson(null, statusCode: 304, headers: {
        'etag': ['"version-1"']
      });
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final response = await dio.get<Object>('https://backend.example/api/v1/ads',
        options: Options(validateStatus: (status) => status == 304));
    expect(response.statusCode, 304);
    expect(response.headers.value('etag'), '"version-1"');
    expect(response.data, isNull);
  });

  test('scripted offline failures use the requested options and Dio error type',
      () async {
    final adapter = FakeDioAdapter()..enqueueError();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    await expectLater(
        dio.get<Object>('https://backend.example/api/v1/ads'),
        throwsA(isA<DioException>().having(
            (error) => error.type, 'type', DioExceptionType.connectionError)));
  });
}
