import 'dart:convert';
import 'dart:io';

import 'package:flixquest/catalog/catalog_controller.dart';
import 'package:flixquest/catalog/media_search.dart';
import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/tv/controllers/tv_home_controller.dart';
import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/config/app_environment.dart';
import 'package:flixquest/core/network/dio_factory.dart';
import 'package:flixquest/core/network/network_runtime.dart';
import 'package:flixquest/functions/tmdb_request.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/services/tmdb_connectivity.dart';

import 'support/tmdb_routing_client.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    TMDB_API_KEY = 'proxy-search-test-key';
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  tearDown(() => TMDB_API_KEY = '');

  test('direct requests are preserved when the proxy is off or missing', () {
    const url =
        'https://api.themoviedb.org/3/search/movie?query=Dune&api_key=k';
    expect(tmdbRequestUri(url, false, 'https://proxy.example').toString(), url);
    expect(tmdbRequestUri(url, true, '').toString(), url);
  });

  test('proxy parameters and the complete destination survive wrapping', () {
    const url = 'https://api.themoviedb.org/3/search/movie?'
        'query=A%26B%2BC%23D%25&include_adult=true&language=fr-FR&api_key=k';
    final request = tmdbRequestUri(
      url,
      true,
      'https://proxy.example/tmdb?region=eu&tag=a&tag=b',
    );
    expect(request.path, '/tmdb');
    expect(request.queryParameters['region'], 'eu');
    expect(request.queryParametersAll['tag'], <String>['a', 'b']);
    expect(request.queryParameters['destination'], url);
    expect(request.queryParameters.containsKey('api_key'), isFalse);
    final destination = Uri.parse(request.queryParameters['destination']!);
    expect(destination.queryParameters['query'], 'A&B+C#D%');
  });

  for (final query in <String>[
    'Dune',
    '  The Dark Knight  ',
    'Love & Other Drugs + #1 100%',
    'Amélie 千と千尋',
  ]) {
    test('mobile and TV search through the proxy: $query', () async {
      // Decode destination once, as the proxy does, then parse the TMDB URL.
      // An unescaped wrapper loses the API key and corrupts reserved characters.
      final requests = <Uri>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final destination = request.uri.queryParameters['destination'];
        final target = destination == null ? null : Uri.tryParse(destination);
        if (target == null) {
          request.response.statusCode = 451;
          request.response.write('<html>Blocked</html>');
        } else {
          if (target.path.endsWith('/configuration')) {
            request.response.write('{"images": {}}');
            await request.response.close();
            return;
          }
          requests.add(target);
          if (target.queryParameters['api_key'] != 'proxy-search-test-key') {
            request.response.statusCode = 401;
          } else {
            request.response.write(jsonEncode(<String, dynamic>{
              'results': <Object>[
                <String, dynamic>{
                  'id': 1,
                  'title': target.queryParameters['query'],
                  'name': target.queryParameters['query'],
                },
              ],
            }));
          }
        }
        await request.response.close();
      });

      final originalConnectivity = TmdbConnectivity.instance;
      final simulation = Platform.environment['TMDB_SIMULATION_URL'];
      final routingClient = TmdbRoutingClient(Uri.parse(
        simulation == null
            ? 'http://127.0.0.1:${server.port}/direct'
            : '$simulation/direct',
      ));
      TmdbConnectivity.instance =
          TmdbConnectivity(client: routingClient, hasNetwork: () async => true);
      addTearDown(() {
        TmdbConnectivity.instance.dispose();
        TmdbConnectivity.instance = originalConnectivity;
        routingClient.close();
      });
      final cache = HttpCache(MemCacheStore());
      final dio = createPublicDio(const AppEnvironment(),
          httpCache: cache, debugLogging: false, retryDelay: (_) async {});
      dio.httpClientAdapter = TmdbRoutingDioAdapter(routingClient.directBase);
      NetworkRuntime.configure(publicDio: dio, httpCache: cache);
      addTearDown(() async {
        dio.close(force: true);
        await cache.close();
      });
      final settings = SettingsProvider()
        ..isAdult = true
        ..appLanguage = 'fr-FR';
      final dependencies = AppDependencyProvider()
        ..tmdbProxy = simulation == null
            ? 'http://127.0.0.1:${server.port}/proxy'
            : '$simulation/proxy';
      addTearDown(settings.dispose);
      addTearDown(dependencies.dispose);

      final mobile = await MediaSearch.run(
        TmdbSearchSource(settings: settings, dependencies: dependencies),
        query,
      );
      expect(mobile.movies.single.title, query.trim());
      expect(mobile.series.single.title, query.trim());
      expect(mobile.people.single.name, query.trim());

      final tv = await const CatalogController().search(
        query: query,
        settings: settings,
        dependencies: dependencies,
      );
      expect(tv, hasLength(2));
      expect(tv.map((item) => item.title), everyElement(query.trim()));

      expect(settings.enableProxy, isTrue);
      if (simulation == null) {
        // TV search asks for the same movie and series URLs, which the shared
        // HTTP cache already holds from the mobile search.
        expect(requests, hasLength(3));
        expect(
            requests.map((uri) => uri.path),
            containsAll(<String>[
              '/3/search/movie',
              '/3/search/tv',
              '/3/search/person',
            ]));
        for (final request in requests) {
          expect(request.host, 'api.themoviedb.org');
          expect(request.queryParameters['query'], query.trim());
          expect(request.queryParameters['include_adult'], 'true');
          expect(request.queryParameters['language'], 'fr-FR');
        }
      }

      if (query == 'Dune') {
        final homeSource = CatalogHomeFeedSource(
          settings: settings,
          dependencies: dependencies,
        );
        final mobileRows = await Future.wait([
          homeSource.list(MediaKind.movie, HomeList.popular),
          homeSource.list(MediaKind.series, HomeList.trendingToday),
        ]);
        expect(mobileRows.every((row) => row.isNotEmpty), isTrue);
        final tvHome = await const TvHomeController().load(
          settings: settings,
          dependencies: dependencies,
        );
        expect(tvHome.isEmpty, isFalse);
        expect(tvHome.popularMovies.single.id, 1);
        expect(tvHome.trendingSeries.single.id, 1);
      }
    });
  }
}
