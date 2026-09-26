import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/app/tv_shell_layout.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/widgets/tv_browse_view.dart';
import 'package:flixquest/tv/widgets/tv_navigation_rail.dart';
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
  mediaCardWidth: 120,
);

// No artwork, so nothing reaches for the network.
TvMediaItem _item(int id) => TvMediaItem(
      kind: TvMediaKind.movie,
      id: id,
      title: 'Title $id',
      overview: 'Overview $id',
      posterPath: null,
      backdropPath: null,
      rating: 7,
      releaseDate: '2024-01-01',
    );

TvBrowseRow _row(String scopeId, int firstId) => TvBrowseRow(
      title: scopeId,
      scopeId: scopeId,
      items: <TvMediaItem>[for (var i = 0; i < 12; i++) _item(firstId + i)],
    );

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<TvScreenFocusController> _pumpBrowse(
  WidgetTester tester, {
  List<TvBrowseRow>? rows,
  TvFocusMemory? memory,
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
            child: TvBrowseView(
              featured: _item(1),
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
    final firstCardLeft = tester.getTopLeft(find.text('Title 100').last).dx;

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(tester.getTopLeft(find.text('second')).dy, firstRowTop);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(tester.getTopLeft(find.text('Title 202').last).dx, firstCardLeft);
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
      const TvBrowseRow(title: 'first', scopeId: 'first', items: []),
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
}
