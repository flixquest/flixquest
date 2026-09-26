import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/singleton/sharedpreferences_singleton.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/app/tv_shell_layout.dart';
import 'package:flixquest/tv/controllers/tv_catalog_controller.dart';
import 'package:flixquest/tv/controllers/tv_search_history_controller.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/screens/tv_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _metrics = TvShellMetrics(
  compact: true,
  safeInset: 16,
  railWidth: 56,
  railGap: 8,
  contentPadding: 14,
  navItemHeight: 42,
  navItemGap: 2,
  mediaCardWidth: 110,
);

// No artwork, so nothing reaches for the network.
TvMediaItem _item(int id, {TvMediaKind kind = TvMediaKind.movie}) =>
    TvMediaItem(
      kind: kind,
      id: id,
      title: 'Title $id',
      overview: 'Overview $id',
      posterPath: null,
      backdropPath: null,
      rating: 7,
      releaseDate: '2024-01-01',
    );

class _FakeCatalog extends TvCatalogController {
  _FakeCatalog({this.failSearch = false});

  final bool failSearch;
  final List<String> searches = <String>[];

  @override
  Future<TvSearchSuggestions> loadSearchSuggestions({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async =>
      TvSearchSuggestions(
        topSearches: <TvMediaItem>[for (var i = 0; i < 10; i++) _item(100 + i)],
        movieGenres: <Genres>[Genres(genreID: 28, genreName: 'Action')],
        seriesGenres: <Genres>[Genres(genreID: 18, genreName: 'Drama')],
      );

  @override
  Future<List<TvMediaItem>> search({
    required String query,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    searches.add(query);
    if (failSearch) throw Exception('offline');
    return <TvMediaItem>[
      _item(1),
      _item(2),
      _item(3, kind: TvMediaKind.series),
    ];
  }
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Types [text] on a hardware keyboard, as fast as a person would.
Future<void> _typeFast(WidgetTester tester, String text) async {
  for (final character in text.split('')) {
    await tester.sendKeyEvent(
      LogicalKeyboardKey.findKeyByKeyId(
        LogicalKeyboardKey.keyA.keyId + character.codeUnitAt(0) - 97,
      )!,
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_FakeCatalog> _pumpSearch(
  WidgetTester tester, {
  _FakeCatalog? catalog,
  List<String> recent = const <String>[],
  List<TvMediaItem>? opened,
}) async {
  // The app's singleton keeps the first instance it was given for the whole
  // run, so each test seeds that one.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferencesSingleton.getInstance();
  await preferences.clear();
  await preferences.setStringList(
    TvSearchHistoryController.preferenceKey,
    recent,
  );
  sharedPrefsSingleton = preferences;
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
            child: TvShellInsets(
              insets: const EdgeInsets.fromLTRB(80, 16, 16, 16),
              child: TvSearchScreen(
                metrics: _metrics,
                controller: fake,
                focusController: focusController,
                onOpenMedia: (item) => opened?.add(item),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // The skeleton pulses until the suggestions arrive, so it never settles.
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  testWidgets('opens on the keyboard with suggestions beside it',
      (tester) async {
    await _pumpSearch(tester, recent: <String>['dune']);
    expect(_focused, 'TV keyboard a');
    expect(find.text('Movies and series'), findsOneWidget);
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Top searches today'), findsOneWidget);
    expect(find.text('Movie genres'), findsOneWidget);
    expect(find.text('dune'), findsOneWidget);
  });

  testWidgets('keys move by column, through the wide keys and back',
      (tester) async {
    await _pumpSearch(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'TV keyboard d');

    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV keyboard delete');
    // Up again has nowhere to go and stays put.
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV keyboard delete');

    // Back down to the column it came from, not the wide key's first.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'TV keyboard d');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'TV keyboard j');
  });

  testWidgets('searches once typing pauses, not on every key', (tester) async {
    final catalog = await _pumpSearch(tester);

    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('a'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    // One letter is too little to search for.
    expect(catalog.searches, isEmpty);

    await _typeFast(tester, 'lie');
    expect(catalog.searches, isEmpty);
    await tester.pump(TvSearchScreen.typingPause);
    await tester.pumpAndSettle();
    expect(catalog.searches, <String>['alie']);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    // The keyboard keeps focus while results arrive.
    expect(_focused, 'TV keyboard a');

    // Delete and Clear edit the query; clearing returns to the suggestions.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(TvSearchScreen.typingPause);
    await tester.pumpAndSettle();
    expect(catalog.searches.last, 'ali');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'TV keyboard clear');
    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('Top searches today'), findsOneWidget);
  });

  testWidgets('Right leaves the keyboard for the rows; Left and Back return',
      (tester) async {
    final opened = <TvMediaItem>[];
    await _pumpSearch(tester, opened: opened);
    await _typeFast(tester, 'dune');
    await tester.pump(TvSearchScreen.typingPause);
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(_focused, 'search-movies:dune:movie:1');

    // Left walks back along the row before it returns to the keyboard.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'search-movies:dune:movie:2');
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'search-movies:dune:movie:1');
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'TV keyboard f');

    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'search-series:dune:series:3');
    await _press(tester, LogicalKeyboardKey.escape);
    expect(_focused, 'TV keyboard f');

    // Right returns to the row last used; opening a result there remembers
    // the search.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'search-series:dune:series:3');
    await _press(tester, LogicalKeyboardKey.select);
    expect(opened.single.id, 3);
    await tester.pumpAndSettle();
    expect(
      sharedPrefsSingleton
          .getStringList(TvSearchHistoryController.preferenceKey),
      <String>['dune'],
    );
  });

  testWidgets('a recent search runs straight away, and holding OK removes it',
      (tester) async {
    final catalog = await _pumpSearch(tester, recent: <String>['dune', 'up']);
    for (var i = 0; i < 6; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(_focused, 'search-recent:recent:dune');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('dune'), findsNothing);
    expect(catalog.searches, isEmpty);

    expect(_focused, 'search-recent:recent:up');
    await _press(tester, LogicalKeyboardKey.select);
    expect(catalog.searches, <String>['up']);
    // Focus follows into the results that replaced the tile.
    expect(_focused, startsWith('search-movies:up:'));
  });

  testWidgets('a failed search offers a retry', (tester) async {
    await _pumpSearch(tester, catalog: _FakeCatalog(failSearch: true));
    await _typeFast(tester, 'dune');
    await tester.pump(TvSearchScreen.typingPause);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });
}
