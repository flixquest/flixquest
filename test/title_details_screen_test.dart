import 'package:flixquest/catalog/details_play.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/catalog/title_details_source.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/mobile/screens/title_details_screen.dart';
import 'package:flixquest/mobile/widgets/page_kit.dart';
import 'package:flixquest/mobile/widgets/filter_chips.dart';
import 'package:flixquest/mobile/widgets/poster_card.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/models/credits.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/models/images.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/videos.dart';
import 'package:flixquest/models/watch_providers.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/bookmark_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 9, 27);

final _movie = MediaItem.fromMovie(Movie(
  id: 1,
  title: 'Heat',
  releaseDate: '1995-12-15',
  overview: 'A group of professional bank robbers start to feel the heat.',
  voteAverage: 8.3,
  backdropPath: '/heat.jpg',
));

final _series = MediaItem.fromSeries(TV(
  id: 9,
  name: 'Dark',
  firstAirDate: '2017-12-01',
  overview: 'A missing child sets four families on a frantic hunt.',
  voteAverage: 8.4,
  backdropPath: '/dark.jpg',
));

MediaItem _related(int id) =>
    MediaItem.fromMovie(Movie(id: id, title: 'Related $id'));

class _Source implements TitleDetailsSource {
  bool failSeries = false;
  final List<int> seasonLoads = <int>[];

  @override
  Future<MovieDetails> movie(int id) async => MovieDetails(
        runtime: 170,
        status: 'Released',
        originalTitle: 'Heat',
        tagline: 'A Los Angeles crime saga',
      );

  @override
  Future<TVDetails> series(int id) async {
    if (failSeries) throw Exception('offline');
    return TVDetails(
      numberOfSeasons: 2,
      numberOfEpisodes: 18,
      status: 'Ended',
      createdBy: <CreatedBy>[CreatedBy(name: 'Baran bo Odar')],
      seasons: <Seasons>[
        Seasons(seasonNumber: 0, name: 'Specials', episodeCount: 3),
        Seasons(seasonNumber: 1, name: 'Season 1', episodeCount: 10),
        Seasons(seasonNumber: 2, name: 'Season 2', episodeCount: 8),
      ],
    );
  }

  @override
  Future<List<Genres>> genres(MediaItem item) async =>
      <Genres>[Genres(genreID: 80, genreName: 'Crime')];

  @override
  Future<Credits> credits(MediaItem item) async => Credits(
        cast: <Cast>[Cast(name: 'Al Pacino', order: 0, character: 'Hanna')],
        crew: <Crew>[Crew(name: 'Michael Mann', job: 'Director')],
      );

  @override
  Future<Videos> videos(MediaItem item) async => Videos(
        result: <Results>[
          Results(
            name: 'Official Trailer',
            videoLink: 'abc',
            type: 'Trailer',
            site: 'YouTube',
          ),
        ],
      );

  @override
  Future<Images> images(MediaItem item) async =>
      Images(backdrop: <Backdrops>[Backdrops(filePath: '/b.jpg')]);

  @override
  Future<ExternalLinks> links(MediaItem item) async =>
      ExternalLinks(imdbId: 'tt0113277');

  @override
  Future<BelongsToCollection?> collection(int movieId) async => null;

  @override
  Future<List<MediaItem>> recommendations(MediaItem item, int page) async =>
      page == 1 ? <MediaItem>[_related(101), _related(102)] : <MediaItem>[];

  @override
  Future<List<MediaItem>> similar(MediaItem item, int page) async =>
      page == 1 ? <MediaItem>[_related(103)] : <MediaItem>[];

  @override
  Future<List<EpisodeList>> season(int seriesId, int seasonNumber) async {
    seasonLoads.add(seasonNumber);
    return <EpisodeList>[
      EpisodeList(
        seasonNumber: seasonNumber,
        episodeNumber: 1,
        episodeId: seasonNumber * 100 + 1,
        name: 'Secrets',
        airDate: '2017-12-01',
        runtime: 51,
        overview: 'A boy goes missing.',
      ),
      EpisodeList(
        seasonNumber: seasonNumber,
        episodeNumber: 2,
        episodeId: seasonNumber * 100 + 2,
        name: 'Lies',
        airDate: '2030-01-03',
      ),
    ];
  }

  @override
  Future<WatchProviders> watchProviders(MediaItem item) async =>
      WatchProviders();
}

RecentEpisode _watching(int season, int episode) => RecentEpisode(
      dateTime: DateTime(2026, 9, 20).toString(),
      elapsed: 900,
      episodeName: 'Secrets',
      episodeNum: episode,
      id: 9000 + season * 100 + episode,
      posterPath: '/p.jpg',
      remaining: 2700,
      seasonNum: season,
      seriesName: 'Dark',
      seriesId: 9,
    );

