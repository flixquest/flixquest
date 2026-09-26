import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/mobile/app/mobile_nav_bar.dart';
import 'package:flixquest/mobile/app/mobile_shell.dart';
import 'package:flixquest/mobile/app/mobile_tabs.dart';
import 'package:flixquest/models/default_home.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/services/app_session_state_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tab that scrolls on its tab's controller, counts its resets and
/// remembers how many times it was built from scratch.
class _FakeTab extends StatefulWidget {
  const _FakeTab(this.tab, this.inits);

  final MobileTab tab;
  final Map<MobileTab, int> inits;

  @override
  State<_FakeTab> createState() => _FakeTabState();
}

class _FakeTabState extends State<_FakeTab> {
  int resets = 0;
  MobileTabController? _tabs;

  void _reset() => setState(() => resets++);

  @override
  void initState() {
    super.initState();
    widget.inits.update(widget.tab, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabs ??= MobileTabScope.of(context)..addResetListener(widget.tab, _reset);
  }

  @override
  void dispose() {
    _tabs?.removeResetListener(widget.tab, _reset);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: MobileTabScope.of(context).scrollController(widget.tab),
      itemCount: 100,
      itemBuilder: (_, index) => SizedBox(
        height: 80,
        child: Text('${widget.tab.id} $index resets $resets'),
      ),
    );
  }
}

Future<({SharedPreferences prefs, Map<MobileTab, int> inits})> _pumpShell(
  WidgetTester tester, {
  Map<String, Object> stored = const <String, Object>{},
  DefaultHome defaultHome = DefaultHome.home,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  sharedPrefsSingleton = prefs;
  final settings = SettingsProvider()..defaultHome = defaultHome;
  final inits = <MobileTab, int>{};
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        home: MobileShell(
          preferences: prefs,
          tabBuilders: <MobileTab, WidgetBuilder>{
            for (final tab in MobileTab.values)
              tab: (_) => _FakeTab(tab, inits),
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (prefs: prefs, inits: inits);
}

Finder _navItem(MobileTab tab) => find.descendant(
      of: find.byType(MobileNavBar),
      matching: find.text(switch (tab) {
        MobileTab.home => 'home',
        MobileTab.newAndHot => 'new_and_hot',
        MobileTab.search => 'search',
        MobileTab.mine => 'my_flixquest',
      }),
    );

MobileTab _current(WidgetTester tester) =>
    tester.widget<MobileNavBar>(find.byType(MobileNavBar)).current;

/// Presses the system Back button, as Android does.
Future<void> _back(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  expect(handled, isTrue);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on Home and builds other tabs only when visited',
      (tester) async {
    final shell = await _pumpShell(tester);
    expect(_current(tester), MobileTab.home);
    expect(shell.inits.keys, <MobileTab>[MobileTab.home]);

    await tester.tap(_navItem(MobileTab.search));
    await tester.pumpAndSettle();
    expect(_current(tester), MobileTab.search);
    expect(find.text('search 0 resets 0'), findsOneWidget);
    expect(find.text('home 0 resets 0'), findsNothing);

    // Back to Home: the same tab, not a new one.
    await tester.tap(_navItem(MobileTab.home));
    await tester.pumpAndSettle();
    expect(shell.inits, <MobileTab, int>{
      MobileTab.home: 1,
      MobileTab.search: 1,
    });
  });

  testWidgets('remembers the tab for the next launch', (tester) async {
    final shell = await _pumpShell(tester);
    await tester.tap(_navItem(MobileTab.mine));
    await tester.pumpAndSettle();
    expect(
      shell.prefs.getString(AppSessionStateStore.handheldDestinationKey),
      'mine',
    );
  });

  testWidgets('restores each tab', (tester) async {
    for (final tab in MobileTab.values) {
      await _pumpShell(
        tester,
        stored: <String, Object>{
          AppSessionStateStore.handheldDestinationKey: tab.id,
        },
      );
      expect(_current(tester), tab);
      // A fresh shell each time.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('an old stored tab opens where its content lives now',
      (tester) async {
    await _pumpShell(
      tester,
      stored: <String, Object>{
        AppSessionStateStore.handheldDestinationKey: 'downloads',
      },
    );
    expect(_current(tester), MobileTab.mine);
  });

  testWidgets('the default-home setting picks the first tab and filter',
      (tester) async {
    await _pumpShell(tester, defaultHome: DefaultHome.search);
    expect(_current(tester), MobileTab.search);
    await tester.pumpWidget(const SizedBox());

    await _pumpShell(tester, defaultHome: DefaultHome.homeSeries);
    expect(_current(tester), MobileTab.home);
    final context = tester.element(find.text('home 0 resets 0'));
    expect(
      MobileTabScope.of(context).initialHomeFilter,
      HomeFilter.series,
    );
  });

  testWidgets('Back from any other tab goes Home, and from Home leaves',
      (tester) async {
    for (final tab in <MobileTab>[
      MobileTab.newAndHot,
      MobileTab.search,
      MobileTab.mine,
    ]) {
      await _pumpShell(tester);
      await tester.tap(_navItem(tab));
      await tester.pumpAndSettle();
      expect(_current(tester), tab);

      await _back(tester);
      expect(_current(tester), MobileTab.home, reason: 'Back from $tab');
      await tester.pumpWidget(const SizedBox());
    }

    await _pumpShell(tester);
    final popped = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        popped.add(call);
        return null;
      },
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      popped.map((call) => call.method),
      contains('SystemNavigator.pop'),
    );
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('pressing the current tab scrolls it up, then resets it',
      (tester) async {
    await _pumpShell(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('home 0 resets 0'), findsNothing);

    await tester.tap(_navItem(MobileTab.home));
    await tester.pumpAndSettle();
    expect(find.text('home 0 resets 0'), findsOneWidget);

    await tester.tap(_navItem(MobileTab.home));
    await tester.pumpAndSettle();
    expect(find.text('home 0 resets 1'), findsOneWidget);
  });

  testWidgets('the selected tab is ink, with no accent', (tester) async {
    await _pumpShell(tester);
    final theme = Theme.of(tester.element(find.byType(MobileNavBar)));
    final label = tester.widget<Text>(_navItem(MobileTab.home));
    expect(label.style?.color, isNot(theme.colorScheme.primary));
    final icons = tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(MobileNavBar),
        matching: find.byType(Icon),
      ),
    );
    for (final icon in icons) {
      expect(icon.color, isNot(theme.colorScheme.primary));
    }
  });
}
