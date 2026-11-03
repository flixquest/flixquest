import '../api/endpoints.dart';
import '../functions/network.dart';
import '../models/movie.dart';
import '../models/person.dart';
import '../models/tv.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import 'media_item.dart';

/// A title someone worked on, with everything they did on it.
class PersonCredit {
  const PersonCredit({
    required this.item,
    this.characters = const <String>[],
    this.jobs = const <String>[],
  });

  final MediaItem item;

  /// The characters they played, each once.
  final List<String> characters;

  /// The jobs they did behind the camera, each once.
  final List<String> jobs;
}

/// What a person's page asks for. A fake can stand in for TMDB in tests.
abstract class PersonSource {
  Future<PersonDetails> details(int personId);
  Future<List<PersonCredit>> credits(int personId, MediaKind kind);
}

/// TMDB through the app's fetchers, language and proxy.
class TmdbPersonSource implements PersonSource {
  const TmdbPersonSource({required this.settings, required this.dependencies});

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;

  @override
  Future<PersonDetails> details(int personId) => fetchPersonDetails(
        Endpoints.getPersonDetails(personId, settings.appLanguage),
        settings.enableProxy,
        dependencies.tmdbProxy,
      );

  @override
  Future<List<PersonCredit>> credits(int personId, MediaKind kind) async {
    final json = await fetchTmdbJson(
      kind == MediaKind.movie
          ? Endpoints.getMovieCreditsForPerson(personId, settings.appLanguage)
          : Endpoints.getTVCreditsForPerson(personId, settings.appLanguage),
      settings.enableProxy,
      dependencies.tmdbProxy,
    );
    return parsePersonCredits(json, kind);
  }
}

/// TMDB's talk and news genres: shows a person visits as themselves, which
/// would otherwise crowd the start of an actor's series.
const _appearanceGenres = <int>{10767, 10763};

/// A person's movie or TV credits, each title once, most popular first.
/// Talk and news shows follow everything else.
List<PersonCredit> parsePersonCredits(
  Map<String, dynamic> json,
  MediaKind kind,
) {
  final items = <int, MediaItem>{};
  final characters = <int, List<String>>{};
  final jobs = <int, List<String>>{};
  void add(Object? raw, String field, Map<int, List<String>> roles) {
    if (raw is! Map<String, dynamic>) return;
    final item = kind == MediaKind.movie
        ? MediaItem.fromMovie(Movie.fromJson(raw))
        : MediaItem.fromSeries(TV.fromJson(raw));
    if (item.id < 0) return;
    items.putIfAbsent(item.id, () => item);
    final list = roles.putIfAbsent(item.id, () => <String>[]);
    final role = raw[field];
    if (role is String) {
      final trimmed = role.trim();
      if (trimmed.isNotEmpty && !list.contains(trimmed)) list.add(trimmed);
    }
  }

  for (final raw in json['cast'] as List? ?? const <Object?>[]) {
    add(raw, 'character', characters);
  }
  for (final raw in json['crew'] as List? ?? const <Object?>[]) {
    add(raw, 'job', jobs);
  }
  final ordered = items.values.toList();
  bool appearance(MediaItem item) =>
      item.genreIds.any(_appearanceGenres.contains);
  // List.sort is not stable, so ties keep TMDB's order through the index.
  final position = <int, int>{
    for (final (index, item) in ordered.indexed) item.id: index,
  };
  ordered.sort((a, b) {
    final byKind = (appearance(a) ? 1 : 0).compareTo(appearance(b) ? 1 : 0);
    if (byKind != 0) return byKind;
    final byPopularity = (b.popularity ?? 0).compareTo(a.popularity ?? 0);
    if (byPopularity != 0) return byPopularity;
    return position[a.id]!.compareTo(position[b.id]!);
  });
  return <PersonCredit>[
    for (final item in ordered)
      PersonCredit(
        item: item,
        characters: characters[item.id] ?? const <String>[],
        jobs: jobs[item.id] ?? const <String>[],
      ),
  ];
}

/// Someone's age today, or at their death; null without a birthday.
int? ageOf(DateTime? born, {DateTime? died, DateTime? now}) {
  if (born == null) return null;
  final until = died ?? now ?? DateTime.now();
  var age = until.year - born.year;
  final hadBirthday = until.month > born.month ||
      (until.month == born.month && until.day >= born.day);
  if (!hadBirthday) age -= 1;
  return age < 0 ? null : age;
}
