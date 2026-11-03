import '../models/credits.dart';
import '../models/tv.dart';

/// Someone in a title's credits, as a row of faces shows them.
class TitlePerson {
  const TitlePerson({
    required this.id,
    required this.name,
    this.role,
    this.profilePath,
    this.adult,
    this.crew = false,
  });

  final int id;
  final String name;

  /// What they did: a character, or a job such as Director.
  final String? role;
  final String? profilePath;
  final bool? adult;

  /// Behind the camera rather than in front of it. Someone who did both
  /// appears once for each.
  final bool crew;

  /// Unique within one title's people.
  String get key => '${crew ? 'crew' : 'cast'}:$id';
}

/// A title's cast in billing order, at most [castLimit] of them, then who
/// made it: a movie's directors, or a series' creators labelled
/// [creatorRole].
List<TitlePerson> titlePeople(
  Credits? credits, {
  List<CreatedBy> creators = const <CreatedBy>[],
  required String creatorRole,
  int castLimit = 20,
}) {
  final people = <TitlePerson>[];
  final seen = <String>{};
  void add(TitlePerson person) {
    if (person.name.trim().isEmpty) return;
    if (seen.add(person.key)) people.add(person);
  }

  final cast = List<Cast>.of(credits?.cast ?? const <Cast>[])
    ..sort((a, b) => (a.order ?? 1 << 20).compareTo(b.order ?? 1 << 20));
  for (final person in cast) {
    if (people.length >= castLimit) break;
    final id = person.id;
    if (id == null) continue;
    final role = person.character ?? person.roles?.firstOrNull?.character;
    add(TitlePerson(
      id: id,
      name: person.name ?? '',
      role: _clean(role),
      profilePath: person.profilePath,
      adult: person.adult,
    ));
  }
  for (final person in credits?.crew ?? const <Crew>[]) {
    final id = person.id;
    if (id == null || person.job != 'Director') continue;
    add(TitlePerson(
      id: id,
      name: person.name ?? '',
      role: person.job,
      profilePath: person.profilePath,
      adult: person.adult,
      crew: true,
    ));
  }
  for (final creator in creators) {
    final id = creator.id;
    if (id == null) continue;
    add(TitlePerson(
      id: id,
      name: creator.name ?? '',
      role: creatorRole,
      profilePath: creator.profilePath,
      crew: true,
    ));
  }
  return people;
}

String? _clean(String? text) {
  final trimmed = text?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
