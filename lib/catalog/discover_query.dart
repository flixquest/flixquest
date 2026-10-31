import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../services/tmdb_connectivity.dart';
import 'media_item.dart';

/// One option in a Discover filter: its label's translation key (or a name
/// shown as is) and the value TMDB takes.
typedef DiscoverOption = ({String label, String value});

/// A country titles can come from: its ISO 3166-1 code, its name in the
/// app's language, and its English name, which search also matches.
typedef DiscoverCountry = ({String code, String name, String englishName});

/// Counts what a discover request would find; null when it can't tell.
typedef DiscoverCounter = Future<int?> Function(String url);

/// Every country titles can come from, named in [language].
typedef DiscoverCountryLoader = Future<List<DiscoverCountry>> Function(
  String language,
);

/// Browse with filters: everything the viewer has chosen for one kind, and
/// the TMDB discover request it makes.
///
/// The options are FlixQuest's own Discover filters, unchanged.
class DiscoverQuery {
  DiscoverQuery(this.kind);

  final MediaKind kind;

  int sort = 0;
  String year = '';

  /// The fewest ratings a title needs; 0 for any.
  int minimumRatings = 0;

  /// Series only: the index into [seriesStatuses].
  int status = 0;
  final Set<String> genres = <String>{};
  final Set<String> providers = <String>{};

  /// Where titles were made, by ISO 3166-1 code; any of them will do.
  final Set<String> countries = <String>{};

  /// The rating counts offered, from any upward.
  static const ratingThresholds = <int>[0, 100, 1000, 5000, 10000, 20000];

  static const sorts = <DiscoverOption>[
    (label: 'popularity_descending', value: 'popularity.desc'),
    (label: 'popularity_ascending', value: 'popularity.asc'),
    (label: 'average_vote_descending', value: 'vote_average.desc'),
    (label: 'average_vote_ascending', value: 'vote_average.asc'),
  ];

  static const seriesStatuses = <DiscoverOption>[
    (label: 'any', value: ''),
    (label: 'returning_series', value: '0'),
    (label: 'planned', value: '1'),
    (label: 'in_production', value: '2'),
    (label: 'ended', value: '3'),
    (label: 'cancelled', value: '4'),
    (label: 'pilot', value: '5'),
  ];

  static const movieGenres = <DiscoverOption>[
    (label: 'action', value: '28'),
    (label: 'adventure', value: '12'),
    (label: 'animation', value: '16'),
    (label: 'comedy', value: '35'),
    (label: 'crime', value: '80'),
    (label: 'documentary', value: '99'),
    (label: 'drama', value: '18'),
    (label: 'family', value: '10751'),
    (label: 'fantasy', value: '14'),
    (label: 'history', value: '36'),
    (label: 'horror', value: '27'),
    (label: 'music', value: '10402'),
    (label: 'mystery', value: '9648'),
    (label: 'romance', value: '10749'),
    (label: 'science_fiction', value: '878'),
    (label: 'tv_movie', value: '10770'),
    (label: 'thriller', value: '53'),
    (label: 'war', value: '10752'),
    (label: 'western', value: '37'),
  ];

  static const seriesGenres = <DiscoverOption>[
    (label: 'action_and_adventure', value: '10759'),
    (label: 'animation', value: '16'),
    (label: 'comedy', value: '35'),
    (label: 'crime', value: '80'),
    (label: 'documentary', value: '99'),
    (label: 'drama', value: '18'),
    (label: 'family', value: '10751'),
    (label: 'kids', value: '10762'),
    (label: 'mystery', value: '9648'),
    (label: 'news', value: '10763'),
    (label: 'reality', value: '10764'),
    (label: 'scifi_and_fantasy', value: '10765'),
    (label: 'soap', value: '10766'),
    (label: 'talk', value: '10767'),
    (label: 'war_and_politics', value: '10768'),
    (label: 'western', value: '37'),
  ];

  /// Service names are shown as they are, not translated.
  static const services = <DiscoverOption>[
    (label: 'Netflix', value: '8'),
    (label: 'Prime Video', value: '9'),
    (label: 'Disney+', value: '337'),
    (label: 'Hulu', value: '15'),
    (label: 'Max', value: '384'),
    (label: 'Apple TV+', value: '350'),
    (label: 'Peacock', value: '387'),
    (label: 'iTunes', value: '2'),
    (label: 'YouTube', value: '188'),
    (label: 'Paramount+', value: '531'),
    (label: 'Netflix Kids', value: '175'),
  ];

