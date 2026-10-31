import 'package:flixquest/catalog/discover_query.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/controllers/tv_catalog_controller.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/screens/tv_discover_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/tv_localization.dart';

// No artwork, so nothing reaches for the network.
TvMediaItem _item(int id, TvMediaKind kind) => TvMediaItem(
      kind: kind,
      id: id,
      title: 'Title $id',
      overview: 'Overview $id',
      posterPath: null,
      backdropPath: null,
      rating: 7,
      releaseDate: '2024-01-01',
    );

/// Serves every discover request from memory, noting what was asked.
class _FakeCatalog extends TvCatalogController {
  _FakeCatalog({this.empty = false});

  /// Finds nothing, whatever the filters.
  final bool empty;
  final List<String> urls = <String>[];

  Map<String, String> get lastQuery => Uri.parse(urls.last).queryParameters;

  @override
  TvCollection listCollection({
    required String id,
    required TvMediaKind kind,
    required String url,
    required String title,
    required String kicker,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    String? adPlacement,
  }) {
    urls.add(url);
    return TvCollection(
      id: id,
      title: title,
      kicker: kicker,
      loadPage: (page) async => empty || page > 2
          ? const <TvMediaItem>[]
          : <TvMediaItem>[
              for (var i = 0; i < 20; i++) _item(page * 100 + i, kind),
            ],
    );
  }
}

const _countries = <DiscoverCountry>[
  (code: 'ET', name: 'Ethiopia', englishName: 'Ethiopia'),
  (code: 'JP', name: 'Japan', englishName: 'Japan'),
  (code: 'KR', name: 'South Korea', englishName: 'South Korea'),
  (code: 'NG', name: 'Nigeria', englishName: 'Nigeria'),
];

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Lets the filters settle and the results follow.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(TvDiscoverScreen.settlePause);
  await tester.pumpAndSettle();
}

