import 'package:flixquest/catalog/details_play.dart';
import 'package:flixquest/models/credits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the series cast leads, guest stars follow, nobody twice', () {
    final credits = Credits.fromJson({
      'cast': [
        {'id': 1, 'name': 'Lead'},
        {'id': 2, 'name': 'Regular'},
      ],
      'guest_stars': [
        {'id': 3, 'name': 'Guest'},
        {'id': 2, 'name': 'Regular'},
      ],
    });

    expect(
      episodeCast(credits).map((person) => person.name),
      ['Lead', 'Regular', 'Guest'],
    );
  });
}
