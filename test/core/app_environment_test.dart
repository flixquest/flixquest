import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public startup creates an HTTP client without deployment configuration',
      () {
    final environment = AppEnvironment.fromRuntime();
    final client = createPublicDio(environment);
    addTearDown(client.close);
    expect(client.options.baseUrl, isEmpty);
    expect(client.options.connectTimeout, const Duration(seconds: 10));
    expect(client.options.receiveTimeout, const Duration(seconds: 20));
  });
}
