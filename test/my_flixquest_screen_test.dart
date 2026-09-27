import 'dart:async';

import 'package:flixquest/catalog/up_next.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/mobile/screens/my_flixquest_screen.dart';
import 'package:flixquest/mobile/widgets/page_kit.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/models/recently_watched.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/bookmark_provider.dart';
import 'package:flixquest/provider/offline_download_provider.dart';
import 'package:flixquest/provider/recently_watched_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/provider/wellness_provider.dart';
import 'package:flixquest/services/offline_download_service.dart';
import 'package:flixquest/models/wellness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecent extends ChangeNotifier implements RecentProvider {
  _FakeRecent({this.movies = const <RecentMovie>[]});

  @override
  final List<RecentMovie> movies;
  @override
  final List<RecentEpisode> episodes = <RecentEpisode>[];
  @override
  final List<UpNext> upNext = <UpNext>[];

  @override
  Future<void> fetchMovies() async {}
  @override
  Future<void> fetchEpisodes() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookmarks extends ChangeNotifier implements BookmarkProvider {
  _FakeBookmarks({this.movies = const <Movie>[]});

  @override
  List<Movie> movies;
  @override
  List<TV> tvShows = <TV>[];

  /// Remote bookmark sync is unavailable offline.
  @override
  Future<void> fetchBookmarks() async => throw Exception('offline');

  @override
  bool isMovieBookmarked(int id) => movies.any((movie) => movie.id == id);
  @override
  bool isTVBookmarked(int id) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWellness extends ChangeNotifier implements WellnessProvider {
  @override
  List<WellnessViewingSession> get sessions => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGateway implements OfflineDownloadGateway {
  _FakeGateway(this.items);

  final List<OfflineDownload> items;
  final _events = StreamController<List<OfflineDownload>>.broadcast();

  @override
  Stream<List<OfflineDownload>> get downloadEvents => _events.stream;

  @override
  Future<List<OfflineDownload>> getDownloads() async => items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OfflineDownload _download(
  String id, {
  required int createdAt,
  OfflineDownloadState state = OfflineDownloadState.downloading,
  double progress = 40,
}) =>
    OfflineDownload(
      id: id,
      title: id,
      mediaType: 'movie',
      quality: '720p',
      state: state,
      progress: progress,
      bytesDownloaded: 0,
      contentLength: -1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );

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

ThemeData _theme(BuildContext context) => Styles.themeData(
      appThemeMode: 'dark',
      isM3Enabled: true,
      lightDynamicColor: null,
      darkDynamicColor: null,
      context: context,
      appColor: AppColorsList().appColors(true).first,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<OfflineDownload> downloads = const [],
  List<RecentMovie> recent = const [],
  List<Movie> saved = const [],
}) async {
  dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sharedPrefsSingleton = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ChangeNotifierProvider<RecentProvider>.value(
          value: _FakeRecent(movies: recent),
        ),
        ChangeNotifierProvider<BookmarkProvider>.value(
          value: _FakeBookmarks(movies: saved),
        ),
        ChangeNotifierProvider<WellnessProvider>.value(value: _FakeWellness()),
        ChangeNotifierProvider(
          create: (_) => OfflineDownloadProvider(
            service: _FakeGateway(downloads),
          ),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: _theme(context),
          home: const Scaffold(body: MyFlixQuestScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('works offline as a guest, with local downloads first',
      (tester) async {
    await _pump(
      tester,
      downloads: <OfflineDownload>[
        _download('first', createdAt: 4),
        _download('second', createdAt: 3),
        _download(
          'third',
          createdAt: 2,
          state: OfflineDownloadState.failed,
          progress: 0,
        ),
        _download('fourth', createdAt: 1),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('guest'), findsWidgets);
    expect(find.text('login_signup'), findsOneWidget);
    // Only the three newest downloads, and "See all" for the rest.
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('third'), findsOneWidget);
    expect(find.text('fourth'), findsNothing);
    // A failed item is never shown as busy.
    final bars = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bars.every((bar) => bar.value != null), isTrue);
  });

  testWidgets('sections and account rows appear in the guide order',
      (tester) async {
    await _pump(
      tester,
      downloads: <OfflineDownload>[_download('local', createdAt: 1)],
      recent: <RecentMovie>[_recentMovie(1)],
      saved: <Movie>[Movie(id: 2, title: 'Saved')],
    );

    double top(String text) => tester.getTopLeft(find.text(text).first).dy;
    final order = <String>[
      'continue_watching',
      'my_list',
      'downloads',
      'viewing_insights',
      'settings',
      'sync',
      'check_server',
      'check_for_update',
      'shared_the_app',
      'about',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(
        top(order[i]),
        greaterThan(top(order[i - 1])),
        reason: '${order[i]} should follow ${order[i - 1]}',
      );
    }
  });

  testWidgets('a guest is offered sign-in instead of sign out', (tester) async {
    await _pump(tester);

    final labels = tester
        .widgetList<ListRow>(find.byType(ListRow))
        .map((row) => row.label)
        .toList();
    expect(labels, isNot(contains('sign_out')));
    expect(find.text('profile'), findsNothing);
    expect(find.text('no_downloads_yet'), findsOneWidget);
  });

  testWidgets('no text or icon uses the accent', (tester) async {
    await _pump(
      tester,
      downloads: <OfflineDownload>[_download('local', createdAt: 1)],
      saved: <Movie>[Movie(id: 2, title: 'Saved')],
    );
    final accent = Theme.of(tester.element(find.byType(MyFlixQuestScreen)))
        .colorScheme
        .primary;

    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.color, isNot(accent), reason: text.data);
    }
    for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
      expect(icon.color, isNot(accent));
    }
  });
}