Future<_FakeCatalog> _pumpDiscover(
  WidgetTester tester, {
  _FakeCatalog? catalog,
  List<TvMediaItem>? opened,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sharedPrefsSingleton = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = catalog ?? _FakeCatalog();
  final focusController = TvScreenFocusController()..requestFocus();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TvFocusMemoryScope(
            memory: TvFocusMemory(),
            child: TvDiscoverScreen(
              metrics: TvShellMetrics.fromConstraints(
                const BoxConstraints.tightFor(width: 880, height: 508),
              ),
              controller: fake,
              focusController: focusController,
              countResults: (_) async => 1234,
              loadCountries: (_) async => _countries,
              onOpenMedia: (item) => opened?.add(item),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  initializeTvTranslations();
  setUpAll(() {
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');
  });

  testWidgets('opens on Movies, with the filters below and results beside',
      (tester) async {
    final catalog = await _pumpDiscover(tester);
    expect(_focused, 'TV discover movies');
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Title 100'), findsOneWidget);
    expect(find.text('1,234 titles'), findsOneWidget);
    expect(find.text('Everything, most popular first'), findsOneWidget);
    expect(catalog.urls, hasLength(1));
    // Series only filter is not offered for movies.
    expect(find.text('TV Series status'), findsNothing);
  });

  testWidgets('the remote moves between the switch, the filters and results',
      (tester) async {
    final opened = <TvMediaItem>[];
    await _pumpDiscover(tester, opened: opened);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'TV discover filter 0');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'TV discover filter 2');

    // Right into the results, on their first title.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, contains(':movie:100'));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, contains(':movie:101'));

    // Left off the first column returns to the row it came from.
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'TV discover filter 2');

    // And so does Back, from anywhere in the results.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, contains(':movie:1'));
    await _press(tester, LogicalKeyboardKey.escape);
    expect(_focused, 'TV discover filter 2');

    // Up off the first filter reaches the switch, and Down off the last
    // stays put rather than wandering into the results.
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV discover movies');
    for (var i = 0; i < 10; i++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focused, 'TV discover filter 5');

    // Back into the results on the title left there, a row down.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.select);
    expect(opened.single.id, 104);
  });

  testWidgets('genres stay open for several; Left closes them', (tester) async {
    final catalog = await _pumpDiscover(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'TV discover filter 1');
    await _press(tester, LogicalKeyboardKey.select);
    // Opens on its current answer: Any.
    expect(_focused, 'TV discover genres 1');
    expect(find.text('Any'), findsOneWidget);

    // Action, then Adventure, each taking effect behind.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.select);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.select);
    await _settle(tester);
    expect(catalog.lastQuery['with_genres'], '28,12');
    expect(_focused, 'TV discover genres 3');

    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'TV discover filter 1');
    expect(find.text('Action, Adventure'), findsWidgets);
  });

  testWidgets('a year is one answer: choosing it closes the list',
      (tester) async {
    final catalog = await _pumpDiscover(tester);
    for (var i = 0; i < 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focused, 'TV discover filter 4');
    await _press(tester, LogicalKeyboardKey.select);
    expect(_focused, 'TV discover year 1');
    // Down to last year, past rows not yet built at the start.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.select);
    await _settle(tester);
    expect(_focused, 'TV discover filter 4');
    expect(
      catalog.lastQuery['primary_release_year'],
      '${DateTime.now().year - 1}',
    );

    // Opening it again starts on that year (after the way back and Any);
    // Back closes it untouched.
    await _press(tester, LogicalKeyboardKey.select);
    expect(_focused, 'TV discover year 3');
    await _press(tester, LogicalKeyboardKey.escape);
    expect(_focused, 'TV discover filter 4');

    // The list reaches 1950 however far down it is.
    await _press(tester, LogicalKeyboardKey.select);
    for (var i = 0; i < 90; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('1950'), findsOneWidget);
    expect(
      _focused,
      'TV discover year ${DiscoverQuery.years().length + 1}',
    );
  });

  testWidgets('countries: picked from the list, or searched on a keyboard',
      (tester) async {
    final catalog = await _pumpDiscover(tester);
    for (var i = 0; i < 3; i++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focused, 'TV discover filter 2');
    await _press(tester, LogicalKeyboardKey.select);
    // The way back, Search, then Any, where it opens; then the popular
    // countries, the US leading.
    expect(_focused, 'TV discover country 2');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.select);
    await _settle(tester);
    expect(catalog.lastQuery['with_origin_country'], 'US');

    // Search, typed on the TV's own keyboard.
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV discover country 1');
    await _press(tester, LogicalKeyboardKey.select);
    expect(_focused, 'TV keyboard a');
    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyH,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pumpAndSettle();
    expect(find.text('Ethiopia'), findsOneWidget);
    expect(find.text('Japan'), findsNothing);
    // Right off the keyboard's last column enters the matches.
    for (var i = 0; i < 6; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(_focused, 'TV country 0');
    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('2 selected'), findsOneWidget);
    // Left goes back to the keyboard, Back back to Discover.
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, startsWith('TV keyboard'));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(catalog.lastQuery['with_origin_country'], 'US|ET');
    // Back on the search row, with Ethiopia now near the top.
    expect(_focused, 'TV discover country 1');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('Ethiopia'), findsOneWidget);
  });

  testWidgets('series keep their own filters, and their status',
      (tester) async {
    final catalog = await _pumpDiscover(tester);
    // A movie filter first.
    for (var i = 0; i < 6; i++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    await _press(tester, LogicalKeyboardKey.select);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.select);
    await _settle(tester);
    expect(catalog.lastQuery['vote_count.gte'], '100');

    // Up to the switch, across to Series.
    for (var i = 0; i < 6; i++) {
      await _press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(_focused, 'TV discover movies');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'TV discover series');
    await _press(tester, LogicalKeyboardKey.select);
    expect(Uri.parse(catalog.urls.last).path, '/3/discover/tv');
    expect(catalog.lastQuery['vote_count.gte'], '0');
    expect(find.text('TV Series status'), findsOneWidget);
    expect(find.text('Title 100'), findsOneWidget);

    // Back to movies: the floor is still set.
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.select);
    expect(Uri.parse(catalog.urls.last).path, '/3/discover/movie');
    expect(catalog.lastQuery['vote_count.gte'], '100');
  });

  testWidgets('nothing found: Right reaches Clear all, which starts over',
      (tester) async {
    final catalog = await _pumpDiscover(tester,
        catalog: _FakeCatalog(
          empty: true,
        ));
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.select);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.select);
    await _settle(tester);
    expect(find.text('No titles match'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'TV discover results action');
    await _press(tester, LogicalKeyboardKey.select);
    await _settle(tester);
    expect(catalog.lastQuery['with_genres'], '');
    // Focus goes back to the panel rather than nowhere.
    expect(_focused, startsWith('TV discover'));
    expect(_focused, isNot('TV discover results action'));
  });
}
