import 'package:flixquest/catalog/person_credits.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/data/ads/content_ads.dart';
import 'package:flixquest/models/credits.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/person.dart' show PersonDetails;
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/videos.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/controllers/tv_media_details_controller.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/screens/tv_collection_screen.dart';
import 'package:flixquest/tv/screens/tv_media_details_screen.dart';
import 'package:flixquest/tv/screens/tv_person_screen.dart';
import 'package:flixquest/tv/widgets/tv_reader_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/tv_localization.dart';

// No artwork, so nothing reaches for the network.
PersonCredit _movie(int id, {num popularity = 1, String? character}) =>
    PersonCredit(
      item: TvMediaItem.fromMovie(Movie(
        id: id,
        title: 'Movie $id',
        overview: 'Overview $id',
        releaseDate: '2001-01-01',
        popularity: popularity,
      )),
      characters: <String>[if (character != null) character],
    );

PersonCredit _series(int id, {num popularity = 1, String? job}) => PersonCredit(
      item: TvMediaItem.fromSeries(TV(
        id: id,
        name: 'Series $id',
        overview: 'Overview $id',
        firstAirDate: '2010-01-01',
        popularity: popularity,
      )),
      jobs: <String>[if (job != null) job],
    );

const _biography = 'Keanu Charles Reeves is a Canadian actor. ';

class _FakePeople implements PersonSource {
  _FakePeople({
    List<PersonCredit>? movies,
    List<PersonCredit>? series,
    this.adult = false,
  })  : movies = movies ??
            <PersonCredit>[
              _movie(101, popularity: 50, character: 'Neo'),
              _movie(102, popularity: 40, character: 'John Wick'),
            ],
        series = series ?? <PersonCredit>[_series(201, job: 'Producer')];

  List<PersonCredit> movies;
  List<PersonCredit> series;
  bool adult;
  bool fail = false;
  int creditLoads = 0;

  @override
  Future<PersonDetails> details(int personId) async => PersonDetails(
        id: personId,
        name: 'Keanu Reeves',
        department: 'Acting',
        birthday: '1964-09-02',
        birthPlace: 'Beirut, Lebanon',
        biography: _biography * 40,
        isAdult: adult,
      );

  @override
  Future<List<PersonCredit>> credits(int personId, TvMediaKind kind) async {
    creditLoads++;
    if (fail) throw Exception('offline');
    return kind == TvMediaKind.movie ? movies : series;
  }
}

/// Person pages and the title pages they open, without the network.
class _FakeController extends TvMediaDetailsController {
  _FakeController(this.people);

  final _FakePeople people;

