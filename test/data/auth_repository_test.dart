import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/data/repositories/auth_repository.dart';
import 'package:flixquest/data/sources/laravel_api.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_dio.dart';

void main() {
  test('login preserves passwords and reads the Laravel Sanctum session',
      () async {
    final fixture =
        jsonDecode(File('test/support/fixtures/auth.json').readAsStringSync());
    final adapter = FakeDioAdapter()..enqueueJson(fixture);
    final dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final result = await AuthRepository(LaravelApi(dio)).signIn(
        const LoginRequest(
            email: ' BEAMLAK@example.com ', password: ' secret password '));
    final session =
        result.when(ok: (value) => value, err: (_) => fail('Login failed'));
    expect(session.user.id, 7);
    expect(session.token, '7|sanitized-test-token');
    expect(session.toString(), isNot(contains('sanitized-test-token')));
    expect(adapter.requests.single.data,
        {'email': 'beamlak@example.com', 'password': ' secret password '});
    expect(adapter.requests.single.uri.path, '/api/v1/auth/login');
  });
}
