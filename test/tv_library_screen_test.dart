import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/app/tv_shell_layout.dart';
import 'package:flixquest/tv/controllers/tv_catalog_controller.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/models/tv_media_item.dart';
import 'package:flixquest/tv/screens/tv_library_screen.dart';
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
  mediaCardWidth: 110,
);

// No artwork, so nothing reaches for the network.
TvMediaItem _item(int id, TvMediaKind kind) => TvMediaItem(
      kind: kind,
      id: id,
      title: 'Title $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      rating: 7,
      releaseDate: '2024-01-01',
    );

class _FakeLibrary extends TvCatalogController {
  _FakeLibrary(this.items);

  final List<TvMediaItem> items;

  @override
  Future<List<TvMediaItem>> loadLibrary() async => items;
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _pumpLibrary(
  WidgetTester tester,
  List<TvMediaItem> items, {
  List<TvCollection>? opened,
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final focusController = TvScreenFocusController()..requestFocus();
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
            child: TvShellInsets(
              insets: const EdgeInsets.fromLTRB(80, 16, 16, 16),
              child: TvLibraryScreen(
                metrics: _metrics,
                controller: _FakeLibrary(items),
                focusController: focusController,
                onOpenMedia: (_) {},
                onOpenCollection: (collection) => opened?.add(collection),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  testWidgets('saved titles sit in rows by kind, entered from the shell',
      (tester) async {
    await _pumpLibrary(tester, <TvMediaItem>[
      _item(1, TvMediaKind.movie),
      _item(2, TvMediaKind.series),
      _item(3, TvMediaKind.movie),
    ]);
    expect(find.text('Movies in My List'), findsOneWidget);
    expect(find.text('Series in My List'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
    expect(_focused, 'library-movies:movie:1');

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'library-series:series:2');
  });

  testWidgets('a long list stops its row and offers the rest as a grid',
      (tester) async {
    final opened = <TvCollection>[];
    await _pumpLibrary(
      tester,
      <TvMediaItem>[
        for (var i = 0; i < 40; i++) _item(100 + i, TvMediaKind.movie),
      ],
      opened: opened,
    );
    expect(find.text('Series in My List'), findsNothing);
    expect(find.text('See all'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'library-all:all-Movies');
    await _press(tester, LogicalKeyboardKey.select);

    final collection = opened.single;
    expect(collection.title, 'Movies');
    expect(await collection.loadPage(1), hasLength(24));
    expect(await collection.loadPage(2), hasLength(16));
    expect(await collection.loadPage(3), isEmpty);
  });

  testWidgets('an empty list says so', (tester) async {
    await _pumpLibrary(tester, const <TvMediaItem>[]);
    expect(find.text('Your list is empty'), findsOneWidget);
  });
}