class _FakeBookmarks extends ChangeNotifier implements BookmarkProvider {
  @override
  final List<Movie> movies = <Movie>[];
  @override
  final List<TV> tvShows = <TV>[];

  @override
  bool isMovieBookmarked(int id) => movies.any((movie) => movie.id == id);

  @override
  bool isTVBookmarked(int id) => tvShows.any((series) => series.id == id);

  @override
  Future<void> addMovie(Movie movie) async {
    movies.add(movie);
    notifyListeners();
  }

  @override
  Future<void> removeMovie(int id) async {
    movies.removeWhere((movie) => movie.id == id);
    notifyListeners();
  }

  @override
  Future<void> addTV(TV series) async {
    tvShows.add(series);
    notifyListeners();
  }

  @override
  Future<void> removeTV(int id) async {
    tvShows.removeWhere((series) => series.id == id);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _setUp() async {
  dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nFLIXQUEST_API_URL=x');
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sharedPrefsSingleton = await SharedPreferences.getInstance();
}

Widget _app(
  MediaItem item, {
  _Source? source,
  WatchHistory history = const WatchHistory(),
  bool canPlay = true,
  bool canDownload = true,
  String mode = 'dark',
  TextDirection direction = TextDirection.ltr,
  BookmarkProvider? bookmarks,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (_) => AppDependencyProvider()
            ..displayWatchNowButton = canPlay
            ..displayDownloadButton = canDownload,
        ),
        ChangeNotifierProvider<BookmarkProvider>(
          create: (_) => bookmarks ?? _FakeBookmarks(),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: Styles.themeData(
            appThemeMode: mode,
            isM3Enabled: true,
            lightDynamicColor: null,
            darkDynamicColor: null,
            context: context,
            appColor: AppColorsList().appColors(mode != 'light').first,
          ),
          home: Directionality(
            textDirection: direction,
            child: TitleDetailsScreen(
              item: item,
              source: source ?? _Source(),
              history: history,
              showTitleLogos: false,
              adBuilder: (_) => const Text('AD_SLOT'),
              now: () => _now,
            ),
          ),
        ),
      ),
    );

Finder get _page => find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );

Future<void> _reach(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(target, 200, scrollable: _page);

/// Brings the tab row into view, then [label] within it, and picks it.
Future<void> _tab(WidgetTester tester, String label) async {
  await _reach(tester, find.byType(FilterChips));
  await tester.scrollUntilVisible(
    find.text(label),
    80,
    scrollable: find.descendant(
      of: find.byType(FilterChips),
      matching: find.byType(Scrollable),
    ),
  );
  // Wholly on screen, not just built: in right to left the row runs the
  // other way.
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Finder _poster(int id) => find.byWidgetPredicate(
    (widget) => widget is PosterCard && widget.item.id == id);

void main() {
  setUp(_setUp);

  testWidgets('a movie: Play first, then what it is, then the tabs',
      (tester) async {
    await tester.pumpWidget(_app(_movie));
    await tester.pumpAndSettle();

    // The page's title; the bar's copy waits, hidden, for the artwork to
    // scroll away.
    expect(find.text('Heat'), findsWidgets);
    expect(
      find.text('1995 · \uFFFC8.3 · 2h 50m', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Crime'), findsOneWidget);
    expect(find.text('play'), findsOneWidget);
    expect(find.text('download_action'), findsOneWidget);
    expect(find.text('starring_line'), findsOneWidget);
    expect(find.text('director_line'), findsOneWidget);
    // Play sits above everything that describes the movie.
    expect(
      tester.getTopLeft(find.text('play')).dy,
      lessThan(tester.getTopLeft(find.text('starring_line')).dy),
    );
    expect(find.text('trailer'), findsOneWidget);
    await _reach(tester, find.text('AD_SLOT'));

    // More Like This: both lists, each title once.
    await _reach(tester, _poster(103));
    expect(_poster(101), findsOneWidget);
    expect(find.byType(PosterCard), findsNWidgets(3));

    await _tab(tester, 'trailers_and_more');
    await _reach(tester, find.text('Official Trailer'));
    expect(find.byType(PosterCard), findsNothing);

    await _tab(tester, 'details');
    await _reach(tester, find.text('A Los Angeles crime saga'));
    expect(find.text('movie_info'), findsOneWidget);
    await _reach(tester, find.text('IMDb'));
  });

  testWidgets('no Play or Download when the remote flags are off',
      (tester) async {
    await tester.pumpWidget(_app(_movie, canPlay: false, canDownload: false));
    await tester.pumpAndSettle();
    expect(find.text('play'), findsNothing);
    expect(find.text('download_action'), findsNothing);
    // The rest of the page is still there.
    expect(find.text('my_list'), findsOneWidget);
  });

  testWidgets('My List toggles movies and series from their detail actions',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final item in <MediaItem>[_movie, _series]) {
      final bookmarks = _FakeBookmarks();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(_app(item, bookmarks: bookmarks));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('my_list'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        item.kind == MediaKind.movie
            ? bookmarks.isMovieBookmarked(item.id)
            : bookmarks.isTVBookmarked(item.id),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a movie part way through resumes, with the time left',
      (tester) async {
    await tester.pumpWidget(
      _app(
        _movie,
        history: WatchHistory(
          movies: <RecentMovie>[
            RecentMovie(
              backdropPath: null,
              dateTime: _now.toString(),
              elapsed: 1800,
              id: 1,
              posterPath: null,
              releaseYear: 1995,
              remaining: 3600,
              title: 'Heat',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('resume_title'), findsOneWidget);
    expect(find.text('time_left'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('a series opens on the season being watched; specials last',
      (tester) async {
    final source = _Source();
    await tester.pumpWidget(
      _app(
        _series,
        source: source,
        history: WatchHistory(episodes: <RecentEpisode>[_watching(2, 1)]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('resume_episode'), findsOneWidget);
    expect(find.text('creators_line'), findsOneWidget);
    await _reach(tester, find.text('Season 2'));
    expect(source.seasonLoads, <int>[2]);

    await _reach(tester, find.text('1. Secrets'));
    // The episode in progress shows how far in it is.
    expect(find.byType(FractionallySizedBox), findsOneWidget);
    // Not out yet: dimmed, with its date, and nothing to download.
    expect(find.text('coming_date'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('2. Lies'), matching: find.byType(Opacity)),
      findsOneWidget,
    );
    expect(find.byTooltip('download_episode'), findsOneWidget);

    await _reach(tester, find.text('Season 2'));
    await tester.ensureVisible(find.text('Season 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Season 2'));
    await tester.pumpAndSettle();
    final names = tester
        .widgetList<ListRow>(find.byType(ListRow))
        .map((row) => row.label)
        .toList();
    expect(names, <String>['Season 1', 'Season 2', 'Specials']);
    await tester.tap(find.text('Specials'));
    await tester.pumpAndSettle();
    expect(source.seasonLoads, <int>[2, 0]);
  });

  testWidgets('a series not started plays its first episode', (tester) async {
    await tester.pumpWidget(_app(_series));
    await tester.pumpAndSettle();
    expect(find.text('play_episode'), findsOneWidget);
    await _reach(tester, find.text('Season 1'));
  });

  testWidgets('a series whose details fail offers Retry', (tester) async {
    final source = _Source()..failSeries = true;
    await tester.pumpWidget(_app(_series, source: source));
    await tester.pumpAndSettle();
    expect(find.text('play_episode'), findsNothing);
    await _reach(tester, find.text('episodes_load_failed'));
    source.failSeries = false;
    await tester.ensureVisible(find.text('retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    await _reach(tester, find.text('1. Secrets'));
    await tester.drag(_page, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('play_episode'), findsOneWidget);
  });

  for (final mode in <String>['dark', 'light']) {
    testWidgets('$mode: the accent only on progress', (tester) async {
      await tester.pumpWidget(
        _app(
          _series,
          mode: mode,
          history: WatchHistory(episodes: <RecentEpisode>[_watching(2, 1)]),
        ),
      );
      await tester.pumpAndSettle();
      final accent = Theme.of(
        tester.element(find.byType(TitleDetailsScreen)),
      ).colorScheme.primary;
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .where((text) => text.style?.color == accent),
        isEmpty,
      );
      expect(
        tester
            .widgetList<Icon>(find.byType(Icon))
            .where((icon) => icon.color == accent),
        isEmpty,
      );
      // It does fill the progress bar under Resume.
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .color,
        accent,
      );
    });
  }

  for (final item in <MediaItem>[_movie, _series]) {
    testWidgets(
        '${item.kind.name}: a small phone, large text, right to left, '
        'every tab', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.3),
          ),
          child: _app(
            item,
            direction: TextDirection.rtl,
            history: WatchHistory(episodes: <RecentEpisode>[_watching(1, 1)]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final tab in <String>[
        'more_like_this',
        'trailers_and_more',
        'details',
      ]) {
        await _tab(tester, tab);
        for (var i = 0; i < 6; i++) {
          await tester.drag(_page, const Offset(0, -500));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.drag(_page, const Offset(0, 5000));
        await tester.pumpAndSettle();
      }
    });
  }
}
