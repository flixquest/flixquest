import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/app/tv_shell_layout.dart';
import 'package:flixquest/tv/controllers/tv_title_logos.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/widgets/tv_browse_skeleton.dart';
import 'package:flixquest/tv/widgets/tv_browse_view.dart';
import 'package:flixquest/tv/widgets/tv_media_card.dart';
import 'package:flixquest/tv/widgets/tv_navigation_rail.dart';
import 'package:flixquest/tv/widgets/tv_top_ten_rank.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  mediaCardWidth: 120,
);

// No artwork, so nothing reaches for the network.
TvMediaItem _item(int id, {String releaseDate = '2024-01-01'}) => TvMediaItem(
      kind: TvMediaKind.movie,
      id: id,
      title: 'Title $id',
      overview: 'Overview $id',
      posterPath: null,
      backdropPath: null,
      rating: 7,
      releaseDate: releaseDate,
    );

TvMediaRow _row(String scopeId, int firstId) => TvMediaRow(
      title: scopeId,
      scopeId: scopeId,
      items: <TvMediaItem>[for (var i = 0; i < 12; i++) _item(firstId + i)],
    );

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

/// The artwork of the card for [itemId] in the row [scopeId], as painted,
/// focus scale included.
Finder _card(String scopeId, int itemId) => find.descendant(
      of: find.byKey(ValueKey<String>('$scopeId:movie:$itemId')),
      matching: find.byType(TvMediaCard),
    );

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Widget _withLogos(TvTitleLogos? logos, Widget child) =>
    logos == null ? child : TvTitleLogoScope(logos: logos, child: child);

/// The rank drawn ahead of a Top 10 row's poster.
Finder _rank(int rank) => find.byWidgetPredicate(
      (widget) => widget is TvTopTenRank && widget.rank == rank,
    );

