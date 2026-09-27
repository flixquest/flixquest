import '../api/endpoints.dart';
import '../functions/network.dart';
import '../models/person.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import 'media_item.dart';

/// Where Search's results come from, so tests can answer (and delay) as
/// they like.
abstract class SearchSource {
  Future<List<MediaItem>> movies(String query);
  Future<List<MediaItem>> series(String query);
  Future<List<Person>> people(String query);
}

/// TMDB, with the viewer's language and adult-content setting.
class TmdbSearchSource implements SearchSource {
  const TmdbSearchSource({required this.settings, required this.dependencies});

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;

  String _encode(String query) => Uri.encodeQueryComponent(query.trim());

  @override
  Future<List<MediaItem>> movies(String query) => fetchMovies(
        Endpoints.movieSearchUrl(
          _encode(query),
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then((items) => items.map(MediaItem.fromMovie).toList());

  @override
  Future<List<MediaItem>> series(String query) => fetchTV(
        Endpoints.tvSearchUrl(
          _encode(query),
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then((items) => items.map(MediaItem.fromSeries).toList());

  @override
  Future<List<Person>> people(String query) => fetchPerson(
        Endpoints.personSearchUrl(
          _encode(query),
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      );
}

/// What a query found, each kind in its own list.
class SearchResults {
  const SearchResults({
    required this.query,
    this.topResult,
    this.movies = const <MediaItem>[],
    this.series = const <MediaItem>[],
    this.people = const <Person>[],
  });

  final String query;

  /// The one title the query most likely means, if one stands out.
  final MediaItem? topResult;
  final List<MediaItem> movies;
  final List<MediaItem> series;
  final List<Person> people;

  bool get isEmpty => movies.isEmpty && series.isEmpty && people.isEmpty;
}

/// How Search looks things up: after the viewer stops typing, and only for
/// a query worth sending.
abstract final class MediaSearch {
  /// The pause in typing before a search goes out.
  static const debounce = Duration(milliseconds: 350);

  /// The shortest query that searches.
  static const minLength = 2;

  static bool searchable(String query) => query.trim().length >= minLength;

  /// Every kind at once; a kind that fails comes back empty rather than
  /// taking the others with it.
  static Future<SearchResults> run(SearchSource source, String query) async {
    Future<List<T>> orEmpty<T>(Future<List<T>> future) =>
        future.catchError((Object _) => <T>[]);
    final found = await Future.wait<Object>(<Future<Object>>[
      orEmpty(source.movies(query)),
      orEmpty(source.series(query)),
      orEmpty(source.people(query)),
    ]);
    final movies = unique(found[0] as List<MediaItem>);
    final series = unique(found[1] as List<MediaItem>);
    final people = (found[2] as List<Person>)
        .where((person) => person.id != null)
        .toList(growable: false);
    return SearchResults(
      query: query,
      topResult: topResultFor(query, movies: movies, series: series),
      movies: movies,
      series: series,
      people: people,
    );
  }

  static List<MediaItem> unique(List<MediaItem> items) {
    final seen = <String>{};
    return items
        .where((item) => item.id >= 0 && seen.add(item.stableId))
        .toList(growable: false);
  }

  /// A title the query plainly names: an exact title match, else one that
  /// starts with the query; the most popular of those. Null when nothing
  /// stands out, rather than guessing.
  static MediaItem? topResultFor(
    String query, {
    required List<MediaItem> movies,
    required List<MediaItem> series,
  }) {
    final wanted = normalize(query);
    if (wanted.isEmpty) return null;
    final all = <MediaItem>[...movies, ...series];
    MediaItem? mostPopular(Iterable<MediaItem> items) {
      MediaItem? best;
      for (final item in items) {
        if (best == null || (item.popularity ?? 0) > (best.popularity ?? 0)) {
          best = item;
        }
      }
      return best;
    }

    return mostPopular(all.where((item) => normalize(item.title) == wanted)) ??
        mostPopular(
          all.where((item) => normalize(item.title).startsWith(wanted)),
        );
  }

  /// A title for comparing: lower case, punctuation and extra spaces gone.
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
