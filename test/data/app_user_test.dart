import 'package:flixquest/data/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  test('Laravel user resource parses aliases and round trips profile values',
      () {
    final user = AppUser.fromJson(fixture('user'));
    expect(user.id, 7);
    expect(user.name, 'Beamlak Aschalew');
    expect(user.profileId, 1);
    expect(user.photoUrl, isNull);
    expect(user.isVerified, isFalse);
    expect(user.joinedAt, DateTime.utc(2026, 10, 3, 9));
    expect(AppUser.fromJson(user.toJson()), user);
  });

  test('snake case profile fields and legacy fullName remain compatible', () {
    final json = fixture('user')
      ..remove('name')
      ..remove('profileId')
      ..remove('photoUrl')
      ..remove('isVerified')
      ..remove('joinedAt')
      ..remove('createdAt');
    json['profile_id'] = '3';
    json['photo_url'] = 'https://example.com/profile.jpg';
    json['verified'] = '1';
    json['created_at'] = '2026-10-03T09:00:00Z';
    final user = AppUser.fromJson(json);
    expect(user.name, 'Beamlak Aschalew');
    expect(user.profileId, 3);
    expect(user.isVerified, isTrue);
    expect(user.photoUrl, 'https://example.com/profile.jpg');
    expect(user.joinedAt, DateTime.utc(2026, 10, 3, 9));
  });

  test('invalid user identities fail parsing instead of becoming guest data',
      () {
    for (final id in [null, 0, -7, 'firebase-uid', 1.5]) {
      expect(() => AppUser.fromJson({...fixture('user'), 'id': id}),
          throwsFormatException);
    }
  });
}
