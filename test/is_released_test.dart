import 'package:flixquest/functions/function.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isReleased', () {
    test('accepts a full ISO release date', () {
      expect(isReleased('2020-01-01'), isTrue);
      expect(isReleased('2999-01-01'), isFalse);
    });

    test('accepts a year-only release date', () {
      expect(isReleased('2020'), isTrue);
      expect(isReleased('2999'), isFalse);
    });

    test('treats an unparseable date as released instead of throwing', () {
      expect(isReleased(''), isTrue);
      expect(isReleased('soon'), isTrue);
    });
  });
}
