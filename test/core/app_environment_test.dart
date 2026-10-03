import 'package:flixquest/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Laravel URL uses define before bundled environment and includes API v1',
      () {
    final environment = AppEnvironment.resolve(
      defineUrl: 'https://backend.example/',
      env: {'LARAVEL_API_URL': 'https://ignored.example'},
      isDebug: false,
    );

    expect(environment.laravelApiUrl, 'https://backend.example/api/v1/');
  });

  test('environment and debug fallback are usable without loading dotenv', () {
    expect(
        AppEnvironment.resolve(
                env: {'LARAVEL_API_URL': 'http://localhost:8000/api/v1/'},
                isDebug: false)
            .laravelApiUrl,
        'http://localhost:8000/api/v1/');
    expect(AppEnvironment.resolve(isDebug: true).laravelApiUrl,
        'http://10.0.2.2:8000/api/v1/');
  });

  test('release builds require a deployment URL', () {
    expect(() => AppEnvironment.resolve(isDebug: false), throwsStateError);
  });

  test('rejects invalid URLs, credentials, query and fragments', () {
    for (final url in [
      'localhost:8000',
      'ftp://backend.example',
      'https://user:password@backend.example',
      'https://backend.example?token=private',
      'https://backend.example#fragment'
    ]) {
      expect(() => AppEnvironment.resolve(defineUrl: url), throwsArgumentError);
    }
  });
}
