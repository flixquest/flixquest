import 'dart:convert';
import 'package:flixquest/models/custom_exceptions.dart';
import 'package:flutter/foundation.dart';
import '/models/images.dart';
import '/models/person.dart';
import '/models/tv.dart';
import '/models/videos.dart';
import '/models/watch_providers.dart';
import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/failure_exception.dart';
import 'package:flixquest/core/network/network_runtime.dart';
import '/models/credits.dart';
import '/models/genres.dart';
import '/models/external_id_lookup.dart';
import '/models/movie.dart';

Future<Map<String, dynamic>> _tmdbJson(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final result = await NetworkRuntime.tmdb.getJson(api,
      proxyEnabled: isProxyEnabled, proxyUrl: proxyUrl);
  return result.when(ok: (data) => data,
      err: (failure) => throw FailureException(failure));
}

Future<List<Movie>> fetchMovies(
  String api,
  bool isProxyEnabled,
  String proxyUrl, {
  String? debugLabel,
}) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  final movies = MovieList.fromJson(data).movies ?? [];
  if (debugLabel != null) {
    debugPrint('[$debugLabel][PARSED] parsedMovies=${movies.length}');
  }
  return movies;
}

Future<List<Movie>> fetchCollectionMovies(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return CollectionMovieList.fromJson(data).movies ?? [];
}

Future<CollectionDetails> fetchCollectionDetails(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return CollectionDetails.fromJson(data);
}

Future<List<Movie>> fetchPersonMovies(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return PersonMoviesList.fromJson(data).movies ?? [];
}

Future<Images> fetchImages(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return Images.fromJson(data);
}

Future<PersonImages> fetchPersonImages(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return PersonImages.fromJson(data);
}

Future<Videos> fetchVideos(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return Videos.fromJson(data);
}

Future<Credits> fetchCredits(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return Credits.fromJson(data);
}

Future<List<Person>> fetchPerson(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return PersonList.fromJson(data).person ?? [];
}

Future<List<Genres>> fetchGenre(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return GenreList.fromJson(data).genre ?? [];
}

Future<ExternalLinks> fetchSocialLinks(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return ExternalLinks.fromJson(data);
}

Future fetchBelongsToCollection(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return BelongsToCollection.fromJson(data);
}

Future<MovieDetails> fetchMovieDetails(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return MovieDetails.fromJson(data);
}

// Future<Credits> fetchPerson(String api) async {
//   Credits credits;
//   var res = await http.get(Uri.parse(api));
//   var decodeRes = jsonDecode(res.body);
//   credits = Credits.fromJson(decodeRes);
//   return credits;
// }

Future<PersonDetails> fetchPersonDetails(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return PersonDetails.fromJson(data);
}

Future<WatchProviders> fetchWatchProviders(
    String api, String country, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return WatchProviders.fromJson(data, country);
}

Future<List<TV>> fetchTV(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return TVList.fromJson(data).tvSeries ?? [];
}

Future<TVDetails> fetchTVDetails(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return TVDetails.fromJson(data);
}

Future<List<TV>> fetchPersonTV(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return PersonTVList.fromJson(data).tv ?? [];
}

Future<Movie> getMovie(String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return Movie.fromJson(data);
}

Future<TV> getTV(String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return TV.fromJson(data);
}

/// One episode, addressed by its series and its two numbers.
Future<EpisodeList> getEpisode(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return EpisodeList.fromJson(data);
}

/// What TMDB holds under an id belonging to another site, such as an IMDb id.
Future<ExternalIdLookup> findByExternalId(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return ExternalIdLookup.fromJson(data);
}

/// A collection's own name and artwork, for one reached without a film in hand.
Future<BelongsToCollection> fetchCollectionSummary(
    String api, bool isProxyEnabled, String proxyUrl) async {
  final data = await _tmdbJson(api, isProxyEnabled, proxyUrl);
  return BelongsToCollection.fromCollectionJson(data);
}

Future<String> getVttFileAsString(String url) async {
  final response = await NetworkRuntime.publicDio.get<List<int>>(url,
      options: Options(responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (_) => true,
          extra: {'cachePolicy': CachePolicy.noStore}));
  if (response.statusCode != 200) return '';
  final decoded = utf8.decode(response.data ?? []);
  return decoded.startsWith('<') ? '' : decoded;
}

const Map<String, String> _vixSrcHeaders = {
  'accept': '*/*',
  'origin': 'https://vixsrc.to',
  'referer': 'https://vixsrc.to/',
  'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
};

Future<Response<String>> _vixResponse(String api) =>
    NetworkRuntime.publicDio.get<String>(api,
        options: Options(responseType: ResponseType.plain,
            headers: _vixSrcHeaders,
            receiveTimeout: const Duration(seconds: 30),
            validateStatus: (_) => true,
            extra: {'cachePolicy': CachePolicy.noStore, 'retryLimit': 0}));

Future<String> getVixSrcEmbedSrc(String api) async {
  final response = await _vixResponse(api);
  final data = jsonDecode(response.data ?? '');
  if (response.statusCode != 200 || data is! Map<String, dynamic> ||
      data['src'] == null || data['src'].toString().isEmpty) {
    throw NotFoundException();
  }
  return data['src'].toString();
}

Future<String?> getVixSrcEmbedHtml(String api) async {
  final response = await _vixResponse(api);
  if (response.statusCode == 410) return null;
  if (response.statusCode != 200) throw ServerDownException();
  return response.data ?? '';
}

Future<String> getVixSrcPlaylist(String api) async {
  final response = await _vixResponse(api);
  if (response.statusCode != 200) throw ServerDownException();
  return response.data ?? '';
}

// ===================== ANIMEKAI FUNCTIONS =====================
