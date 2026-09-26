import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/app/tv_shell_layout.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/focus/tv_focusable.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/widgets/tv_content_grid.dart';
import 'package:flixquest/tv/widgets/tv_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _destinationIds = <String>[
  'home',
  'search',
  'movies',
  'series',
  'live',
  'library',
  'wellness',
  'profile',
  'settings',
];

final _destinations = <TvNavigationDestination>[
  for (final id in _destinationIds)
    TvNavigationDestination(id: id, label: id, icon: Icons.circle_outlined),
];

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

/// Lays the shell out the way a 1080p Android TV does (960x540 logical).
Future<GlobalKey<TvShellLayoutState>> _pumpLayout(
  WidgetTester tester, {
  String selectedId = 'movies',
  ValueChanged<String>? onDestinationSelected,
  Widget Function(String id, TvScreenFocusController controller)? screen,
  TvFocusMemory? memory,
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final metrics = TvShellMetrics.fromConstraints(
    const BoxConstraints(maxWidth: 960, maxHeight: 540),
  );
  final layoutKey = GlobalKey<TvShellLayoutState>();
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppDependencyProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(metrics.safeInset),
            child: TvFocusMemoryScope(
              memory: memory ?? TvFocusMemory(),
              child: StatefulBuilder(
                builder: (context, setState) => TvShellLayout(
                  key: layoutKey,
                  destinations: _destinations,
                  selectedId: selectedId,
                  metrics: metrics,
                  onDestinationSelected: (id) {
                    onDestinationSelected?.call(id);
                    setState(() => selectedId = id);
                  },
                  screenBuilder: (context, id, controller) =>
                      screen?.call(id, controller) ??
                      _StubScreen(id: id, focusController: controller),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return layoutKey;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });

  testWidgets('up on the first rail item stays on the rail', (tester) async {
    final layout = await _pumpLayout(tester);
    layout.currentState!.focusRail('home');
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowUp);

    expect(_focused, 'TV nav home');
  });

  testWidgets('down on the last rail item stays on the rail', (tester) async {
    final layout = await _pumpLayout(tester);
    layout.currentState!.focusRail('settings');
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowDown);

    expect(_focused, 'TV nav settings');
  });

  testWidgets('left from the content returns to the selected destination',
      (tester) async {
    final layout = await _pumpLayout(tester, selectedId: 'movies');
    // The entry card sits level with a different rail item ("series").
    layout.currentState!.focusRail();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'movies entry');

    await _press(tester, LogicalKeyboardKey.arrowLeft);

    expect(_focused, 'TV nav movies');
  });

  testWidgets('up from the top of the content stays in the content',
      (tester) async {
    final layout = await _pumpLayout(tester);
    layout.currentState!.focusRail();
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'movies top');

    await _press(tester, LogicalKeyboardKey.arrowUp);

    expect(_focused, 'movies top');
  });

  testWidgets('right enters the screen without waiting for another frame',
      (tester) async {
    final layout = await _pumpLayout(
      tester,
      screen: (id, controller) =>
          _GridScreen(id: id, focusController: controller),
    );
    layout.currentState!.focusRail();
    await tester.pumpAndSettle();

    // No pump: on a TV nothing else is animating, so a focus move parked in a
    // post-frame callback waits until some other key press draws a frame.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    expect(_focused, 'movies-grid:0');
  });

  testWidgets('right from any rail item enters the screen that is showing',
      (tester) async {
    final selections = <String>[];
    final layout = await _pumpLayout(
      tester,
      selectedId: 'movies',
      onDestinationSelected: selections.add,
    );
    layout.currentState!.focusRail('live');
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowRight);

    expect(_focused, 'movies entry');
    expect(selections, isEmpty);
  });

  testWidgets('right enters a screen that has no focus entry point',
      (tester) async {
    final layout = await _pumpLayout(
      tester,
      selectedId: 'wellness',
      screen: (id, _) => _StubScreen(id: id),
    );
    layout.currentState!.focusRail();
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.arrowRight);

    expect(_focused, startsWith('wellness '));
  });

  testWidgets('selecting a destination keeps focus on the rail',
      (tester) async {
    // The series grid was browsed earlier, so it has an item to restore.
    final memory = TvFocusMemory()
      ..remember(scopeId: 'series-grid', itemId: '3');
    final layout = await _pumpLayout(
      tester,
      memory: memory,
      screen: (id, controller) =>
          _GridScreen(id: id, focusController: controller),
    );
    layout.currentState!.focusRail('series');
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.select);

    expect(find.bySemanticsLabel('series card 3'), findsOneWidget);
    expect(_focused, 'TV nav series');

    await _press(tester, LogicalKeyboardKey.arrowRight);

    expect(_focused, 'series-grid:3');
  });

  group('right while the screen is still loading', () {
    late ValueNotifier<List<int>> catalog;

    Future<GlobalKey<TvShellLayoutState>> pumpLoadingCatalog(
      WidgetTester tester,
    ) async {
      catalog = ValueNotifier<List<int>>(const <int>[]);
      addTearDown(catalog.dispose);
      final layout = await _pumpLayout(
        tester,
        screen: (id, controller) => ValueListenableBuilder<List<int>>(
          valueListenable: catalog,
          builder: (_, items, __) => _GridScreen(
            id: id,
            focusController: controller,
            items: items,
          ),
        ),
      );
      layout.currentState!.focusRail();
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'TV nav movies');
      return layout;
    }

    testWidgets('lands in the content once it arrives', (tester) async {
      await pumpLoadingCatalog(tester);

      catalog.value = const <int>[0, 1, 2];
      await tester.pumpAndSettle();

      expect(_focused, 'movies-grid:0');
    });

    testWidgets('is dropped once the user has moved on', (tester) async {
      await pumpLoadingCatalog(tester);
      await _press(tester, LogicalKeyboardKey.arrowDown);

      catalog.value = const <int>[0, 1, 2];
      await tester.pumpAndSettle();

      expect(_focused, 'TV nav series');
    });
  });
  group('a region rebuilt while the other holds focus', () {
    testWidgets('keeps its content reachable by the D-pad', (tester) async {
      final revision = ValueNotifier<int>(0);
      addTearDown(revision.dispose);
      final layout = await _pumpLayout(
        tester,
        screen: (id, controller) => ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (_, value, __) => _RowScreen(
            id: id,
            focusController: controller,
            revision: value,
          ),
        ),
      );
      layout.currentState!.focusRail();
      await tester.pumpAndSettle();

      // Data arriving while the rail holds focus rebuilds the whole screen.
      revision.value++;
      await tester.pumpAndSettle();

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'movies card 0');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'movies card 1');
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focused, 'movies card 0');
    });

    testWidgets('keeps the rail reachable by the D-pad', (tester) async {
      final layout = await _pumpLayout(tester, selectedId: 'movies');
      layout.currentState!.focusRail();
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'movies entry');

      // The shell rebuilds while the content holds focus, as it does when a
      // details page closes.
      tester
          .state<TvShellLayoutState>(find.byType(TvShellLayout))
          .setState(() {});
      tester
          .state<TvNavigationRailState>(find.byType(TvNavigationRail))
          .setState(() {});
      await tester.pumpAndSettle();

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focused, 'TV nav movies');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'TV nav series');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused, 'TV nav search');
    });
  });
}