  /// The countries offered before any search: the biggest sources of
  /// films and series, in English until TMDB's names arrive.
  static const featuredCountries = <DiscoverCountry>[
    (code: 'US', name: 'United States', englishName: 'United States'),
    (code: 'GB', name: 'United Kingdom', englishName: 'United Kingdom'),
    (code: 'KR', name: 'South Korea', englishName: 'South Korea'),
    (code: 'JP', name: 'Japan', englishName: 'Japan'),
    (code: 'IN', name: 'India', englishName: 'India'),
    (code: 'FR', name: 'France', englishName: 'France'),
    (code: 'ES', name: 'Spain', englishName: 'Spain'),
    (code: 'IT', name: 'Italy', englishName: 'Italy'),
    (code: 'DE', name: 'Germany', englishName: 'Germany'),
    (code: 'CN', name: 'China', englishName: 'China'),
    (code: 'HK', name: 'Hong Kong', englishName: 'Hong Kong'),
    (code: 'TR', name: 'Turkey', englishName: 'Turkey'),
    (code: 'MX', name: 'Mexico', englishName: 'Mexico'),
    (code: 'BR', name: 'Brazil', englishName: 'Brazil'),
    (code: 'CA', name: 'Canada', englishName: 'Canada'),
    (code: 'AU', name: 'Australia', englishName: 'Australia'),
  ];

  /// Codes TMDB keeps for countries that no longer exist (the Soviet Union,
  /// Yugoslavia); no flag stands for them.
  static final _retiredCountries =
      'AN BU CS DD SU TP XC XG XI XK YU ZR'.split(' ').toSet();

  /// [code]'s flag as an emoji, or null for a country without one.
  static String? flag(String code) {
    if (code.length != 2 || _retiredCountries.contains(code)) return null;
    final upper = code.toUpperCase();
    const regionalA = 0x1F1E6;
    final first = upper.codeUnitAt(0) - 0x41;
    final second = upper.codeUnitAt(1) - 0x41;
    if (first < 0 || first > 25 || second < 0 || second > 25) return null;
    return String.fromCharCodes(<int>[regionalA + first, regionalA + second]);
  }

  /// The countries in [all] that [search] names, by either name or code;
  /// those starting with it first.
  static List<DiscoverCountry> matchCountries(
    List<DiscoverCountry> all,
    String search,
  ) {
    final needle = search.trim().toLowerCase();
    if (needle.isEmpty) return all;
    final starts = <DiscoverCountry>[];
    final contains = <DiscoverCountry>[];
    for (final country in all) {
      final name = country.name.toLowerCase();
      final english = country.englishName.toLowerCase();
      if (name.startsWith(needle) ||
          english.startsWith(needle) ||
          country.code.toLowerCase() == needle) {
        starts.add(country);
      } else if (name.contains(needle) || english.contains(needle)) {
        contains.add(country);
      }
    }
    return <DiscoverCountry>[...starts, ...contains];
  }

  /// [all] to browse: the [chosen] ones that aren't popular first, so they
  /// stay in reach, then the popular ones, then the rest A to Z.
  static List<DiscoverCountry> browseCountries(
    List<DiscoverCountry> all,
    Set<String> chosen,
  ) {
    final featured = <String>{
      for (final country in featuredCountries) country.code,
    };
    DiscoverCountry named(String code) =>
        all.where((country) => country.code == code).firstOrNull ??
        featuredCountries
            .where((country) => country.code == code)
            .firstOrNull ??
        (code: code, name: code, englishName: code);
    return <DiscoverCountry>[
      for (final code in chosen)
        if (!featured.contains(code)) named(code),
      for (final code in featured) named(code),
      for (final country in all)
        if (!featured.contains(country.code) && !chosen.contains(country.code))
          country,
    ];
  }

  /// The years to pick from, newest first, back to 1950.
  static List<String> years({DateTime? now}) => <String>[
        for (var year = (now ?? DateTime.now()).year; year >= 1950; year--)
          '$year',
      ];

  List<DiscoverOption> get genreOptions =>
      kind == MediaKind.movie ? movieGenres : seriesGenres;