  @override
  PersonSource personSource({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) =>
      people;

  @override
  Future<TvMediaDetailsData> load({
    required TvMediaItem item,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async =>
      TvMediaDetailsData(item: item, recommendations: const <TvMediaItem>[]);

  @override
  Future<List<Results>> loadVideos({
    required TvMediaItem item,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async =>
      const <Results>[];

  @override
  Future<Credits> loadCredits({
    required TvMediaItem item,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async =>
      Credits();

  @override
  Future<bool> isBookmarked(TvMediaItem item) async => false;
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<_FakePeople> _pumpPerson(
  WidgetTester tester, {
  _FakePeople? people,
  bool? isAdult,
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  people ??= _FakePeople();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
      ],
      child: MaterialApp(
        home: TvPersonScreen(
          personId: 1,
          name: 'K. Reeves',
          isAdult: isAdult,
          controller: _FakeController(people),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return people;
}

void main() {
  initializeTvTranslations();
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    ContentAds.lookup = (_, __) async => const <int>[];
  });

  tearDown(ContentAds.reset);

  testWidgets('opens on Biography with who they are on the billboard',
      (tester) async {
    await _pumpPerson(tester);
    expect(_focused, 'TV browse featured');
    expect(find.text('Biography'), findsOneWidget);
    expect(find.text('Keanu Reeves'), findsOneWidget,
        reason: "TMDB's name for them over the credit's");
    expect(find.text('ACTING'), findsOneWidget);
    expect(find.textContaining('Born on Sep 2, 1964'), findsOneWidget);
    expect(find.text('From Beirut, Lebanon'), findsOneWidget);
    expect(find.textContaining('Keanu Charles Reeves'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Down enters their better-known kind first, and the spotlight names '
      'the part they played', (tester) async {
    await _pumpPerson(tester);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'person-1-movie:movie:101');
    expect(find.text('AS NEO'), findsOneWidget);
    expect(find.text('Keanu Charles Reeves'), findsNothing,
        reason: 'browsing, the spotlight is the focused title');

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('AS JOHN WICK'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'person-1-series:series:201');
    expect(find.text('PRODUCER'), findsOneWidget,
        reason: 'a job is named as it is, not as a part');

    // Each row returns to where it was left; Up off the first is the
    // billboard.
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'person-1-movie:movie:102');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV browse featured');
  });

  testWidgets('Back from the rows returns to the billboard', (tester) async {
    await _pumpPerson(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'person-1-series:series:201');

    await _press(tester, LogicalKeyboardKey.escape);
    expect(_focused, 'TV browse featured');
  });

  testWidgets('a series-first career leads with its series', (tester) async {
    await _pumpPerson(
      tester,
      people: _FakePeople(
        movies: <PersonCredit>[_movie(101, popularity: 2)],
        series: <PersonCredit>[_series(201, popularity: 90)],
      ),
    );
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'person-1-series:series:201');
  });

  testWidgets('Biography reads the whole of it, Down scrolling it',
      (tester) async {
    await _pumpPerson(tester);
    await _press(tester, LogicalKeyboardKey.select);
    expect(find.byType(TvReaderDialog), findsOneWidget);
    expect(_focused, 'Close');
    expect(find.text('Up and Down scroll'), findsOneWidget);

    final scrollable = find.descendant(
      of: find.byType(TvReaderDialog),
      matching: find.byType(Scrollable),
    );
    double offset() =>
        tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset(), 0);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(offset(), greaterThan(0));
    expect(_focused, 'Close', reason: 'Close keeps focus while reading');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(offset(), 0);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(TvReaderDialog), findsNothing);
    expect(_focused, 'TV browse featured');
  });

  testWidgets('a long list ends in See all, which opens every title',
      (tester) async {
    await _pumpPerson(
      tester,
      people: _FakePeople(
        movies: <PersonCredit>[
          for (var i = 0; i < 25; i++) _movie(300 + i, popularity: 100 - i),
        ],
        series: const <PersonCredit>[],
      ),
    );
    await _press(tester, LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < TvPersonScreen.rowLimit; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(_focused, 'person-1-movie:#trailing-action');

    await _press(tester, LogicalKeyboardKey.select);
    expect(find.byType(TvCollectionScreen), findsOneWidget);
    expect(find.text('KEANU REEVES'), findsOneWidget);
    expect(find.text('Movie 300'), findsOneWidget);
  });

  testWidgets('a title opens its page, and Back returns to its card',
      (tester) async {
    await _pumpPerson(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.select);
    expect(find.byType(TvMediaDetailsScreen), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(TvMediaDetailsScreen), findsNothing);
    expect(_focused, 'person-1-movie:movie:102');
  });

  testWidgets("an adult person's titles stay hidden without the setting",
      (tester) async {
    await _pumpPerson(tester, isAdult: true);
    expect(
        find.text('This section contains NSFW & 18+ content'), findsOneWidget);
    expect(find.text('Movie 101'), findsNothing);
    expect(_focused, 'Biography of Keanu Reeves');
    expect(tester.takeException(), isNull);
  });

  testWidgets('their own page marking them adult hides the titles too',
      (tester) async {
    await _pumpPerson(tester, people: _FakePeople(adult: true));
    expect(
      find.text('This section contains NSFW & 18+ content'),
      findsOneWidget,
    );
    expect(find.text('Movie 101'), findsNothing);
  });

  testWidgets('nobody listed says so under Biography', (tester) async {
    await _pumpPerson(
      tester,
      people: _FakePeople(
        movies: const <PersonCredit>[],
        series: const <PersonCredit>[],
      ),
    );
    expect(
      find.text('No movies or series are listed for Keanu Reeves yet.'),
      findsOneWidget,
    );
    expect(_focused, 'Biography of Keanu Reeves');
  });

  testWidgets('titles that fail to load offer a focused Retry', (tester) async {
    final people = _FakePeople()..fail = true;
    await _pumpPerson(tester, people: people);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(_focused, 'Retry');

    people.fail = false;
    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('Something went wrong'), findsNothing);
    expect(_focused, 'TV browse featured');
  });
}
