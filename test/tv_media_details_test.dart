import 'package:flixquest/catalog/person_credits.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/data/ads/content_ads.dart';
import 'package:flixquest/models/credits.dart';
import 'package:flixquest/models/person.dart' show PersonDetails;
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/videos.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/recently_watched_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/services/hosted_ads_repository.dart';
import 'package:flixquest/services/device_presentation_service.dart';
import 'package:flixquest/services/video_launcher.dart';
import 'package:flixquest/tv/controllers/tv_media_details_controller.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/screens/tv_media_details_screen.dart';
import 'package:flixquest/tv/screens/tv_person_screen.dart';
import 'package:flixquest/widgets/network_banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/tv_localization.dart';

import 'support/fake_adsterra_webview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// No artwork, so nothing reaches for the network.
TvMediaItem _item(int id,
        {TvMediaKind kind = TvMediaKind.series, List<int>? genreIds}) =>
    TvMediaItem(
      kind: kind,
      id: id,
      title: 'Title $id',
      overview: 'Overview $id',
      posterPath: null,
      backdropPath: null,
      rating: 8,
      releaseDate: '2024-01-01',
      series: kind == TvMediaKind.series && genreIds != null
          ? TV(id: id, name: 'Title $id', genreIds: genreIds)
          : null,
    );

Results _video(String key, {String type = 'Trailer'}) =>
    Results(name: 'Video $key', videoLink: key, type: type, site: 'YouTube');

RecentEpisode _watched({
  required int seriesId,
  int season = 2,
  int episode = 4,
  int elapsed = 600,
  int remaining = 1200,
}) =>
    RecentEpisode(
      dateTime: '2026-09-01',
      elapsed: elapsed,
      episodeName: 'Watched',
      episodeNum: episode,
      id: 9000 + episode,
      posterPath: null,
      remaining: remaining,
      seasonNum: season,
      seriesName: 'Title $seriesId',
      seriesId: seriesId,
    );

RecentMovie _watchedMovie(int id, {int elapsed = 600, int remaining = 3000}) =>
    RecentMovie(
      backdropPath: null,
      dateTime: '2026-09-01',
      elapsed: elapsed,
      id: id,
      posterPath: null,
      releaseYear: 2024,
      remaining: remaining,
      title: 'Title $id',
    );

/// Someone's page without the network: one movie each.
class _FakePeople implements PersonSource {
  final List<int> opened = <int>[];

  @override
  Future<PersonDetails> details(int personId) async {
    opened.add(personId);
    return PersonDetails(id: personId, name: 'Person $personId');
  }

  @override
  Future<List<PersonCredit>> credits(int personId, TvMediaKind kind) async =>
      kind == TvMediaKind.movie
          ? <PersonCredit>[
              PersonCredit(item: _item(900 + personId, kind: kind)),
            ]
          : const <PersonCredit>[];
}

/// Serves a series with Specials and two seasons, without the network.
class _FakeController extends TvMediaDetailsController {
  _FakeController({
    this.videos = const <Results>[],
    this.videosFail = false,
    Credits? credits,
  }) : credits = credits ?? Credits();

  final List<int> seasonsLoaded = <int>[];
  List<Results> videos;

  /// Fails the videos request until a test clears it.
  bool videosFail;
  int videoLoads = 0;
  Credits credits;
  final _FakePeople people = _FakePeople();

