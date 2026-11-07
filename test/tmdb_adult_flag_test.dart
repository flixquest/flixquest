import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/data/sources/tmdb_api.dart';
import 'package:flixquest/functions/tmdb_request.dart';
import 'package:flixquest/services/tmdb_connectivity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_dio.dart';

void main() {
  group('tmdbUrlWithAdultFlag', () {
    test('adds the flag to a TMDB request that has none', () {
      const url = 'https://api.themoviedb.org/3/trending/movie/day?api_key=k';
      expect(tmdbUrlWithAdultFlag(url), '$url&include_adult=false');
    });

    test('starts the query when the request has none', () {
      const url = 'https://api.themoviedb.org/3/movie/popular';
      expect(tmdbUrlWithAdultFlag(url), '$url?include_adult=false');
    });

    test('leaves the choice of a request that already states one', () {
      const url = 'https://api.themoviedb.org/3/search/movie?'
          'query=A%26B%2BC%23D%25&include_adult=true&api_key=k';
      expect(tmdbUrlWithAdultFlag(url), url);
    });

    test('keeps the encoding of the rest of the request', () {
      const url = 'https://api.themoviedb.org/3/discover/tv?'
          'with_origin_country=US%7CGB&api_key=k';
      expect(tmdbUrlWithAdultFlag(url), '$url&include_adult=false');
    });

    test('leaves requests to other hosts alone', () {
      const url = 'https://proxy.example/tmdb?destination=x';
      expect(tmdbUrlWithAdultFlag(url), url);
    });
  });

  test('every TMDB request through the shared Dio client carries the flag',
      () async {
    final adapter = FakeDioAdapter()..enqueueJson({'results': []});
    final dio = createPublicDio(const AppEnvironment(), debugLogging: false);
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);

    await TmdbApi(dio)
        .getJson('https://api.themoviedb.org/3/trending/movie/day?api_key=k');

    expect(
        adapter.requests.single.uri.queryParameters['include_adult'], 'false');
  });

  test('the flag travels inside the destination through the proxy', () async {
    final adapter = FakeDioAdapter()..enqueueJson({'results': []});
    final dio = createPublicDio(const AppEnvironment(), debugLogging: false);
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);

    await TmdbApi(dio).getJson(
      'https://api.themoviedb.org/3/trending/movie/day?api_key=k',
      proxyEnabled: true,
      proxyUrl: 'https://proxy.example/tmdb',
    );

    final sent = adapter.requests.single.uri;
    expect(sent.host, 'proxy.example');
    expect(
        Uri.parse(sent.queryParameters['destination']!)
            .queryParameters['include_adult'],
        'false');
  });

  test('requests through TmdbConnectivity carry the flag', () async {
    final seen = <Uri>[];
    final connectivity = TmdbConnectivity(
      client: MockClient((request) async {
        seen.add(request.url);
        return http.Response('{}', 200);
      }),
      hasNetwork: () async => true,
    );
    addTearDown(connectivity.dispose);

    await connectivity.get(
        'https://api.themoviedb.org/3/discover/tv?api_key=k', '');

    expect(seen.single.queryParameters['include_adult'], 'false');
  });
}
