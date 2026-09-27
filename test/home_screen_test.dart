import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/catalog/home_hero.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/up_next.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/mobile/screens/home_screen.dart';
import 'package:flixquest/mobile/widgets/category_section.dart';
import 'package:flixquest/mobile/widgets/hero_card.dart';
import 'package:flixquest/mobile/widgets/media_rows.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/bookmark_provider.dart';
import 'package:flixquest/provider/recently_watched_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/update_screen.dart';
import 'package:flixquest/widgets/hosted_ads_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaItem _item(MediaKind kind, int id) => kind == MediaKind.movie
    ? MediaItem.fromMovie(Movie(id: id, title: 'Movie $id'))
    : MediaItem.fromSeries(TV(id: id, name: 'Series $id'));

List<MediaItem> _movies(Iterable<int> ids) =>
    ids.map((id) => _item(MediaKind.movie, id)).toList();
List<MediaItem> _series(Iterable<int> ids) =>
    ids.map((id) => _item(MediaKind.series, id)).toList();

class _FakeSource implements HomeFeedSource {
  _FakeSource([this.fail = false]);

  bool fail;
  int loads = 0;

  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async {
    loads++;
    if (fail) throw Exception('offline');
    // TMDB has no upcoming list for series.
    if (list == HomeList.upcoming && kind == MediaKind.series) {
      return const <MediaItem>[];
    }
    final base = kind == MediaKind.movie ? 1 : 101;
    final ids = switch (list) {
      HomeList.trendingToday => <int>[base, base + 1, base + 2],
      HomeList.trendingWeek => <int>[base + 3, base + 4],
      HomeList.popular => <int>[base + 5],
      HomeList.topRated => <int>[base + 6],
      HomeList.newReleases => <int>[base + 7],
      HomeList.upcoming => <int>[base + 8],
    };
    return kind == MediaKind.movie ? _movies(ids) : _series(ids);
  }

  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) async =>
      !fail && providerId == 8
          ? (kind == MediaKind.movie ? _movies([40]) : _series([140]))
          : const <MediaItem>[];

  @override
  Future<List<Genres>> genres(MediaKind kind) async => const <Genres>[];

  @override
  Future<List<MediaItem>> discover(
    MediaKind kind, {
    required int page,
    required int year,
    required int genreId,
  }) async =>
      const <MediaItem>[];

  @override
  Future<List<MediaItem>> genre(MediaKind kind, int genreId) async =>
      _movies([70, 71]);
}

class _FakeRecent extends ChangeNotifier implements RecentProvider {
  _FakeRecent({List<RecentMovie> movies = const [], this.upNext = const []})
      : movies = List.of(movies);

  @override
  final List<RecentMovie> movies;
  @override
  final List<RecentEpisode> episodes = <RecentEpisode>[];
  @override
  final List<UpNext> upNext;

  @override
  Future<void> deleteMovie(int id) async {
    movies.removeWhere((movie) => movie.id == id);
    notifyListeners();
  }

