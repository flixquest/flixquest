import 'dart:convert';
import 'package:dio/dio.dart';

Uri originalUrl(RequestOptions request) {
  final original = request.extra['tmdbOriginalUrl'];
  if (original is String) return Uri.parse(original);
  var url = request.uri;
  final destination = url.queryParameters['destination'];
  if (destination != null) {
    final parsed = Uri.tryParse(destination);
    if (parsed?.host == 'api.themoviedb.org') url = parsed!;
  }
  return url;
}

String normalizedCacheKey(RequestOptions request,
    {required String scope, String authScope = 'public'}) {
  final url = originalUrl(request);
  final keys = url.queryParametersAll.keys
      .where((key) => !(scope == 'tmdb' && key == 'api_key'))
      .toList()
    ..sort();
  final normalized = url.replace(fragment: '', queryParameters: {
    for (final key in keys) key: url.queryParametersAll[key]!,
  });
  return jsonEncode(
      [scope, authScope, request.method.toUpperCase(), normalized.toString()]);
}
