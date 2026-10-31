import 'package:flixquest/catalog/catalog_controller.dart';
import 'package:flixquest/catalog/discover_query.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/mobile/screens/discover_screen.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, String> _params(String url) => Uri.parse(url).queryParameters;

void main() {
  setUp(() async {
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  group('the request', () {
    test('movies: every filter, explicit titles as the app setting says', () {
      final query = DiscoverQuery(MediaKind.movie)
        ..sort = 2
        ..year = '2014'
        ..minimumRatings = 5000
        ..genres.addAll(<String>['878', '18'])
        ..providers.add('8');
      final url = query.url('es-ES', includeAdult: true);
      expect(Uri.parse(url).path, '/3/discover/movie');
      expect(_params(url), <String, String>{
        'api_key': 'key',
        'language': 'es-ES',
        'sort_by': 'vote_average.desc',
        'watch_region': 'US',
        'include_adult': 'true',
        'primary_release_year': '2014',
        'vote_count.gte': '5000',
        'with_genres': '878,18',
        'with_watch_providers': '8',
      });
      expect(query.activeCount, 5);
      expect(_params(query.url('en'))['include_adult'], 'false');
    });

    test('series: the status and first-air year instead', () {
      final query = DiscoverQuery(MediaKind.series)
        ..status = 3
        ..year = '2008';
      final params = _params(query.url('en-US'));
      expect(Uri.parse(query.url('en-US')).path, '/3/discover/tv');
      expect(params['with_status'], '2'); // in_production
      expect(params['first_air_date_year'], '2008');
      expect(params['vote_count.gte'], '0');
      expect(params.containsKey('include_adult'), isFalse);
      expect(params.containsKey('primary_release_year'), isFalse);
      expect(query.activeCount, 2);
    });

    test('Clear goes back to everything, most popular first', () {
      final query = DiscoverQuery(MediaKind.movie)
        ..sort = 3
        ..year = '2000'
        ..genres.add('28');
      query.clear();
      expect(query.activeCount, 0);
      expect(_params(query.url('en'))['sort_by'], 'popularity.desc');
    });

    test('countries: any of them, by origin', () {
      final query = DiscoverQuery(MediaKind.series)
        ..countries.addAll(<String>['KR', 'JP']);
      final params = _params(query.url('en'));
      // A bar asks TMDB for titles from either; a comma would ask for both.
      expect(params['with_origin_country'], 'KR|JP');
      expect(query.activeCount, 2);
      query.clear();
      expect(query.countries, isEmpty);
      expect(
        _params(query.url('en')).containsKey('with_origin_country'),
        isFalse,
      );
    });

    test('a flag for each country that has one', () {
      expect(DiscoverQuery.flag('KR'), '\u{1F1F0}\u{1F1F7}');
      expect(DiscoverQuery.flag('et'), '\u{1F1EA}\u{1F1F9}');
      // The Soviet Union and Yugoslavia are gone, and so are their flags.
      expect(DiscoverQuery.flag('SU'), isNull);
      expect(DiscoverQuery.flag('YU'), isNull);
      expect(DiscoverQuery.flag('1A'), isNull);
    });

    test('countries are found by either name or code, prefixes first', () {
      const all = <DiscoverCountry>[
        (code: 'ES', name: 'España', englishName: 'Spain'),
        (code: 'KR', name: 'Corea del Sur', englishName: 'South Korea'),
        (code: 'KP', name: 'Corea del Norte', englishName: 'North Korea'),
        (code: 'ZA', name: 'Sudáfrica', englishName: 'South Africa'),
      ];
      List<String> codes(String search) =>
          DiscoverQuery.matchCountries(all, search).map((c) => c.code).toList();
      expect(codes('corea'), <String>['KR', 'KP']);
      // The English name finds it in any language, for the TV's keyboard.
      expect(codes('spain'), <String>['ES']);
      expect(codes('korea'), <String>['KR', 'KP']);
      expect(codes('south'), <String>['KR', 'ZA']);
      expect(codes('za'), <String>['ZA']);
      expect(codes(''), hasLength(4));
    });

    test('browsing: the chosen first, then the popular, then A to Z', () {
      const all = <DiscoverCountry>[
        (code: 'AR', name: 'Argentina', englishName: 'Argentina'),
        (code: 'ET', name: 'Ethiopia', englishName: 'Ethiopia'),
        (code: 'KR', name: 'Korea', englishName: 'South Korea'),
      ];
      final order = DiscoverQuery.browseCountries(all, <String>{'ET', 'KR'});
      expect(order.first.code, 'ET');
      // A popular one stays with the popular, named as TMDB names it.
      expect(order.where((c) => c.code == 'KR').single.name, 'Korea');
      expect(
        order.map((c) => c.code).skip(1).take(16),
        DiscoverQuery.featuredCountries.map((c) => c.code),
      );
      expect(order.last.code, 'AR');
      expect(order, hasLength(1 + 16 + 1));
    });

    test('years run from this one back to 1950', () {
      final years = DiscoverQuery.years(now: DateTime(2031, 1, 1));
      expect(years.first, '2031');
      expect(years.last, '1950');
    });
  });

  testWidgets('each kind keeps its own filters, and results open with them',
      (tester) async {
    final opened = <MediaCollection>[];
    final counted = <String>[];
    final lastYear = '${DateTime.now().year - 1}';
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ],
        child: MaterialApp(
          home: DiscoverScreen(
            openResults: (_, results) => opened.add(results),
            // Nothing matches a request for this year's comedies.
            countResults: (url) async {
              counted.add(url);
              return url.contains('with_genres=35') &&
                      url.contains('year=$lastYear')
                  ? 0
                  : 1234;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The count arrives once the choices settle.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('show_titles'), findsOneWidget);
    expect(counted, hasLength(1));

    final list = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    Future<void> reach(Finder finder) async {
      await tester.scrollUntilVisible(finder, 200, scrollable: list);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    // Movies: a genre, a year, a ratings floor.
    await reach(find.text('comedy'));
    await tester.tap(find.text('comedy'));
    await reach(find.text(lastYear));
    await tester.tap(find.text(lastYear));
    await settle();
    // Those choices find nothing: the button says so and holds back.
    expect(find.text('no_titles_match'), findsOneWidget);
    // The choices show at the top, each removable.
    await tester.drag(list, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text(lastYear), findsOneWidget);
    await tester.tap(find.text(lastYear));
    await settle();
    expect(find.text('show_titles'), findsOneWidget);
    await reach(find.text('MINIMUM_RATINGS'));
    await tester.drag(list, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ratings_at_least').at(1));
    await settle();

    // Series start clean, with their own options.
    await tester.drag(list, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('series'));
    await tester.pumpAndSettle();
    // Nothing chosen yet for series.
    expect(find.byIcon(PhosphorIcons.x()), findsNothing);
    await reach(find.text('TV_SERIES_STATUS'));

    // And back: the movie filters are still set.
    await tester.drag(list, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('movies'));
    await tester.pumpAndSettle();
    // Comedy and the ratings floor, still there to remove.
    expect(find.byIcon(PhosphorIcons.x()), findsNWidgets(2));

    await tester.tap(find.text('show_titles'));
    await tester.pumpAndSettle();
    final results = opened.single;
    expect(results.adPlacement, 'discover_movies');
    expect(results.title, 'discover_movies');
    expect(results.id, contains('with_genres=35'));
    expect(results.id, contains('vote_count.gte=1000'));

    await tester.tap(find.text('clear_all'));
    await settle();
    expect(find.byIcon(PhosphorIcons.x()), findsNothing);
  });

  testWidgets('countries: popular ones at hand, any other by search',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <MediaCollection>[];
    final counted = <String>[];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ],
        child: MaterialApp(
          home: DiscoverScreen(
            openResults: (_, results) => opened.add(results),
            countResults: (url) async {
              counted.add(url);
              return 1234;
            },
            loadCountries: (_) async => const <DiscoverCountry>[
              (code: 'ET', name: 'Ethiopia', englishName: 'Ethiopia'),
              (code: 'JP', name: 'Japan', englishName: 'Japan'),
              (code: 'KR', name: 'South Korea', englishName: 'South Korea'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    Future<void> settle() async {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    final korea = find.textContaining('South Korea');
    await tester.scrollUntilVisible(korea, 200, scrollable: list);
    await tester.tap(korea);
    await settle();
    expect(
        Uri.parse(counted.last).queryParameters['with_origin_country'], 'KR');

    // One that isn't popular, found by name.
    await tester.tap(find.text('more_countries'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'eth');
    await tester.pumpAndSettle();
    expect(find.text('Japan'), findsNothing);
    await tester.tap(find.text('Ethiopia'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Ethiopia'))).pop();
    await settle();
    expect(
      Uri.parse(counted.last).queryParameters['with_origin_country'],
      'KR|ET',
    );
    // It joins the popular ones, chosen, to take back in place.
    await tester.drag(list, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.byIcon(PhosphorIcons.x()), findsNWidgets(2));

    await tester.tap(find.text('show_titles'));
    await tester.pumpAndSettle();
    expect(opened.single.id, contains('with_origin_country=KR%7CET'));
  });

  for (final size in const <Size>[Size(768, 1024), Size(1024, 768)]) {
    testWidgets('a $size tablet, 1.3 text, right to left: nothing overflows',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(1.3),
          ),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
              ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
            ],
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: DiscoverScreen(
                  openResults: (_, __) {},
                  countResults: (_) async => 1234,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 8; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('targets are 48 dp and labelled', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ],
        child: MaterialApp(
          home: DiscoverScreen(
            openResults: (_, __) {},
            countResults: (_) async => 1234,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