  @override
  Future<void> addMovie(RecentMovie movie) async {
    movies.add(movie);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookmarks extends ChangeNotifier implements BookmarkProvider {
  @override
  List<Movie> movies = <Movie>[];
  @override
  List<TV> tvShows = <TV>[];

  @override
  bool isMovieBookmarked(int id) => movies.any((movie) => movie.id == id);
  @override
  bool isTVBookmarked(int id) => tvShows.any((series) => series.id == id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RecentMovie _recentMovie(int id) => RecentMovie(
      backdropPath: '/b.jpg',
      dateTime: DateTime.now().toString(),
      elapsed: 600,
      id: id,
      posterPath: null,
      releaseYear: 2024,
      remaining: 3000,
      title: 'Movie $id',
    );

Future<void> _setUp() async {
  dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sharedPrefsSingleton = await SharedPreferences.getInstance();
}

ThemeData _theme(BuildContext context, String mode) => Styles.themeData(
      appThemeMode: mode,
      isM3Enabled: true,
      lightDynamicColor: null,
      darkDynamicColor: null,
      context: context,
      appColor: AppColorsList().appColors(mode != 'light').first,
    );

Widget _app({
  required Widget child,
  RecentProvider? recent,
  BookmarkProvider? bookmarks,
  AppDependencyProvider? dependencies,
  String mode = 'dark',
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (_) => dependencies ?? AppDependencyProvider(),
        ),
        ChangeNotifierProvider<RecentProvider>.value(
          value: recent ?? _FakeRecent(),
        ),
        ChangeNotifierProvider<BookmarkProvider>.value(
          value: bookmarks ?? _FakeBookmarks(),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: _theme(context, mode),
          home: Scaffold(body: child),
        ),
      ),
    );

/// The rows Home would show for [feed], by what each is.
Future<List<Widget>> _rows(
  WidgetTester tester, {
  required HomeFilter filter,
  required HomeFeed feed,
  List<MediaItem> continueWatching = const [],
  List<MediaItem> myList = const [],
}) async {
  late List<Widget> rows;
  await tester.pumpWidget(
    _app(
      child: Builder(
        builder: (context) {
          rows = homeRows(
            context,
            filter: filter,
            feed: feed,
            continueWatching: continueWatching,
            myList: myList,
            heroes: <HomeHero>[
              if (feed.hero case final hero?) HomeHero(item: hero),
            ],
            genresFor: (_) => const <String>[],
            onHeroShown: (_) {},
            loadCategory: (_) async => const <MediaItem>[],
            onOpenCategory: (_) {},
            onOpenService: (_) {},
            onOpenList: (_, __, ___) {},
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return rows;
}

String _describe(Widget row) => switch (row) {
      HeroCarousel() => 'hero',
      HomeAdSlot() => 'ad',
      HomeOptionalRow() => 'update',
      CategorySection() => 'category',
      ContinueRow(:final title) => title,
      TopTenRow(:final title) => title,
      PosterRow(:final title) => title ?? '',
      ServiceRow(:final title) => title,
      _ => row.runtimeType.toString(),
    };

void main() {
  setUp(_setUp);

  testWidgets('All: the rows in order, three ads spread down the page',
      (tester) async {
    final feed = await HomeFeedController(_FakeSource()).load(HomeFilter.all);
    final rows = await _rows(
      tester,
      filter: HomeFilter.all,
      feed: feed,
      continueWatching: _movies([90]),
      myList: _series([150]),
    );
    // Every chart comes as a pair, movies then series; only the viewer's
    // own rows hold both. One ad sits under the hero, two further down.
    expect(rows.map(_describe), <String>[
      'hero',
      'ad',
      'continue_watching',
      'top_10_movies_today',
      'top_10_series_today',
      'trending_movies_week',
      'trending_series_week',
      'ad',
      'my_list',
      'new_movies',
      'new_episodes',
      'popular_movies',
      'popular_series',
      'popular_series_on',
      'streaming_services',
      'top_rated_movies',
      'top_rated_series',
      'upcoming_movies',
      'ad',
    ]);
    // Each slot carries its own ad-tag id, and the tab's own prefix.
    expect(
      rows.whereType<HomeAdSlot>().map((slot) => slot.placement),
      <String>['home_all_hero', 'home_all_trending', 'home_all_genres'],
    );
    // The mid-feed slot is the medium rectangle.
    expect(
      rows.whereType<HomeAdSlot>().map((slot) => slot.variant),
      <HostedBannerVariant>[
        HostedBannerVariant.standard,
        HostedBannerVariant.tall,
        HostedBannerVariant.standard,
      ],
    );
    // And no catalogue row mixes the two.
    for (final row in rows.whereType<PosterRow>()) {
      if (row.title == 'my_list') continue;
      expect(
        row.items.map((item) => item.kind).toSet(),
        hasLength(1),
        reason: row.title,
      );
    }
  });

  testWidgets('Movies and Series title their Top 10 for the kind',
      (tester) async {
    for (final (filter, title) in <(HomeFilter, String)>[
      (HomeFilter.movies, 'top_10_movies_today'),
      (HomeFilter.series, 'top_10_series_today'),
    ]) {
      final feed = await HomeFeedController(_FakeSource()).load(filter);
      final rows = await _rows(tester, filter: filter, feed: feed);
      expect(rows.map(_describe), contains(title));
      final top = rows.whereType<TopTenRow>().single;
      expect(
        top.items.every(
          (item) =>
              item.kind ==
              (filter == HomeFilter.movies
                  ? MediaKind.movie
                  : MediaKind.series),
        ),
        isTrue,
      );
    }
    // Series has no upcoming row.
    final series =
        await HomeFeedController(_FakeSource()).load(HomeFilter.series);
    final rows = await _rows(tester, filter: HomeFilter.series, feed: series);
    expect(rows.map(_describe), isNot(contains('upcoming_movies')));
  });

  testWidgets('a title shows in at most two of the first five rows',
      (tester) async {
    final feed = await HomeFeedController(_FakeSource()).load(HomeFilter.all);
    // Movie 1 is #1 today; put it in Continue Watching and My List too.
    final rows = await _rows(
      tester,
      filter: HomeFilter.all,
      feed: feed,
      continueWatching: _movies([1]),
      myList: _movies([1, 60]),
    );
    final myList = rows.whereType<PosterRow>().firstWhere(
          (row) => row.title == 'my_list',
        );
    expect(myList.items.map((item) => item.id), <int>[60]);
    expect(rows.whereType<TopTenRow>().first.items.first.id, 1);
  });

  testWidgets('loads, fades in, and switches filter', (tester) async {
    final source = _FakeSource();
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: source,
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HeroCarousel), findsOneWidget);
    expect(find.text('top_10_movies_today'), findsOneWidget);

    await tester.tap(find.text('series'));
    await tester.pumpAndSettle();
    expect(find.text('top_10_series_today'), findsOneWidget);
    expect(find.text('top_10_movies_today'), findsNothing);

    // Back to All: already loaded, so nothing is fetched again.
    final loads = source.loads;
    await tester.tap(find.text('filter_all'));
    await tester.pumpAndSettle();
    expect(find.text('top_10_movies_today'), findsOneWidget);
    expect(source.loads, loads);
  });

  testWidgets('update notice stays below filters and above the hero',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'FlixQuest',
      packageName: 'com.test.fq',
      version: '4.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final dependencies = AppDependencyProvider()
      ..setUpdateConfiguration(
        forced: false,
        latestVersion: '4.2.0',
        latestBuild: 2,
        minimumBuild: 0,
        downloadUrl: 'https://example.com/update.apk',
        changeLog: '',
      );
    await tester.pumpWidget(
      _app(
        dependencies: dependencies,
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UpdateBottom), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(UpdateBottom)).dy,
      lessThan(tester.getTopLeft(find.byType(HeroCarousel)).dy),
    );
    expect(
      find.descendant(
        of: find.byType(UpdateBottom),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
  });

  testWidgets('the featured title stays put across a refresh', (tester) async {
    await tester.pumpWidget(
      _app(
        recent: _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]),
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    List<HomeHero> heroes() =>
        tester.widget<HeroCarousel>(find.byType(HeroCarousel)).heroes;
    final hero = heroes().first;
    expect(hero.continuing, isTrue);
    expect(hero.item.id, 90);
    // Then FlixQuest's spotlight: this week's trending.
    expect(heroes().length, greaterThan(1));

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(heroes().first.item.stableId, hero.item.stableId);
  });

  testWidgets('when nothing loads, a quiet message and Retry', (tester) async {
    final source = _FakeSource(true);
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: source,
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home_load_failed'), findsOneWidget);

    source.fail = false;
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(find.byType(HeroCarousel), findsOneWidget);
  });

  for (final mode in <String>['dark', 'amoled', 'light']) {
    testWidgets('$mode: the accent only on the kicker and progress',
        (tester) async {
      await tester.pumpWidget(
        _app(
          mode: mode,
          recent: _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]),
          child: HomeScreen(
            source: _FakeSource(),
            findTint: null,
            showTitleLogos: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final accent = Theme.of(
        tester.element(find.byType(HomeScreen)),
      ).colorScheme.primary;
      // No text in the accent: the heroes' labels are white beside the
      // accented mark.
      final accentTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.style?.color == accent)
          .map((text) => text.data);
      expect(accentTexts, isEmpty);
      expect(find.text('CONTINUE_WATCHING'), findsOneWidget);
      expect(find.text('FLIXQUEST'), findsOneWidget);
      final accentIcons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((icon) => icon.color == accent);
      expect(accentIcons, isEmpty);
    });
  }

  testWidgets('a small phone, large text, right to left: nothing overflows',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _app(
          recent: _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]),
          bookmarks: _FakeBookmarks()..movies = <Movie>[Movie(id: 60)],
          // Inside the app, whose own locale would otherwise set the
          // direction.
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: HomeScreen(
              source: _FakeSource(),
              findTint: null,
              showTitleLogos: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Scroll the whole page through so every row is laid out.
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('upcoming_movies'), findsOneWidget);
  });

  testWidgets('the hero turns on its own, and holds while touched',
      (tester) async {
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heroes =
        tester.widget<HeroCarousel>(find.byType(HeroCarousel)).heroes;
    expect(heroes.length, greaterThan(1));
    String shown() => tester
        .widget<HeroCard>(
          find.byType(HeroCard).hitTestable().first,
        )
        .hero
        .item
        .stableId;
    expect(shown(), heroes[0].item.stableId);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(shown(), heroes[1].item.stableId);

    // A finger on the card: no turn.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HeroCarousel)),
    );
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(shown(), heroes[1].item.stableId);
    // Let go without tapping, which would open the title.
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('random genre rows close the page', (tester) async {
    final feed = HomeFeed(
      filter: HomeFilter.movies,
      categories: <HomeCategory>[
        for (final layout in CategoryLayout.values)
          HomeCategory(
            kind: MediaKind.movie,
            genre: Genres(genreID: layout.index, genreName: layout.name),
            layout: layout,
          ),
      ],
    );
    final rows = await _rows(tester, filter: HomeFilter.movies, feed: feed);
    expect(
      rows.reversed.take(CategoryLayout.values.length).map(_describe),
      everyElement('category'),
    );

    // Each layout lays out without trouble on a phone.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final section in rows.whereType<CategorySection>()) {
      await tester.pumpWidget(
        _app(
          child: SingleChildScrollView(
            child: CategorySection(
              category: section.category,
              load: () async => _movies([1, 2, 3, 4, 5, 6, 7, 8]),
              onSeeAll: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(section.category.genre.genreName!), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('under All, a genre row says which kind it is', (tester) async {
    final feed = HomeFeed(
      filter: HomeFilter.all,
      categories: <HomeCategory>[
        HomeCategory(
          kind: MediaKind.series,
          genre: Genres(genreID: 18, genreName: 'Drama'),
          layout: CategoryLayout.posters,
        ),
      ],
    );
    final all = await _rows(tester, filter: HomeFilter.all, feed: feed);
    expect(all.whereType<CategorySection>().single.kicker, 'series');
    final series = await _rows(
      tester,
      filter: HomeFilter.series,
      feed: HomeFeed(filter: HomeFilter.series, categories: feed.categories),
    );
    expect(series.whereType<CategorySection>().single.kicker, isNull);
  });

  testWidgets('a flick sideways moves the hero on, and back', (tester) async {
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heroes =
        tester.widget<HeroCarousel>(find.byType(HeroCarousel)).heroes;
    String shown() => tester
        .widget<HeroCard>(find.byType(HeroCard).hitTestable().last)
        .hero
        .item
        .stableId;
    await tester.fling(
      find.byType(HeroCarousel),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(shown(), heroes[1].item.stableId);
    // Mid-crossfade both cards are there, one fading over the other.
    await tester.fling(
      find.byType(HeroCarousel),
      const Offset(300, 0),
      1000,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HeroCard), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(shown(), heroes[0].item.stableId);
  });

  testWidgets('the page takes the hero\'s colour as it turns', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: _PosterSource(),
          findTint: (url) async {
            asked.add(url);
            return const Color(0xFF2D5BD6);
          },
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Looked up outside build, as the hero is first shown, without error.
    expect(asked, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(asked, hasLength(2));
  });

  testWidgets(
      'Continue Watching: ⋮ offers Resume, Details and Remove, '
      'with Undo', (tester) async {
    final recent = _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]);
    await tester.pumpWidget(
      _app(
        recent: recent,
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('more_options'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('more_options'));
    await tester.pumpAndSettle();
    expect(find.text('resume_title'), findsWidgets);
    expect(find.text('details'), findsOneWidget);
    // A movie has no episodes to pick.
    expect(find.text('episodes'), findsNothing);

    await tester.tap(find.text('remove_from_row'));
    await tester.pumpAndSettle();
    expect(recent.movies, isEmpty);
    expect(find.byType(ContinueRow), findsNothing);
    expect(find.text('removed_from_row'), findsOneWidget);

    await tester.tap(find.text('undo'));
    await tester.pumpAndSettle();
    expect(recent.movies.single.id, 90);
    expect(find.byType(ContinueRow), findsOneWidget);
  });

  testWidgets("a series' next episode shows as one, and plays as one",
      (tester) async {
    final next = UpNext(
      seriesId: 7,
      seriesName: 'Severance',
      finishedSeason: 2,
      finishedEpisode: 4,
      season: 2,
      episode: 5,
      backdropPath: '/b.jpg',
      watchedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      _app(
        recent: _FakeRecent(upNext: <UpNext>[next]),
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // It leads the hero, offering the episode itself.
    final hero =
        tester.widget<HeroCarousel>(find.byType(HeroCarousel)).heroes.first;
    expect(hero.item.upNext?.label, 'S2:E5');
    expect(find.text('play_episode'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byTooltip('more_options'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('S2:E5'), findsWidgets);
    expect(find.textContaining('next_episode'), findsOneWidget);
    await tester.tap(find.byTooltip('more_options'));
    await tester.pumpAndSettle();
    expect(find.text('episodes'), findsOneWidget);
  });
}

/// Like [_FakeSource], with posters, so the hero has artwork to take a
/// colour from.
class _PosterSource extends _FakeSource {
  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async =>
      (await super.list(kind, list))
          .map(
            (item) => MediaItem(
              kind: item.kind,
              id: item.id,
              title: item.title,
              overview: '',
              posterPath: '/p${item.id}.jpg',
              backdropPath: null,
              rating: null,
              releaseDate: null,
            ),
          )
          .toList();
}