  @override
  Future<Credits> loadCredits({
    required TvMediaItem item,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async =>
      credits;

  @override
  PersonSource personSource({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) =>
      people;

  @override
  Future<List<Results>> loadVideos({
    required TvMediaItem item,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    videoLoads++;
    if (videosFail) throw Exception('offline');
    return videos;
  }

  @override
  Future<TvMediaDetailsData> load({
    required TvMediaItem item,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    if (item.kind == TvMediaKind.movie) {
      return TvMediaDetailsData(
        item: item,
        recommendations: <TvMediaItem>[
          for (var i = 0; i < 4; i++) _item(500 + i, kind: TvMediaKind.movie),
        ],
      );
    }
    return TvMediaDetailsData(
      item: item,
      seriesDetails: TVDetails(
        numberOfSeasons: 2,
        seasons: <Seasons>[
          Seasons(seasonNumber: 0, name: 'Specials'),
          Seasons(seasonNumber: 1, name: 'Season 1'),
          Seasons(seasonNumber: 2, name: 'Season 2'),
        ],
      ),
      recommendations: <TvMediaItem>[
        for (var i = 0; i < 4; i++) _item(500 + i),
      ],
    );
  }

  @override
  Future<List<EpisodeList>> loadSeason({
    required int seriesId,
    required int seasonNumber,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    seasonsLoaded.add(seasonNumber);
    return <EpisodeList>[
      for (var number = 1; number <= 6; number++)
        EpisodeList(
          episodeId: seasonNumber * 100 + number,
          episodeNumber: number,
          seasonNumber: seasonNumber,
          name: 'Episode $seasonNumber-$number',
          airDate: '2024-01-0$number',
        ),
    ];
  }

  @override
  Future<bool> isBookmarked(TvMediaItem item) async => false;
}

/// Recently watched progress without the database, or the Firebase sync
/// the real provider starts, behind it.
class _FakeRecent extends ChangeNotifier implements RecentProvider {
  _FakeRecent({this.recentMovies = const [], this.recentEpisodes = const []});

  final List<RecentMovie> recentMovies;
  final List<RecentEpisode> recentEpisodes;

  @override
  List<RecentMovie> get movies => recentMovies;

  @override
  List<RecentEpisode> get episodes => recentEpisodes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<_FakeController> _pumpDetails(
  WidgetTester tester, {
  TvMediaItem? item,
  RecentProvider? recent,
  AppDependencyProvider? dependencies,
  _FakeController? controller,
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  controller ??= _FakeController();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (_) => dependencies ?? AppDependencyProvider(),
        ),
        if (recent != null)
          ChangeNotifierProvider<RecentProvider>.value(value: recent),
      ],
      child: MaterialApp(
        home: TvMediaDetailsScreen(
          item: item ?? _item(42),
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  initializeTvTranslations();
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    // Titles without genre ids are asked about; these have none of note.
    ContentAds.lookup = (_, __) async => const <int>[];
  });

  tearDown(ContentAds.reset);

  testWidgets(
    'TV details lays out the enabled top-right banner slot',
    (tester) async {
      final device = DevicePresentationService.instance;
      WebViewPlatform.instance = FakeAdsterraWebViewPlatform();
      device.isTelevision = true;
      HostedAdsRepository.instance.useFetcherForTesting((_) async => []);
      addTearDown(() {
        device.isTelevision = false;
        HostedAdsRepository.instance.useFetcherForTesting((_) async => []);
      });
      final dependencies = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig());
      await _pumpDetails(tester, dependencies: dependencies);

      final banner = find.byType(NetworkBannerWidget);
      expect(banner, findsOneWidget);
      expect(
          tester.widget<NetworkBannerWidget>(banner).placement, 'title_detail');
      final slot = tester.widget<Positioned>(
        find.ancestor(of: banner, matching: find.byType(Positioned)).first,
      );
      expect(slot.right, isNotNull);
      expect(slot.top, isNotNull);
      expect(slot.width, 360);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'a Kids series shows no banner on its TV page',
    (tester) async {
      final device = DevicePresentationService.instance;
      WebViewPlatform.instance = FakeAdsterraWebViewPlatform();
      device.isTelevision = true;
      var hostedRequests = 0;
      HostedAdsRepository.instance.useFetcherForTesting((_) async {
        hostedRequests++;
        return [];
      });
      addTearDown(() {
        device.isTelevision = false;
        HostedAdsRepository.instance.useFetcherForTesting((_) async => []);
      });
      final dependencies = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig());
      await _pumpDetails(
        tester,
        item: _item(42, genreIds: <int>[16, FamilyGenres.kids]),
        dependencies: dependencies,
      );

      expect(find.byType(NetworkBannerWidget), findsNothing);
      expect(hostedRequests, 0);
      expect(find.text('Play S1:E1'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  group('TvResumePoint', () {
    test('resumes a movie part way through', () {
      final point = TvResumePoint.forItem(
        _item(1, kind: TvMediaKind.movie),
        movies: <RecentMovie>[_watchedMovie(2), _watchedMovie(1)],
        episodes: const <RecentEpisode>[],
      )!;
      expect(point.elapsed, 600);
      expect(point.progress, moreOrLessEquals(600 / 3600));
      expect(point.timeLeft, '50m left');
      expect(point.episodeLabel, isNull);
    });

    test('starts a finished or untouched movie over', () {
      expect(
        TvResumePoint.forItem(
          _item(1, kind: TvMediaKind.movie),
          movies: <RecentMovie>[_watchedMovie(1, elapsed: 5000, remaining: 60)],
          episodes: const <RecentEpisode>[],
        ),
        isNull,
      );
      expect(
        TvResumePoint.forItem(
          _item(1, kind: TvMediaKind.movie),
          movies: <RecentMovie>[_watchedMovie(1, elapsed: 0)],
          episodes: const <RecentEpisode>[],
        ),
        isNull,
      );
    });

    test('picks the series episode watched most recently', () {
      final point = TvResumePoint.forItem(
        _item(7),
        movies: const <RecentMovie>[],
        episodes: <RecentEpisode>[
          _watched(seriesId: 8),
          _watched(seriesId: 7, season: 3, episode: 1, remaining: 90),
          _watched(seriesId: 7),
        ],
      )!;
      expect(point.episodeLabel, 'S3:E1');
      // Nearly done: Play moves on to the next episode.
      expect(point.finished, isTrue);
    });

    test('formats runtimes the way the facts line shows them', () {
      expect(formatRuntime(const Duration(minutes: 134)), '2h 14m');
      expect(formatRuntime(const Duration(minutes: 48)), '48m');
      expect(formatRuntime(const Duration(minutes: 120)), '2h');
      expect(formatRuntime(const Duration(seconds: 20)), '1m');
    });
  });

  group('seasons', () {
    final seasons = <Seasons>[
      Seasons(seasonNumber: 1),
      Seasons(seasonNumber: 2),
    ];

    test('the page opens on the season being watched', () {
      final resume = TvResumePoint(
        elapsed: 10,
        remaining: 900,
        episode: _watched(seriesId: 1),
      );
      expect(initialSeasonNumber(seasons, resume), 2);
      expect(initialSeasonNumber(seasons, null), 1);
      expect(initialSeasonNumber(const <Seasons>[], null), isNull);
    });

    test('specials come after the regular seasons', () {
      final data = TvMediaDetailsData(
        item: _item(1),
        recommendations: const <TvMediaItem>[],
        seriesDetails: TVDetails(
          seasons: <Seasons>[
            Seasons(seasonNumber: 0),
            Seasons(seasonNumber: 1),
            Seasons(),
          ],
        ),
      );
      expect(data.seasons.map((season) => season.seasonNumber), <int>[1, 0]);
    });

    test('finds the next episode and knows what has aired', () {
      final episodes = <EpisodeList>[
        EpisodeList(episodeNumber: 1),
        EpisodeList(episodeNumber: 2, airDate: '2030-01-01'),
      ];
      expect(episodeAfter(episodes, 1)?.episodeNumber, 2);
      expect(episodeAfter(episodes, 2), isNull);
      expect(hasAired(episodes.first), isTrue);
      expect(hasAired(episodes.last, now: DateTime(2026)), isFalse);
    });
  });

  group('details page', () {
    testWidgets('opens on Play, offering the first episode', (tester) async {
      await _pumpDetails(tester);
      expect(_focused, 'TV details play');
      expect(find.text('Play S1:E1'), findsOneWidget);
      expect(find.text('Episodes'), findsWidgets);
      expect(find.text('My List'), findsOneWidget);
    });

    testWidgets('loads the opening season once', (tester) async {
      final controller = await _pumpDetails(tester);
      expect(controller.seasonsLoaded, <int>[1]);
      expect(find.text('Episode 1-1'), findsNothing,
          reason: 'cards show "1. Episode 1-1"');
      expect(find.text('1. Episode 1-1'), findsOneWidget);
    });

    testWidgets('Down steps through seasons, episodes and More like this',
        (tester) async {
      await _pumpDetails(tester);

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'details-seasons:42:1');

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'details-episodes:42:1:1');

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'details-similar:series:42:series:500');

      // Each row returns to where it was left.
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused, 'details-episodes:42:1:2');

      await _press(tester, LogicalKeyboardKey.arrowUp);
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused, 'TV details play');
    });

    testWidgets('Back from the rows returns to the actions', (tester) async {
      await _pumpDetails(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'details-episodes:42:1:1');

      await _press(tester, LogicalKeyboardKey.escape);
      expect(_focused, 'TV details play');
    });

    testWidgets('a season loads once focus settles on it', (tester) async {
      final controller = await _pumpDetails(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);

      // Sweeping past Season 2 to Specials fetches only where it stops.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_focused, 'details-seasons:42:0');
      expect(controller.seasonsLoaded, <int>[1]);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(controller.seasonsLoaded, <int>[1, 0]);
      expect(find.text('1. Episode 0-1'), findsOneWidget);

      // Down lands in the season just chosen.
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'details-episodes:42:0:1');

      // Back to a season already loaded, which is not fetched again.
      await _press(tester, LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_focused, 'details-seasons:42:1');
      expect(controller.seasonsLoaded, <int>[1, 0]);
      expect(find.text('1. Episode 1-1'), findsOneWidget);
    });

    testWidgets('Specials sit after the regular seasons', (tester) async {
      await _pumpDetails(tester);
      final season1 = tester.getTopLeft(find.text('Season 1')).dx;
      final season2 = tester.getTopLeft(find.text('Season 2')).dx;
      final specials = tester.getTopLeft(find.text('Specials')).dx;
      expect(season1, lessThan(season2));
      expect(season2, lessThan(specials));
    });

    group('videos', () {
      late List<Uri> opened;
      var opens = true;

      setUp(() {
        opened = <Uri>[];
        opens = true;
        launchExternalUrl = (url) async {
          opened.add(url);
          return opens;
        };
      });

      tearDown(() => launchExternalUrl =
          (url) async => throw StateError('no launcher in tests'));

      testWidgets('sit between the episodes and More like this',
          (tester) async {
        await _pumpDetails(
          tester,
          controller: _FakeController(
            videos: <Results>[_video('aaa'), _video('bbb', type: 'Teaser')],
          ),
        );
        expect(find.text('Videos'), findsOneWidget);
        expect(find.text('Video aaa'), findsOneWidget);
        expect(find.text('Teaser'), findsOneWidget);

        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-episodes:42:1:1');

        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-videos:series:42:aaa');
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(_focused, 'details-videos:series:42:bbb');

        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-similar:series:42:series:500');

        // Up comes back to the video it left.
        await _press(tester, LogicalKeyboardKey.arrowUp);
        expect(_focused, 'details-videos:series:42:bbb');
        await _press(tester, LogicalKeyboardKey.arrowUp);
        expect(_focused, 'details-episodes:42:1:1');

        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.escape);
        expect(_focused, 'TV details play');
      });

      testWidgets('a movie reaches them straight from its actions',
          (tester) async {
        await _pumpDetails(
          tester,
          item: _item(7, kind: TvMediaKind.movie),
          controller: _FakeController(videos: <Results>[_video('aaa')]),
        );
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-videos:movie:7:aaa');
      });

      testWidgets('open in YouTube and keep focus on the card', (tester) async {
        await _pumpDetails(
          tester,
          controller: _FakeController(videos: <Results>[_video('aaa')]),
        );
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.select);

        expect(opened, <Uri>[Uri.parse('https://youtube.com/watch?v=aaa')]);
        expect(_focused, 'details-videos:series:42:aaa');
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('say so when nothing can open the video', (tester) async {
        opens = false;
        await _pumpDetails(
          tester,
          controller: _FakeController(videos: <Results>[_video('aaa')]),
        );
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.select);

        expect(opened, hasLength(1));
        expect(
          find.text(
              'This video could not be opened. Install YouTube and try again.'),
          findsOneWidget,
        );
        expect(_focused, 'details-videos:series:42:aaa');
      });

      testWidgets('that fail offer a Retry Down reaches', (tester) async {
        final controller = _FakeController(
          videos: <Results>[_video('aaa')],
          videosFail: true,
        );
        await _pumpDetails(tester, controller: controller);
        expect(find.text('Videos could not be loaded.'), findsOneWidget);
        expect(find.text('Play S1:E1'), findsOneWidget,
            reason: 'the rest of the page does not wait on the videos');

        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'TV details videos retry');

        controller.videosFail = false;
        await _press(tester, LogicalKeyboardKey.select);
        expect(controller.videoLoads, 2);
        expect(find.text('Videos could not be loaded.'), findsNothing);
        expect(_focused, 'details-videos:series:42:aaa');
      });
    });

    group('cast and crew', () {
      Credits credits() => Credits(
            cast: <Cast>[
              // Out of billing order, as TMDB can send them.
              Cast(id: 2, name: 'Second Lead', character: 'Sidekick', order: 1),
              Cast(id: 1, name: 'Lead', character: 'Hero', order: 0),
            ],
            crew: <Crew>[
              Crew(id: 3, name: 'Maker', job: 'Director'),
              Crew(id: 4, name: 'Grip', job: 'Key Grip'),
            ],
          );

      testWidgets('sit between the episodes and the videos', (tester) async {
        await _pumpDetails(
          tester,
          controller: _FakeController(
            credits: credits(),
            videos: <Results>[_video('aaa')],
          ),
        );
        expect(find.text('Cast And Crew'), findsOneWidget);
        expect(find.text('Hero'), findsOneWidget);
        expect(find.text('Director'), findsOneWidget);
        expect(find.text('Grip'), findsNothing,
            reason: 'only who made the title, not the whole crew');

        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-episodes:42:1:1');

        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-cast:series:42:cast:1',
            reason: 'billing order, not the order TMDB listed them');
        await _press(tester, LogicalKeyboardKey.arrowRight);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(_focused, 'details-cast:series:42:crew:3');

        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-videos:series:42:aaa');
        await _press(tester, LogicalKeyboardKey.arrowUp);
        expect(_focused, 'details-cast:series:42:crew:3');

        await _press(tester, LogicalKeyboardKey.escape);
        expect(_focused, 'TV details play');
      });

      testWidgets('a movie reaches them straight from its actions',
          (tester) async {
        await _pumpDetails(
          tester,
          item: _item(7, kind: TvMediaKind.movie),
          controller: _FakeController(credits: credits()),
        );
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-cast:movie:7:cast:1');
      });

      testWidgets('nobody listed leaves no row to stop on', (tester) async {
        await _pumpDetails(tester);
        expect(find.text('Cast And Crew'), findsNothing);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focused, 'details-similar:series:42:series:500');
      });

      testWidgets('a face opens their page, and Back returns to it',
          (tester) async {
        final controller = _FakeController(credits: credits());
        await _pumpDetails(
          tester,
          item: _item(7, kind: TvMediaKind.movie),
          controller: controller,
        );
        await _press(tester, LogicalKeyboardKey.arrowDown);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(_focused, 'details-cast:movie:7:cast:2');

        await _press(tester, LogicalKeyboardKey.select);
        expect(find.byType(TvPersonScreen), findsOneWidget);
        expect(controller.people.opened, <int>[2]);
        // The name TMDB gives on their page, over the credit's.
        expect(find.text('Person 2'), findsWidgets);

        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.byType(TvPersonScreen), findsNothing);
        expect(_focused, 'details-cast:movie:7:cast:2');
      });
    });