  /// How many filters are set beyond the defaults (sort doesn't count).
  int get activeCount =>
      genres.length +
      providers.length +
      countries.length +
      (year.isEmpty ? 0 : 1) +
      (minimumRatings > 0 ? 1 : 0) +
      (kind == MediaKind.series && status != 0 ? 1 : 0);

  void clear() {
    sort = 0;
    year = '';
    minimumRatings = 0;
    status = 0;
    genres.clear();
    providers.clear();
    countries.clear();
  }

  /// The TMDB request for these filters, in [language]; the results page
  /// adds the page number. Explicit titles follow the app's setting
  /// ([includeAdult]), as every other list does.
  String url(String language, {bool includeAdult = false}) {
    final movie = kind == MediaKind.movie;
    final parameters = <String, String>{
      'api_key': TMDB_API_KEY,
      'language': language,
      'sort_by': sorts[sort].value,
      'watch_region': 'US',
      if (movie) 'include_adult': '$includeAdult',
      if (movie) 'primary_release_year': year else 'first_air_date_year': year,
      if (!movie) 'with_status': seriesStatuses[status].value,
      'vote_count.gte': '$minimumRatings',
      'with_genres': genres.join(','),
      'with_watch_providers': providers.join(','),
      // A bar between codes asks for any of them, not all.
      if (countries.isNotEmpty) 'with_origin_country': countries.join('|'),
    };
    return Uri.parse(
      '$TMDB_API_BASE_URL/discover/${movie ? 'movie' : 'tv'}',
    ).replace(queryParameters: parameters).toString();
  }
}

/// How many titles [url] (a discover request) finds, or null if it can't
/// say; through the proxy when it's on.
Future<int?> fetchDiscoverTotal(
  String url, {
  required bool proxyEnabled,
  required String proxyUrl,
  http.Client? client,
}) async {
  final http.Client ownClient = client ?? http.Client();
  try {
    final response = await TmdbConnectivity.instance.get(
      url,
      proxyUrl,
      client: ownClient,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body);
    return body is Map ? (body['total_results'] as num?)?.toInt() : null;
  } catch (_) {
    return null;
  } finally {
    if (client == null) ownClient.close();
  }
}

/// Every country TMDB knows, by language, once fetched.
final Map<String, List<DiscoverCountry>> _countriesByLanguage =
    <String, List<DiscoverCountry>>{};

/// Every country TMDB knows, named in [language] and in alphabetical order;
/// just [DiscoverQuery.featuredCountries] when TMDB can't be reached. Kept
/// for the session once fetched.
Future<List<DiscoverCountry>> fetchDiscoverCountries(
  String language, {
  required String proxyUrl,
  http.Client? client,
}) async {
  final cached = _countriesByLanguage[language];
  if (cached != null) return cached;
  final http.Client ownClient = client ?? http.Client();
  try {
    final url = Uri.parse('$TMDB_API_BASE_URL/configuration/countries')
        .replace(queryParameters: <String, String>{
      'api_key': TMDB_API_KEY,
      'language': language,
    }).toString();
    final response = await TmdbConnectivity.instance.get(
      url,
      proxyUrl,
      client: ownClient,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode != 200) return DiscoverQuery.featuredCountries;
    final body = jsonDecode(response.body);
    if (body is! List) return DiscoverQuery.featuredCountries;
    final countries = <DiscoverCountry>[
      for (final entry in body)
        if (entry is Map && entry['iso_3166_1'] is String)
          (
            code: entry['iso_3166_1'] as String,
            englishName: '${entry['english_name'] ?? entry['iso_3166_1']}',
            // TMDB leaves a name it has no translation for empty.
            name: '${entry['native_name'] ?? ''}'.trim().isEmpty
                ? '${entry['english_name'] ?? entry['iso_3166_1']}'
                : '${entry['native_name']}'.trim(),
          ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (countries.isEmpty) return DiscoverQuery.featuredCountries;
    return _countriesByLanguage[language] = List.unmodifiable(countries);
  } catch (_) {
    return DiscoverQuery.featuredCountries;
  } finally {
    if (client == null) ownClient.close();
  }
}

/// The countries [codes] stands for, named as [all] names them, on one line.
String countryNames(Iterable<String> codes, List<DiscoverCountry> all) {
  String name(String code) =>
      all.where((country) => country.code == code).firstOrNull?.name ??
      DiscoverQuery.featuredCountries
          .where((country) => country.code == code)
          .firstOrNull
          ?.name ??
      code;
  return codes.map(name).join(', ');
}
