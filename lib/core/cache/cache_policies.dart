import 'cache_policy.dart';

class CachePolicies {
  static CachePolicy forUrl(Uri url, {String? scope}) {
    scope ??= url.host == 'api.themoviedb.org' ? 'tmdb' : null;
    final path = url.path.replaceFirst(RegExp(r'^/(3|api/v[12])/'), '');
    if (scope == 'tmdb') {
      if (path.startsWith('search/')) {
        return const CachePolicy(
            scope: 'tmdb',
            fresh: Duration(minutes: 5),
            maxStale: Duration(days: 1),
            validators: false);
      }
      if (path.startsWith('genre/') || path.startsWith('configuration')) {
        return const CachePolicy(
            scope: 'tmdb',
            fresh: Duration(days: 7),
            maxStale: Duration(days: 30));
      }
      if (path.startsWith('trending/') ||
          path.startsWith('discover/') ||
          RegExp(r'^(movie|tv)/(popular|top_rated|upcoming|now_playing|on_the_air|airing_today)$')
              .hasMatch(path)) {
        return const CachePolicy(
            scope: 'tmdb',
            fresh: Duration(minutes: 15),
            maxStale: Duration(days: 7));
      }
      return const CachePolicy(
          scope: 'tmdb',
          fresh: Duration(days: 1),
          maxStale: Duration(days: 30));
    }
    if (scope == 'scraper') {
      return switch (path) {
        'providers' => const CachePolicy(
            scope: 'scraper',
            fresh: Duration(minutes: 5),
            maxStale: Duration(days: 1),
            validators: false),
        'providers/status' => const CachePolicy(
            scope: 'scraper',
            fresh: Duration(seconds: 60),
            maxStale: Duration(minutes: 10),
            validators: false),
        'subtitles/search' => const CachePolicy(
            scope: 'scraper',
            fresh: Duration(days: 1),
            maxStale: Duration(days: 7),
            validators: false),
        _ => CachePolicy.noStore,
      };
    }
    if (scope == 'laravel') {
      return switch (path) {
        'config/bootstrap' => const CachePolicy(
            scope: 'laravel', fresh: Duration.zero, maxStale: null),
        'ads' => const CachePolicy(
            scope: 'laravel',
            fresh: Duration(minutes: 5),
            maxStale: Duration(hours: 24)),
        'messages/active' => const CachePolicy(
            scope: 'laravel',
            fresh: Duration(minutes: 15),
            maxStale: Duration(days: 7)),
        _ => CachePolicy.noStore,
      };
    }
    return CachePolicy.noStore;
  }
}