Future<TvScreenFocusController> _pumpBrowse(
  WidgetTester tester, {
  List<TvBrowseRow>? rows,
  TvFocusMemory? memory,
  String? Function(TvMediaItem item)? badgeFor,
  TvTitleLogos? logos,
}) async {
  tester.view.physicalSize = const Size(864, 508);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final focusController = TvScreenFocusController();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TvFocusMemoryScope(
            memory: memory ?? TvFocusMemory(),
            child: _withLogos(
              logos,
              TvBrowseView(
                featured: _item(1),
                badgeFor: badgeFor,
                metrics: _metrics,
                onOpenMedia: (_) {},
                focusController: focusController,
                focusMemoryScope: 'test-row',
                rows: rows ??
                    <TvBrowseRow>[
                      _row('first', 100),
                      _row('second', 200),
                      _row('third', 300),
                    ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return focusController;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  testWidgets('entering starts on the billboard and Down enters the rows',
      (tester) async {
    final controller = await _pumpBrowse(tester);
    expect(controller.requestFocus(), isTrue);
    await tester.pumpAndSettle();
    expect(_focused, 'TV browse featured');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'first:movie:100');
  });

  testWidgets('each row returns to the card it was left on', (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'first:movie:102');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'second:movie:200');

    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'first:movie:102');
  });

  testWidgets('Up from the first row and Back both return to the billboard',
      (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV browse featured');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(_focused, 'TV browse featured');
  });

  testWidgets('Left off a row\'s first card does not jump to another row',
      (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();

    // Scroll the first row along so its cards sit left of the second row's.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'second:movie:200');

    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'second:movie:200');
  });

  testWidgets('the focused row holds one position and the card pins left',
      (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowDown);
    final firstRowTop = tester.getTopLeft(find.text('first')).dy;
    final firstCardLeft = tester.getTopLeft(_card('first', 100)).dx;

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(tester.getTopLeft(find.text('second')).dy, firstRowTop);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(tester.getTopLeft(_card('second', 202)).dx, firstCardLeft);
  });

  testWidgets('the spotlight follows the focused card', (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('Overview 1'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Overview 101'), findsOneWidget);
    expect(find.text('Overview 1'), findsNothing);
  });

  testWidgets('removing the focused row hands focus to the next one',
      (tester) async {
    final rows = ValueNotifier<List<TvBrowseRow>>(<TvBrowseRow>[
      _row('first', 100),
      _row('second', 200),
    ]);
    addTearDown(rows.dispose);
    tester.view.physicalSize = const Size(864, 508);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TvScreenFocusController();
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
              child: ValueListenableBuilder<List<TvBrowseRow>>(
                valueListenable: rows,
                builder: (_, value, __) => TvBrowseView(
                  featured: _item(1),
                  metrics: _metrics,
                  onOpenMedia: (_) {},
                  focusController: controller,
                  focusMemoryScope: 'test-row',
                  rows: value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.requestFocus();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'first:movie:100');

    rows.value = <TvBrowseRow>[
      const TvMediaRow(title: 'first', scopeId: 'first', items: []),
      _row('second', 200),
    ];
    await tester.pumpAndSettle();
    expect(_focused, 'second:movie:200');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Left off a row\'s first card reaches the rail, not a hidden card',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final metrics = TvShellMetrics.fromConstraints(
      const BoxConstraints(maxWidth: 960, maxHeight: 540),
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
              child: TvShellLayout(
                destinations: <TvNavigationDestination>[
                  for (final id in <String>['home', 'movies'])
                    TvNavigationDestination(
                      id: id,
                      label: id,
                      icon: Icons.circle_outlined,
                    ),
                ],
                selectedId: 'home',
                metrics: metrics,
                onDestinationSelected: (_) {},
                screenBuilder: (context, id, controller) => TvBrowseView(
                  featured: _item(1),
                  metrics: metrics,
                  onOpenMedia: (_) {},
                  focusController: controller,
                  focusMemoryScope: 'test-row',
                  rows: <TvBrowseRow>[
                    _row('first', 100),
                    _row('second', 200),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_focused, 'TV nav home');

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'TV browse featured');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'first:movie:104');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'TV nav home');

    // Back into the content returns to the row, where it was left.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'second:movie:200');
  });

  testWidgets('cards are artwork only; the spotlight carries their details',
      (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);

    // A card's own facts line would read "2024  •  ★ 7.0".
    expect(find.textContaining('  •  '), findsNothing);
    expect(find.text('2024   Movie   ★ 7.0'), findsOneWidget);
  });

  testWidgets('the focused card grows from its leading edge', (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();
    final resting = tester.getRect(_card('first', 100));

    await _press(tester, LogicalKeyboardKey.arrowDown);
    final focused = tester.getRect(_card('first', 100));

    expect(focused.left, moreOrLessEquals(resting.left, epsilon: 1));
    expect(focused.width, moreOrLessEquals(resting.width * 1.1, epsilon: 1));
    // Its neighbour is not covered by it.
    expect(
        tester.getRect(_card('first', 101)).left, greaterThan(focused.right));
  });

  testWidgets('rows below the focused one are dimmed while browsing',
      (tester) async {
    bool dimmed(String scopeId, int itemId) =>
        tester.widget<TvMediaCard>(_card(scopeId, itemId)).dimmed;

    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();
    // The billboard leaves every row at full strength.
    expect(dimmed('first', 100), isFalse);
    expect(dimmed('second', 200), isFalse);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(dimmed('first', 100), isFalse);
    expect(dimmed('first', 105), isFalse);
    expect(dimmed('second', 200), isTrue);
    expect(dimmed('third', 300), isTrue);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(dimmed('second', 200), isFalse);
    expect(dimmed('third', 300), isTrue);
  });

  group('Top 10 row', () {
    List<TvBrowseRow> topTenRows() => <TvBrowseRow>[
          TvTopTenRow(
            title: 'top',
            scopeId: 'top',
            items: <TvMediaItem>[for (var i = 0; i < 12; i++) _item(100 + i)],
          ),
          _row('second', 200),
        ];

    testWidgets('keeps ten titles and ranks each one', (tester) async {
      await _pumpBrowse(tester, rows: topTenRows());

      expect(find.byType(TvTopTenRank), findsNWidgets(10));
      expect(_rank(1), findsOneWidget);
      expect(_rank(10), findsOneWidget);
      expect(_rank(11), findsNothing);
      expect(find.bySemanticsLabel('Number 1, Title 100'), findsOneWidget);
    });

    testWidgets('pins the focused title\'s rank to the leading edge',
        (tester) async {
      final controller = await _pumpBrowse(tester, rows: topTenRows());
      controller.requestFocus();
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'top:movie:100');
      final leadingEdge = tester.getTopLeft(_rank(1)).dx;

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'top:movie:102');
      expect(tester.getTopLeft(_rank(3)).dx, moreOrLessEquals(leadingEdge));
      // The poster follows its rank rather than covering it.
      expect(
        tester.getTopLeft(_card('top', 102)).dx,
        greaterThan(tester.getTopLeft(_rank(3)).dx),
      );
    });

    testWidgets('ranked cards carry no badge of their own', (tester) async {
      await _pumpBrowse(
        tester,
        rows: topTenRows(),
        badgeFor: (_) => TvMediaBadge.top10,
      );
      expect(tester.widget<TvMediaCard>(_card('top', 100)).badge, isNull);
      expect(
        tester.widget<TvMediaCard>(_card('second', 200)).badge,
        TvMediaBadge.top10,
      );
    });
  });

  group('badges', () {
    test('a title counts as new for 30 days after release', () {
      final now = DateTime(2026, 9, 26);
      String? badge(String date) =>
          TvMediaBadge.recencyOf(_item(1, releaseDate: date), now: now);

      expect(badge('2026-09-20'), TvMediaBadge.recent);
      expect(badge('2026-08-27'), TvMediaBadge.recent);
      expect(badge('2026-08-01'), isNull);
      // Not out yet: Coming soon says so already.
      expect(badge('2026-10-10'), isNull);
      expect(badge(''), isNull);
    });

    testWidgets('the page labels cards, except in rows that opt out',
        (tester) async {
      final recent = DateTime.now().subtract(const Duration(days: 3));
      final fresh = _item(
        150,
        releaseDate: recent.toIso8601String().substring(0, 10),
      );
      await _pumpBrowse(
        tester,
        badgeFor: (item) => item.id == 101 ? TvMediaBadge.top10 : null,
        rows: <TvBrowseRow>[
          TvMediaRow(
            title: 'first',
            scopeId: 'first',
            items: <TvMediaItem>[_item(100), _item(101), fresh],
          ),
          TvMediaRow(
            title: 'quiet',
            scopeId: 'quiet',
            items: <TvMediaItem>[_item(101), fresh],
            showBadges: false,
          ),
        ],
      );
      String? badge(String scopeId, int id) =>
          tester.widget<TvMediaCard>(_card(scopeId, id)).badge;

      expect(badge('first', 100), isNull);
      expect(badge('first', 101), TvMediaBadge.top10);
      expect(badge('first', 150), TvMediaBadge.recent);
      expect(badge('quiet', 101), isNull);
      expect(badge('quiet', 150), isNull);
      expect(find.text(TvMediaBadge.top10), findsOneWidget);
    });
  });

  testWidgets(
      'logos are looked up for the billboard, the first row\'s opening '
      'cards, and the cards ahead of focus once it settles', (tester) async {
    final requested = <int>[];
    final logos = TvTitleLogos(
      language: 'en',
      proxyEnabled: false,
      proxyUrl: '',
      client: MockClient((request) async {
        requested.add(int.parse(request.url.pathSegments[2]));
        return http.Response('{"logos": []}', 200);
      }),
    );
    final controller = await _pumpBrowse(tester, logos: logos);
    await tester.pump(const Duration(milliseconds: 500));
    expect(requested.toSet(), <int>{1, 100, 101, 102});

    controller.requestFocus();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));

    expect(requested.toSet(), <int>{1, 100, 101, 102, 103, 104, 105});
    // Each title is looked up once however often it is focused.
    expect(requested, hasLength(requested.toSet().length));
    // Without a logo, the spotlight keeps the name (as does the card, which
    // has no poster here).
    expect(find.text('Title 102'), findsNWidgets(2));
  });

  testWidgets('the skeleton holds the page\'s shape while it loads',
      (tester) async {
    tester.view.physicalSize = const Size(864, 508);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvShellInsets(
            insets: EdgeInsets.fromLTRB(80, 16, 16, 16),
            child: TvBrowseSkeleton(metrics: _metrics),
          ),
        ),
      ),
    );
    // It pulses for as long as it shows, so it never settles.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    // Nothing sits under the rail.
    for (final block in tester.widgetList<Container>(find.byType(Container))) {
      expect(
        tester.getTopLeft(find.byWidget(block)).dx,
        greaterThanOrEqualTo(80),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Left off a row\'s first card reaches the rail, not a hidden card',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final metrics = TvShellMetrics.fromConstraints(
      const BoxConstraints(maxWidth: 960, maxHeight: 540),
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
              child: TvShellLayout(
                destinations: <TvNavigationDestination>[
                  for (final id in <String>['home', 'movies'])
                    TvNavigationDestination(
                      id: id,
                      label: id,
                      icon: Icons.circle_outlined,
                    ),
                ],
                selectedId: 'home',
                metrics: metrics,
                onDestinationSelected: (_) {},
                screenBuilder: (context, id, controller) => TvBrowseView(
                  featured: _item(1),
                  metrics: metrics,
                  onOpenMedia: (_) {},
                  focusController: controller,
                  focusMemoryScope: 'test-row',
                  rows: <TvBrowseRow>[
                    _row('first', 100),
                    _row('second', 200),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_focused, 'TV nav home');

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'TV browse featured');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
    }
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'first:movie:104');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'TV nav home');

    // Back into the content returns to the row, where it was left.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'second:movie:200');
  });

  testWidgets('cards are artwork only; the spotlight carries their details',
      (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);

    // A card's own facts line would read "2024  •  ★ 7.0".
    expect(find.textContaining('  •  '), findsNothing);
    expect(find.text('2024   Movie   ★ 7.0'), findsOneWidget);
  });

  testWidgets('the focused card grows from its leading edge', (tester) async {
    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();
    final resting = tester.getRect(_card('first', 100));

    await _press(tester, LogicalKeyboardKey.arrowDown);
    final focused = tester.getRect(_card('first', 100));

    expect(focused.left, moreOrLessEquals(resting.left, epsilon: 1));
    expect(focused.width, moreOrLessEquals(resting.width * 1.1, epsilon: 1));
    // Its neighbour is not covered by it.
    expect(
        tester.getRect(_card('first', 101)).left, greaterThan(focused.right));
  });

  testWidgets('rows below the focused one are dimmed while browsing',
      (tester) async {
    bool dimmed(String scopeId, int itemId) =>
        tester.widget<TvMediaCard>(_card(scopeId, itemId)).dimmed;

    final controller = await _pumpBrowse(tester);
    controller.requestFocus();
    await tester.pumpAndSettle();
    // The billboard leaves every row at full strength.
    expect(dimmed('first', 100), isFalse);
    expect(dimmed('second', 200), isFalse);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(dimmed('first', 100), isFalse);
    expect(dimmed('first', 105), isFalse);
    expect(dimmed('second', 200), isTrue);
    expect(dimmed('third', 300), isTrue);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(dimmed('second', 200), isFalse);
    expect(dimmed('third', 300), isTrue);
  });

  group('Top 10 row', () {
    List<TvBrowseRow> topTenRows() => <TvBrowseRow>[
          TvTopTenRow(
            title: 'top',
            scopeId: 'top',
            items: <TvMediaItem>[for (var i = 0; i < 12; i++) _item(100 + i)],
          ),
          _row('second', 200),
        ];

    testWidgets('keeps ten titles and ranks each one', (tester) async {
      await _pumpBrowse(tester, rows: topTenRows());

      expect(find.byType(TvTopTenRank), findsNWidgets(10));
      expect(_rank(1), findsOneWidget);
      expect(_rank(10), findsOneWidget);
      expect(_rank(11), findsNothing);
      expect(find.bySemanticsLabel('Number 1, Title 100'), findsOneWidget);
    });

    testWidgets('pins the focused title\'s rank to the leading edge',
        (tester) async {
      final controller = await _pumpBrowse(tester, rows: topTenRows());
      controller.requestFocus();
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'top:movie:100');
      final leadingEdge = tester.getTopLeft(_rank(1)).dx;

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'top:movie:102');
      expect(tester.getTopLeft(_rank(3)).dx, moreOrLessEquals(leadingEdge));
      // The poster follows its rank rather than covering it.
      expect(
        tester.getTopLeft(_card('top', 102)).dx,
        greaterThan(tester.getTopLeft(_rank(3)).dx),
      );
    });

    testWidgets('ranked cards carry no badge of their own', (tester) async {
      await _pumpBrowse(
        tester,
        rows: topTenRows(),
        badgeFor: (_) => TvMediaBadge.top10,
      );
      expect(tester.widget<TvMediaCard>(_card('top', 100)).badge, isNull);
      expect(
        tester.widget<TvMediaCard>(_card('second', 200)).badge,
        TvMediaBadge.top10,
      );
    });
  });

  group('badges', () {
    test('a title counts as new for 30 days after release', () {
      final now = DateTime(2026, 9, 26);
      String? badge(String date) =>
          TvMediaBadge.recencyOf(_item(1, releaseDate: date), now: now);

      expect(badge('2026-09-20'), TvMediaBadge.recent);
      expect(badge('2026-08-27'), TvMediaBadge.recent);
      expect(badge('2026-08-01'), isNull);
      // Not out yet: Coming soon says so already.
      expect(badge('2026-10-10'), isNull);
      expect(badge(''), isNull);
    });

    testWidgets('the page labels cards, except in rows that opt out',
        (tester) async {
      final recent = DateTime.now().subtract(const Duration(days: 3));
      final fresh = _item(
        150,
        releaseDate: recent.toIso8601String().substring(0, 10),
      );
      await _pumpBrowse(
        tester,
        badgeFor: (item) => item.id == 101 ? TvMediaBadge.top10 : null,
        rows: <TvBrowseRow>[
          TvMediaRow(
            title: 'first',
            scopeId: 'first',
            items: <TvMediaItem>[_item(100), _item(101), fresh],
          ),
          TvMediaRow(
            title: 'quiet',
            scopeId: 'quiet',
            items: <TvMediaItem>[_item(101), fresh],
            showBadges: false,
          ),
        ],
      );
      String? badge(String scopeId, int id) =>
          tester.widget<TvMediaCard>(_card(scopeId, id)).badge;

      expect(badge('first', 100), isNull);
      expect(badge('first', 101), TvMediaBadge.top10);
      expect(badge('first', 150), TvMediaBadge.recent);
      expect(badge('quiet', 101), isNull);
      expect(badge('quiet', 150), isNull);
      expect(find.text(TvMediaBadge.top10), findsOneWidget);
    });
  });

  testWidgets(
      'logos are looked up for the billboard, the first row\'s opening '
      'cards, and the cards ahead of focus once it settles', (tester) async {
    final requested = <int>[];
    final logos = TvTitleLogos(
      language: 'en',
      proxyEnabled: false,
      proxyUrl: '',
      client: MockClient((request) async {
        requested.add(int.parse(request.url.pathSegments[2]));
        return http.Response('{"logos": []}', 200);
      }),
    );
    final controller = await _pumpBrowse(tester, logos: logos);
    await tester.pump(const Duration(milliseconds: 500));
    expect(requested.toSet(), <int>{1, 100, 101, 102});

    controller.requestFocus();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));

    expect(requested.toSet(), <int>{1, 100, 101, 102, 103, 104, 105});
    // Each title is looked up once however often it is focused.
    expect(requested, hasLength(requested.toSet().length));
    // Without a logo, the spotlight keeps the name (as does the card, which
    // has no poster here).
    expect(find.text('Title 102'), findsNWidgets(2));
  });

  testWidgets('the skeleton holds the page\'s shape while it loads',
      (tester) async {
    tester.view.physicalSize = const Size(864, 508);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvShellInsets(
            insets: EdgeInsets.fromLTRB(80, 16, 16, 16),
            child: TvBrowseSkeleton(metrics: _metrics),
          ),
        ),
      ),
    );
    // It pulses for as long as it shows, so it never settles.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    // Its rows start where the browse view's first row does.
    final firstCard = tester.getRect(find.byType(Container).last).topLeft;
    expect(firstCard.dx, greaterThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
  });
}
