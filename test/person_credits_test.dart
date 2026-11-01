import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/person_credits.dart';
import 'package:flixquest/catalog/title_people.dart';
import 'package:flixquest/models/credits.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePersonCredits', () {
    test('lists each title once with every part and job, most popular first',
        () {
      final credits = parsePersonCredits(<String, dynamic>{
        'cast': <Object?>[
          <String, dynamic>{
            'id': 1,
            'title': 'Small',
            'popularity': 2,
            'character': 'Clerk',
          },
          <String, dynamic>{
            'id': 2,
            'title': 'Big',
            'popularity': 90,
            'character': 'Neo',
          },
          // Billed twice for one film, as TMDB does for a double role.
          <String, dynamic>{
            'id': 2,
            'title': 'Big',
            'popularity': 90,
            'character': ' Thomas Anderson ',
          },
          <String, dynamic>{'id': null, 'title': 'No id'},
          'not a credit',
        ],
        'crew': <Object?>[
          <String, dynamic>{
            'id': 2,
            'title': 'Big',
            'popularity': 90,
            'job': 'Producer',
          },
          <String, dynamic>{
            'id': 3,
            'title': 'Directed',
            'popularity': 40,
            'job': 'Director',
          },
        ],
      }, MediaKind.movie);

      expect(credits.map((credit) => credit.item.id), <int>[2, 3, 1]);
      expect(credits.first.characters, <String>['Neo', 'Thomas Anderson']);
      expect(credits.first.jobs, <String>['Producer']);
      expect(credits[1].characters, isEmpty);
      expect(credits[1].jobs, <String>['Director']);
    });

    test('talk and news shows follow everything else', () {
      final credits = parsePersonCredits(<String, dynamic>{
        'cast': <Object?>[
          <String, dynamic>{
            'id': 10,
            'name': 'Late Show',
            'popularity': 500,
            'genre_ids': <int>[10767],
            'character': 'Self',
          },
          <String, dynamic>{
            'id': 11,
            'name': 'Drama',
            'popularity': 20,
            'genre_ids': <int>[18],
          },
          <String, dynamic>{
            'id': 12,
            'name': 'Evening News',
            'popularity': 300,
            'genre_ids': <int>[10763],
          },
        ],
      }, MediaKind.series);

      expect(credits.map((credit) => credit.item.id), <int>[11, 10, 12]);
      expect(credits.first.item.kind, MediaKind.series);
    });
  });

  test('ageOf counts birthdays not yet reached, and stops at death', () {
    final born = DateTime(1964, 9, 2);
    expect(ageOf(born, now: DateTime(2026, 9, 1)), 61);
    expect(ageOf(born, now: DateTime(2026, 9, 2)), 62);
    expect(ageOf(born, died: DateTime(2000, 1, 1)), 35);
    expect(ageOf(null), isNull);
  });

  group('titlePeople', () {
    test('the cast in billing order, then directors and creators', () {
      final people = titlePeople(
        Credits(
          cast: <Cast>[
            Cast(id: 2, name: 'Second', character: 'B', order: 1),
            Cast(id: 1, name: 'First', character: 'A', order: 0),
            Cast(
              id: 3,
              name: 'Series regular',
              roles: <Roles>[Roles(character: 'C')],
            ),
            Cast(id: null, name: 'No id'),
            Cast(id: 4, name: '  '),
          ],
          crew: <Crew>[
            Crew(id: 5, name: 'Director', job: 'Director'),
            Crew(id: 6, name: 'Writer', job: 'Writer'),
            // Credited twice in the crew, once in front of the camera.
            Crew(id: 1, name: 'First', job: 'Director'),
            Crew(id: 1, name: 'First', job: 'Director'),
          ],
        ),
        creators: <CreatedBy>[CreatedBy(id: 7, name: 'Creator')],
        creatorRole: 'Creator',
      );

      expect(people.map((person) => person.key), <String>[
        'cast:1',
        'cast:2',
        'cast:3',
        'crew:5',
        'crew:1',
        'crew:7',
      ]);
      expect(people[2].role, 'C', reason: "a series' role comes from roles");
      expect(people.last.role, 'Creator');
    });

    test('keeps to the cast limit and copes with no credits', () {
      final people = titlePeople(
        Credits(cast: <Cast>[
          for (var i = 0; i < 30; i++) Cast(id: i, name: 'P$i', order: i),
        ]),
        creatorRole: 'Creator',
        castLimit: 5,
      );
      expect(people, hasLength(5));
      expect(titlePeople(null, creatorRole: 'Creator'), isEmpty);
    });
  });
}
