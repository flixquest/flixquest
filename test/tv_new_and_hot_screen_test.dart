import 'package:flixquest/catalog/new_and_hot.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/controllers/tv_media_details_controller.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/screens/tv_new_and_hot_screen.dart';
import 'package:flixquest/tv/widgets/tv_media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/tv_localization.dart';

const _metrics = TvShellMetrics(
  compact: true,
  safeInset: 16,
  railWidth: 56,
  railGap: 8,
  contentPadding: 14,
  navItemHeight: 42,
  navItemGap: 2,
  mediaCardWidth: 120,
);

TvMediaItem _movie(int id, String date, {num popularity = 1}) =>
    TvMediaItem.fromMovie(Movie(
      id: id,
      title: 'Movie $id',
      releaseDate: date,
      backdropPath: '/backdrop.jpg',
      overview: 'A story about movie $id.',
      popularity: popularity,
      genreIds: const <int>[28],
    ));

TvMediaItem _series(int id, String date, {num popularity = 1}) =>
    TvMediaItem.fromSeries(TV(
      id: id,
      name: 'Series $id',
      firstAirDate: date,
      backdropPath: '/backdrop.jpg',
      overview: 'A story about series $id.',
      popularity: popularity,
    ));

class _Source implements NewAndHotSource {
  bool failAll = false;
  bool failUpcoming = false;
  bool empty = false;
  int calls = 0;

  Future<List<TvMediaItem>> _answer(List<TvMediaItem> items) async {
    calls++;
    if (failAll) throw Exception('offline');
    return empty ? const <TvMediaItem>[] : items;
  }

  @override
  Future<List<TvMediaItem>> upcomingMovies() {
    if (failUpcoming) {
      calls++;
      return Future<List<TvMediaItem>>.error(Exception('offline'));
    }
    return _answer(<TvMediaItem>[
      _movie(1, '2026-11-03', popularity: 10),
      _movie(2, '2026-11-01', popularity: 5),
      // The best known of all, but too far off to lead the page.
      _movie(3, '2027-01-20', popularity: 999),
    ]);
  }

  @override
  Future<List<TvMediaItem>> seriesPremieres(DateTime today) =>
      _answer(<TvMediaItem>[_series(4, '2026-11-05', popularity: 50)]);

  @override
  Future<List<TvMediaItem>> trending(TvMediaKind kind) => _answer(<TvMediaItem>[
        for (var i = 0; i < 12; i++)
          kind == TvMediaKind.movie
              ? _movie(100 + i, '2026-01-01')
              : _series(200 + i, '2026-01-01'),
      ]);

  @override
  Future<List<Genres>> genres(TvMediaKind kind) async =>
      kind == TvMediaKind.movie
          ? <Genres>[Genres(genreID: 28, genreName: 'Action')]
          : <Genres>[];
}

/// My List without the database.
class _FakeDetails extends TvMediaDetailsController {
  final Set<String> saved = <String>{};

  @override
  Future<bool> isBookmarked(TvMediaItem item) async =>
      saved.contains(item.stableId);

  @override
  Future<bool> toggleBookmark(TvMediaItem item, bool isBookmarked) async {
    if (isBookmarked) {
      saved.remove(item.stableId);
      return false;
    }
    saved.add(item.stableId);
    return true;
  }
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness(this.source, this.details, this.focus, this.opened);

  final _Source source;
  final _FakeDetails details;
  final TvScreenFocusController focus;
  final List<TvMediaItem> opened;
}

