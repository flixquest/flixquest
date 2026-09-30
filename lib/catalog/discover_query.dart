import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import 'media_item.dart';

/// One option in a Discover filter: its label's translation key (or a name
/// shown as is) and the value TMDB takes.
typedef DiscoverOption = ({String label, String value});

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
  final request = proxyEnabled && proxyUrl.isNotEmpty
      ? '$proxyUrl?destination=$url'
      : url;
  final http.Client ownClient = client ?? http.Client();
  try {
    final response = await ownClient
        .get(Uri.parse(request))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body);
    return body is Map ? (body['total_results'] as num?)?.toInt() : null;
  } catch (_) {
    return null;
  } finally {
    if (client == null) ownClient.close();
  }
}