/// A row of cards moved between by plain directional traversal, the way
/// most TV screens move focus. [revision] only forces a rebuild.
class _RowScreen extends StatefulWidget {
  const _RowScreen({
    required this.id,
    required this.revision,
    this.focusController,
  });

  final String id;
  final int revision;
  final TvScreenFocusController? focusController;

  @override
  State<_RowScreen> createState() => _RowScreenState();
}

class _RowScreenState extends State<_RowScreen> {
  late final List<FocusNode> _cards = <FocusNode>[
    for (var i = 0; i < 3; i++) FocusNode(debugLabel: '${widget.id} card $i'),
  ];

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, () {
      _cards.first.requestFocus();
      return true;
    });
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    for (final node in _cards) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final node in _cards)
          Padding(
            padding: const EdgeInsets.all(12),
            child: _button(node.debugLabel!, node: node, height: 120),
          ),
      ],
    );
  }
}

/// A catalog-shaped screen: a chip across the top, an entry card in the
/// middle, and a footer button, with a focus controller entering the card.
class _StubScreen extends StatefulWidget {
  const _StubScreen({required this.id, this.focusController});

  final String id;
  final TvScreenFocusController? focusController;

  @override
  State<_StubScreen> createState() => _StubScreenState();
}

class _StubScreenState extends State<_StubScreen> {
  late final FocusNode _entry = FocusNode(debugLabel: '${widget.id} entry');

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, () {
      if (_entry.context == null) return false;
      _entry.requestFocus();
      return true;
    });
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _button('${widget.id} top', height: 36),
        const SizedBox(height: 150),
        _button('${widget.id} entry', node: _entry, height: 120),
        const Spacer(),
        _button('${widget.id} bottom', height: 30),
      ],
    );
  }
}

/// A catalog-shaped screen whose focus controller enters a real content grid.
class _GridScreen extends StatefulWidget {
  const _GridScreen({
    required this.id,
    this.focusController,
    this.items = const <int>[0, 1, 2, 3, 4, 5],
  });

  final String id;
  final TvScreenFocusController? focusController;
  final List<int> items;

  @override
  State<_GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends State<_GridScreen> {
  final TvContentGridController _grid = TvContentGridController();

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _grid.requestFocus);
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      // Stands in for the loading spinner, which would never let the test
      // settle.
      return const Center(child: Text('Loading'));
    }
    return TvContentGrid<int>(
      controller: _grid,
      scopeId: '${widget.id}-grid',
      items: widget.items,
      itemId: (item) => '$item',
      semanticLabel: (item) => '${widget.id} card $item',
      targetItemWidth: 200,
      itemBuilder: (_, item, width) => SizedBox(width: width, height: 100),
      onItemActivated: (_) {},
    );
  }
}

Widget _button(String label, {FocusNode? node, double height = 40}) {
  return TvFocusable(
    focusNode: node,
    semanticLabel: label,
    onActivate: () {},
    child: SizedBox(width: 120, height: height),
  );
}
