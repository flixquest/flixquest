import 'package:flixquest/core/config/migration_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only explicitly selected features cut over', () {
    final flags = MigrationFlags.parse(' auth,config, auth,typo ');
    expect(flags.auth, isTrue);
    expect(flags.config, isTrue);
    expect(flags.ads, isFalse);
    expect(flags.sync, isFalse);
    expect(MigrationFlags.parse('').auth, isFalse);
  });
}
