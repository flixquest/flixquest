import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapping results transforms success and preserves structured failures',
      () {
    const success = Result<int>.ok(7);
    const failure = Result<int>.err(Failure.validation({
      'email': ['Already taken.']
    }));
    expect(
        success.map((value) => 'user:$value').getOrElse((_) => ''), 'user:7');
    expect(
        failure.map((value) => '$value'),
        const Result<String>.err(Failure.validation({
          'email': ['Already taken.']
        })));
    expect(
        Result<int>.fromJson(
            failure.toJson((value) => value), (value) => value as int),
        failure);
    expect(
        Result<int>.fromJson(
            success.toJson((value) => value), (value) => value as int),
        success);
  });

  test('failure fallback does not run on success', () {
    expect(
        const Result<int>.ok(3)
            .getOrElse((_) => throw StateError('Unexpected fallback')),
        3);
    expect(
        const Result<int>.err(Failure.unauthorized()).getOrElse((_) => 0), 0);
  });

  test('every failure kind survives serialization', () {
    const failures = [
      Failure.network(message: 'Offline'),
      Failure.timeout(),
      Failure.unauthorized(),
      Failure.forbidden(),
      Failure.notFound(),
      Failure.conflict(),
      Failure.validation({
        'password': ['Too short.']
      }),
      Failure.rateLimited(retryAfter: 30),
      Failure.server(status: 503),
      Failure.clockSkew(serverTimeUtc: 1700000000000, driftMs: 86400000),
      Failure.cache(),
      Failure.unknown(),
    ];
    for (final failure in failures) {
      expect(Failure.fromJson(failure.toJson()), failure);
    }
  });
}
