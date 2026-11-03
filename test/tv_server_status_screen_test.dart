import 'dart:async';

import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/tv/screens/tv_server_status_screen.dart';
import 'package:flixquest/video_providers/scraper_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/tv_localization.dart';

ProviderHealthSnapshot _snapshot({int online = 18, int offline = 2}) =>
    ProviderHealthSnapshot(
      interval: const Duration(minutes: 10),
      total: online + offline,
      online: online,
      offline: offline,
      updatedAt: DateTime.utc(2026, 11, 1, 12),
      providers: <ProviderHealthResult>[
        for (var i = 0; i < online + offline; i++)
          ProviderHealthResult(
            id: 'p$i',
            alias: 'Source $i',
            name: 'secret-$i',
            online: i < online,
            requestTime: Duration(milliseconds: 100 + i),
          ),
      ],
    );

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _pump(
  WidgetTester tester,
  Future<ProviderHealthSnapshot> Function(BuildContext) load,
) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => AppDependencyProvider(),
    child: MaterialApp(home: TvServerStatusScreen(load: load)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  initializeTvTranslations();

  testWidgets('shows how many sources are up, by their public names',
      (tester) async {
    await _pump(tester, (_) async => _snapshot());
    expect(find.text('Some providers are unavailable'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('18 of 20 sources online'), findsOneWidget);
    expect(find.text('Health is checked every 10 minutes.'), findsOneWidget);
    expect(find.text('Source 0'), findsOneWidget);
    expect(find.textContaining('secret-'), findsNothing);
    expect(_focused, 'Check again');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Up and Down scroll the list while Check again keeps focus',
      (tester) async {
    await _pump(tester, (_) async => _snapshot(online: 30, offline: 10));
    final list = find.byType(Scrollable).last;
    double offset() => tester.state<ScrollableState>(list).position.pixels;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(0));
    expect(_focused, 'Check again');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(offset(), 0);
  });

  testWidgets('Check again asks once more, and a failure keeps the last',
      (tester) async {
    var calls = 0;
    var fail = false;
    await _pump(tester, (_) async {
      calls++;
      if (fail) throw Exception('offline');
      return _snapshot(online: 20, offline: 0);
    });
    expect(find.text('Server working'), findsOneWidget);

    fail = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Server working'), findsOneWidget);
    expect(find.text("Couldn't check again. These are the last results."),
        findsOneWidget);
    expect(_focused, 'Check again');
  });

  testWidgets('a first check that fails offers a focused Retry',
      (tester) async {
    var fail = true;
    await _pump(tester, (_) async {
      if (fail) throw Exception('offline');
      return _snapshot();
    });
    expect(find.text('Provider health is unavailable'), findsOneWidget);
    expect(_focused, 'Retry');

    fail = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('18 of 20 sources online'), findsOneWidget);
    expect(_focused, 'Check again');
  });

  testWidgets('says it is checking until the first answer', (tester) async {
    final answer = Completer<ProviderHealthSnapshot>();
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppDependencyProvider(),
      child: MaterialApp(
        home: TvServerStatusScreen(load: (_) => answer.future),
      ),
    ));
    await tester.pump();
    expect(find.text('Checking…'), findsWidgets);

    answer.complete(_snapshot());
    await tester.pumpAndSettle();
    expect(find.text('Checking…'), findsNothing);
  });
}