Future<_Harness> _pump(WidgetTester tester, {_Source? source}) async {
  tester.view.physicalSize = const Size(864, 508);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness(
    source ?? _Source(),
    _FakeDetails(),
    TvScreenFocusController(),
    <TvMediaItem>[],
  );
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
            child: TvNewAndHotScreen(
              metrics: _metrics,
              onOpenMedia: harness.opened.add,
              focusController: harness.focus,
              source: harness.source,
              now: () => DateTime(2026, 11, 1, 20),
              details: harness.details,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  initializeTvTranslations();
  setUpAll(() {
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  group('NewAndHotCatalog.loadPage', () {
    test('asks for each list once and fills every row from them', () async {
      final source = _Source();
      final page = await NewAndHotCatalog(
        source,
        now: () => DateTime(2026, 11, 1),
      ).loadPage();
      // Upcoming, premieres, and the two trending lists the Top 10s share.
      expect(source.calls, 4);
      expect(
        page.premieres.map((entry) => entry.$2.id),
        <int>[2, 1, 4, 3],
        reason: 'soonest first, today included',
      );
      expect(page.everyoneWatching, hasLength(20));
      expect(page.topMovies.map((item) => item.id), hasLength(10));
      expect(page.topSeries.first.id, 200);
      expect(page.genreNames(page.premieres.first.$2), <String>['Action']);
    });

    test('one list failing leaves the rest; all failing fails', () async {
      final partial = await NewAndHotCatalog(
        _Source()..failUpcoming = true,
        now: () => DateTime(2026, 11, 1),
      ).loadPage();
      expect(partial.premieres.map((entry) => entry.$2.id), <int>[4]);
      expect(partial.topMovies, isNotEmpty);

      expect(
        NewAndHotCatalog(_Source()..failAll = true).loadPage(),
        throwsException,
      );
    });
  });

  testWidgets(
      'the billboard leads with the best-known title arriving within a month',
      (tester) async {
    final harness = await _pump(tester);
    expect(harness.focus.requestFocus(), isTrue);
    await tester.pumpAndSettle();
    expect(_focused, 'TV browse featured');
    expect(find.text('PREMIERES NOV 5'), findsOneWidget);
    expect(find.text('Series 4'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.select);
    expect(harness.opened.single.id, 4);
  });

  testWidgets('Down steps through coming, watching and both Top 10s',
      (tester) async {
    final harness = await _pump(tester);
    harness.focus.requestFocus();
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'new-coming-soon:movie:2');
    expect(find.text('COMING TODAY'), findsOneWidget);
    expect(find.text('Movie   Action'), findsOneWidget,
        reason: 'the kind and its genres, for a title with no rating yet');

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('COMING NOV 3'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'new-everyone-watching:movie:100');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'new-top-movies:movie:100');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'new-top-series:series:200');

    await _press(tester, LogicalKeyboardKey.escape);
    expect(_focused, 'TV browse featured');
  });

  testWidgets('coming cards carry the day they arrive', (tester) async {
    await _pump(tester);
    String? badgeOf(int id) => tester
        .widget<TvMediaCard>(find.descendant(
          of: find.byKey(ValueKey<String>('new-coming-soon:movie:$id')),
          matching: find.byType(TvMediaCard),
        ))
        .badge;
    expect(badgeOf(2), 'TODAY');
    expect(badgeOf(1), 'NOV 3');
  });

  testWidgets(
      'holding OK on a coming card adds it to My List, and again '
      'takes it off', (tester) async {
    final harness = await _pump(tester);
    harness.focus.requestFocus();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('Hold OK to add to My List or remove it'), findsOneWidget);

    Future<void> hold() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
    }

    await hold();
    expect(harness.details.saved, <String>{'movie:2'});
    expect(find.text('Added to My List'), findsOneWidget);
    expect(harness.opened, isEmpty, reason: 'a hold is not a press');

    await hold();
    expect(harness.details.saved, isEmpty);
    expect(find.text('Removed from My List'), findsOneWidget);

    // A press still opens it.
    await _press(tester, LogicalKeyboardKey.select);
    expect(harness.opened.single.id, 2);
  });

  testWidgets('a page that cannot load offers Retry', (tester) async {
    final source = _Source()..failAll = true;
    await _pump(tester, source: source);
    expect(
      find.text("New & Hot couldn't load. Check your connection."),
      findsOneWidget,
    );

    source.failAll = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Coming Soon'), findsOneWidget);
  });

  testWidgets('nothing new says so', (tester) async {
    await _pump(tester, source: _Source()..empty = true);
    expect(find.text('Nothing new here yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