    group('action buttons', () {
      Future<void> expectSteps(WidgetTester tester, List<String> ids) async {
        expect(_focused, 'TV details ${ids.first}');
        for (final id in ids.skip(1)) {
          await _press(tester, LogicalKeyboardKey.arrowRight);
          expect(_focused, 'TV details $id');
        }
        // The last button holds; nothing below or beside it is picked up.
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(_focused, 'TV details ${ids.last}');
        for (final id in ids.reversed.skip(1)) {
          await _press(tester, LogicalKeyboardKey.arrowLeft);
          expect(_focused, 'TV details $id');
        }
      }

      testWidgets('a series in progress steps through all four in order',
          (tester) async {
        await _pumpDetails(
          tester,
          recent: _FakeRecent(recentEpisodes: <RecentEpisode>[
            _watched(seriesId: 42, season: 1, episode: 2),
          ]),
        );
        expect(find.text('Resume S1:E2'), findsOneWidget);
        expect(find.text('Play from S1:E1'), findsOneWidget);

        // One line, however wide the labels run.
        final top = tester.getTopLeft(find.text('Resume S1:E2')).dy;
        // The first "Episodes" is the button; the seasons row shares the name.
        // (Within a pixel: the focused button is scaled up slightly. A second
        // line would sit a whole button lower.)
        expect(
          tester.getTopLeft(find.text('Episodes').first).dy,
          moreOrLessEquals(top, epsilon: 2),
        );
        expect(
          tester.getTopLeft(find.text('My List')).dy,
          moreOrLessEquals(top, epsilon: 2),
        );

        await expectSteps(
          tester,
          <String>['play', 'restart', 'episodes', 'list'],
        );
      });

      testWidgets('a movie in progress steps through its three',
          (tester) async {
        await _pumpDetails(
          tester,
          item: _item(7, kind: TvMediaKind.movie),
          recent: _FakeRecent(recentMovies: <RecentMovie>[_watchedMovie(7)]),
        );
        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Play from start'), findsOneWidget);
        await expectSteps(tester, <String>['play', 'restart', 'list']);
      });
    });
  });
}
