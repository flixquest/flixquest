import 'package:flixquest/data/models/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  test(
      'Laravel clock skew retains authoritative time and serializes nested details',
      () {
    final error = ApiError.fromJson(fixture('clock_skew_error'));
    expect(error.code, 'clock_skew_detected');
    expect(error.clockSkew?.serverTimeUtc, 1700000000000);
    expect(error.clockSkew?.maxDriftMs, 86400000);
    expect(error.toJson()['clockSkew'], isA<Map<String, dynamic>>());
    expect(ApiError.fromJson(error.toJson()), error);
  });

  test(
      'validation messages remain field scoped and tolerate missing optional fields',
      () {
    final error = ApiError.fromJson(fixture('validation_error'));
    expect(error.errors, {
      'email': ['The email field is required.']
    });
    expect(error.clockSkew, isNull);
    expect(
        ApiError.fromJson({
          'errors': {'email': 'Already taken.', 'bad': null},
          'retry_after': '60'
        }).retryAfter,
        60);
    expect(ApiError.fromJson({}).message, 'Request failed.');
  });
}
