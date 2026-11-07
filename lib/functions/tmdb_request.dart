/// Wraps a TMDB URL as one proxy parameter, preserving its own query string.
Uri tmdbRequestUri(String url, bool proxyEnabled, String proxyUrl) {
  final destination = Uri.parse(url);
  if (!proxyEnabled || proxyUrl.isEmpty) return destination;

  final proxy = Uri.parse(proxyUrl);
  return proxy.replace(queryParameters: <String, dynamic>{
    ...proxy.queryParametersAll,
    'destination': destination.toString(),
  });
}

/// [url] with `include_adult=false` when it is a TMDB request that doesn't say.
///
/// A request that already states a value keeps it, because search and discover
/// follow the app's explicit-results setting. The URL is extended as text so
/// the encoding of its other parameters survives.
String tmdbUrlWithAdultFlag(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.host != 'api.themoviedb.org' ||
      uri.queryParameters.containsKey('include_adult')) {
    return url;
  }
  return '$url${url.contains('?') ? '&' : '?'}include_adult=false';
}
