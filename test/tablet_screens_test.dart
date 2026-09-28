import 'package:flixquest/catalog/details_play.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/season_source.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/mobile/screens/credits_screen.dart';
import 'package:flixquest/mobile/screens/episode_screen.dart';
import 'package:flixquest/mobile/screens/season_screen.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/models/credits.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/models/images.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/videos.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/bookmark_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _series = MediaItem.fromSeries(TV(
  id: 9,
  name: 'Dark',
  firstAirDate: '2017-12-01',
  overview: 'A missing child sets four families on a frantic hunt.',
  voteAverage: 8.4,
  backdropPath: '/dark.jpg',
));

final _seasons = <Seasons>[
  Seasons(seasonNumber: 1, name: 'Season 1', episodeCount: 10),
  Seasons(seasonNumber: 2, name: 'Season 2', episodeCount: 8),
];

final _episodes = <EpisodeList>[
  for (var number = 1; number <= 8; number++)
    EpisodeList(
      seasonNumber: 1,
      episodeNumber: number,
      episodeId: 100 + number,
      name: 'Episode number $number with a fairly long name',
      airDate: '2017-12-01',
      runtime: 51,
      overview: 'A boy goes missing and the town starts to talk. ' * 3,
    ),
];

Credits _credits() => Credits(
      cast: <Cast>[
        for (var i = 0; i < 12; i++)
          Cast(
            id: i,
            name: 'Actor number $i with a long name',
            order: i,
            character: 'A character with a rather long description $i',
          ),
      ],
      episodeGuestStars: <TVEpisodeGuestStars>[
        TVEpisodeGuestStars(id: 50, name: 'Guest', character: 'Visitor'),
      ],
      crew: <Crew>[
        Crew(
            id: 70,
            name: 'Baran bo Odar',
            job: 'Director',
            department: 'Directing'),
        Crew(
            id: 71,
            name: 'Jantje Friese',
            job: 'Writer',
            department: 'Writing'),
      ],
    );

class _Source implements SeasonSource {
  @override
  Future<TVDetails> series(int seriesId) async =>
      TVDetails(numberOfSeasons: 2, seasons: _seasons);

  @override
  Future<List<Genres>> genres(int seriesId) async =>
      <Genres>[Genres(genreID: 80, genreName: 'Crime')];

  @override
  Future<List<EpisodeList>> episodes(int seriesId, int season) async =>
      _episodes;

  @override
  Future<Credits> seasonCredits(int seriesId, int season) async => _credits();

  @override
  Future<Images> seasonImages(int seriesId, int season) async =>
      Images(backdrop: <Backdrops>[Backdrops(filePath: '/b.jpg')]);

  @override
  Future<Videos> seasonVideos(int seriesId, int season) async => Videos();

  @override
  Future<EpisodeList> episode(int seriesId, int season, int episode) async =>
      _episodes[episode - 1];

  @override
  Future<Credits> episodeCredits(int seriesId, int season, int episode) async =>
      _credits();

  @override
  Future<Images> episodeImages(int seriesId, int season, int episode) async =>
      Images(backdrop: <Backdrops>[Backdrops(filePath: '/b.jpg')]);
}

class _FakeBookmarks extends ChangeNotifier implements BookmarkProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(
  Widget home, {
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ChangeNotifierProvider<BookmarkProvider>(
          create: (_) => _FakeBookmarks(),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: Styles.themeData(
            appThemeMode: 'dark',
            isM3Enabled: true,
            lightDynamicColor: null,
            darkDynamicColor: null,
            context: context,
            appColor: AppColorsList().appColors(true).first,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(textDirection: direction, child: child!),
          ),
          home: home,
        ),
      ),
    );

Widget _season() => SeasonScreen(
      series: _series,
      seasons: _seasons,
      seasonNumber: 1,
      source: _Source(),
      history: const WatchHistory(),
      adBuilder: (_) => const SizedBox(height: 60, child: Text('AD_SLOT')),
      now: () => DateTime(2026, 9, 27),
    );

Widget _episode() => EpisodeScreen(
      series: _series,
      episode: _episodes.first,
      seasonEpisodes: _episodes,
      seasons: _seasons,
      source: _Source(),
      history: const WatchHistory(),
      adBuilder: (_) => const SizedBox(height: 60, child: Text('AD_SLOT')),
      now: () => DateTime(2026, 9, 27),
    );

Widget _creditsPage() => CreditsScreen(
      credits: Future<Credits>.value(_credits()),
      title: 'Season 1',
      kicker: 'Dark',
    );

Future<void> _sweep(WidgetTester tester) async {
  final scrollable = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollable.first, const Offset(0, -500));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  final pages = <String, Widget Function()>{
    'season': _season,
    'episode': _episode,
    'credits': _creditsPage,
  };
  final sizes = <String, Size>{
    'phone': const Size(390, 844),
    'tablet portrait': const Size(768, 1024),
    'tablet landscape': const Size(1024, 768),
    'wide': const Size(1440, 900),
  };

  for (final page in pages.entries) {
    for (final size in sizes.entries) {
      for (final variant in <(String, double, TextDirection)>[
        ('', 1, TextDirection.ltr),
        (', large text', 1.3, TextDirection.ltr),
        (', rtl', 1, TextDirection.rtl),
      ]) {
        testWidgets(
            '${page.key} at ${size.key}${variant.$1} lays out without overflow',
            (tester) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_app(
            page.value(),
            textScale: variant.$2,
            direction: variant.$3,
          ));
          await tester.pumpAndSettle();
          await _sweep(tester);

          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final page in pages.entries) {
    testWidgets('${page.key}: targets are 48 dp and labelled', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(_app(page.value()));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('the credits list keeps to a reading width on a wide screen',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_creditsPage()));
    await tester.pumpAndSettle();

    final row = find.byType(PersonRow).first;
    expect(tester.getSize(row).width, lessThanOrEqualTo(760));
    expect(tester.getCenter(row).dx, closeTo(720, 1));
  });
}
