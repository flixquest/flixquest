import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/new_and_hot.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/mobile/screens/new_and_hot_screen.dart';
import 'package:flixquest/mobile/widgets/filter_chips.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/translations/codegen_loader.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaItem _movie(int id, String date) => MediaItem.fromMovie(Movie(
      id: id,
      title: 'Movie $id',
      releaseDate: date,
      backdropPath: '/backdrop.jpg',
      overview: 'A story about movie $id.',
    ));

MediaItem _series(int id, String date) => MediaItem.fromSeries(TV(
      id: id,
      name: 'Series $id',
      firstAirDate: date,
      backdropPath: '/backdrop.jpg',
      overview: 'A story about series $id.',
    ));

class _Source implements NewAndHotSource {
  bool failMovies = false;
  int movieCalls = 0;
  int seriesCalls = 0;
  int upcomingCalls = 0;

  @override
  Future<List<MediaItem>> upcomingMovies() async {
    upcomingCalls++;
    return <MediaItem>[
      _movie(1, '2026-09-27'),
      _movie(2, '2026-09-28'),
      _movie(3, '2026-09-29'),
    ];
  }

  @override
  Future<List<MediaItem>> seriesPremieres(DateTime today) async =>
      <MediaItem>[_series(4, '2026-09-30')];

  @override
  Future<List<MediaItem>> trending(MediaKind kind) async {
    if (kind == MediaKind.movie) {
      movieCalls++;
      if (failMovies) throw Exception('offline');
      return <MediaItem>[_movie(10, '2026-09-27')];
    }
    seriesCalls++;
    return <MediaItem>[_series(11, '2026-09-27')];
  }

  @override
  Future<List<Genres>> genres(MediaKind kind) async => <Genres>[];
}

Future<void> _setUp() async {
  // EasyLocalization reads the saved locale, so the mock store comes first.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sharedPrefsSingleton = await SharedPreferences.getInstance();
  await EasyLocalization.ensureInitialized();
  dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');
}

Widget _app({
  required _Source source,
  String mode = 'dark',
  bool canPlay = true,
  Locale locale = const Locale('en'),
}) {
  final content = MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(
        create: (_) => AppDependencyProvider()..displayWatchNowButton = canPlay,
      ),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        localizationsDelegates: locale.languageCode == 'ar'
            ? context.localizationDelegates
            : const <LocalizationsDelegate<dynamic>>[
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
        theme: Styles.themeData(
          appThemeMode: mode,
          isM3Enabled: true,
          lightDynamicColor: null,
          darkDynamicColor: null,
          context: context,
          appColor: AppColorsList().appColors(mode != 'light').first,
        ),
        home: Scaffold(
          body: NewAndHotScreen(
            source: source,
            now: () => DateTime(2026, 9, 27),
            showTitleLogos: false,
            adBuilder: (_) => const Text('AD_SLOT'),
          ),
        ),
      ),
    ),
  );
  if (locale.languageCode != 'ar') return content;
  return EasyLocalization(
    supportedLocales: const <Locale>[
      Locale('en'),
      Locale('es'),
      Locale('ar'),
      Locale('hi'),
    ],
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    startLocale: locale,
    child: content,
  );
}

Future<void> _tapSegment(WidgetTester tester, String label,
    {bool rtl = false}) async {
  final target = find.text(label);
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (var i = 0; i < 8; i++) {
    var delta = rtl ? 200.0 : -200.0;
    if (target.evaluate().isNotEmpty) {
      final center = tester.getCenter(target);
      if (center.dx > 0 && center.dx < width) {
        await tester.tap(target);
        await tester.pumpAndSettle();
        return;
      }
      delta = center.dx < 0 ? 200 : -200;
    } else if (label == 'coming_soon' || label == 'قريبًا') {
      delta = rtl ? -200 : 200;
    }
    await tester.drag(find.byType(FilterChips), Offset(delta, 0));
    await tester.pumpAndSettle();
  }
  fail('Could not reach $label');
}

void main() {
  setUp(_setUp);

  testWidgets('loads Coming Soon first; pills show one segment at a time',
      (tester) async {
    final source = _Source();
    await tester.pumpWidget(_app(source: source));
    await tester.pumpAndSettle();
    expect(source.upcomingCalls, 1);
    expect(source.movieCalls, 0);
    expect(find.text('Movie 1'), findsOneWidget);
    await _tapSegment(tester, 'everyone_watching');
    expect(source.movieCalls, 1);
    expect(source.seriesCalls, 1);
    expect(find.text('Movie 10'), findsOneWidget);
    expect(find.text('Movie 1'), findsNothing);
    await _tapSegment(tester, 'top_10_movies');
    expect(find.text('Movie 10'), findsOneWidget);
    expect(find.text('Series 11'), findsNothing);
    await _tapSegment(tester, 'top_10_series');
    expect(find.text('Series 11'), findsOneWidget);
    expect(find.text('Movie 10'), findsNothing);
    await _tapSegment(tester, 'everyone_watching');
    expect(source.movieCalls,
        2); // Top 10 made one more request; return is cached.
  });

  testWidgets('Play is hidden when the remote playback flag is off',
      (tester) async {
    await tester.pumpWidget(_app(source: _Source(), canPlay: false));
    await tester.pumpAndSettle();
    await _tapSegment(tester, 'everyone_watching');
    expect(find.text('play'), findsNothing);
  });

  testWidgets('one failed segment offers Retry and reloads', (tester) async {
    final source = _Source()..failMovies = true;
    await tester.pumpWidget(_app(source: source));
    await tester.pumpAndSettle();
    await _tapSegment(tester, 'top_10_movies');
    expect(find.text('new_and_hot_load_failed'), findsOneWidget);
    expect(find.text('retry'), findsOneWidget);
    source.failMovies = false;
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(find.text('Movie 10'), findsOneWidget);
    expect(source.movieCalls, 2);
  });

  testWidgets('ad is after the third date group', (tester) async {
    await tester.pumpWidget(_app(source: _Source()));
    await tester.pumpAndSettle();
    final scroll = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    expect(find.text('Movie 1'), findsOneWidget);
    expect(find.text('AD_SLOT'), findsNothing);
    await tester.scrollUntilVisible(find.text('AD_SLOT'), 200,
        scrollable: scroll);
    expect(find.text('AD_SLOT'), findsOneWidget);
  });

  for (final mode in <String>['dark', 'light']) {
    testWidgets('$mode: accent appears only on premiere kickers',
        (tester) async {
      await tester.pumpWidget(_app(source: _Source(), mode: mode));
      await tester.pumpAndSettle();
      final accent = Theme.of(tester.element(find.byType(NewAndHotScreen)))
          .colorScheme
          .primary;
      final accentTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.style?.color == accent)
          .map((text) => text.data);
      expect(accentTexts, isNotEmpty);
      expect(
          accentTexts.every((text) =>
              text!.startsWith('COMING') || text.startsWith('PREMIERES')),
          isTrue);
      final accentIcons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((icon) => icon.color == accent);
      expect(accentIcons, isEmpty);
    });
  }

  testWidgets('320 wide, 1.3 text, Arabic: no overflow in every segment',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 700),
        textScaler: TextScaler.linear(1.3),
      ),
      child: _app(source: _Source(), locale: const Locale('ar')),
    ));
    await tester.pumpAndSettle();
    for (final label in <String>[
      'ما يشاهده الجميع',
      'أفضل ١٠ أفلام',
      'أفضل ١٠ مسلسلات',
      'قريبًا',
    ]) {
      await _tapSegment(tester, label, rtl: true);
      expect(tester.takeException(), isNull);
    }
  });
}
