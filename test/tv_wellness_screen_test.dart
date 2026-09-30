import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/screens/tv_wellness_screen.dart';
import 'package:flixquest/tv/widgets/tv_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://example.com');
  });
  const metrics = TvShellMetrics(
    compact: true,
    safeInset: 16,
    railWidth: 88,
    railGap: 8,
    contentPadding: 14,
    navItemHeight: 42,
    navItemGap: 2,
    mediaCardWidth: 140,
  );

  testWidgets('D-pad enters Insights, changes range, and reaches details',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now().toUtc();
    final session = WellnessViewingSession(
      id: 'one',
      ownerId: 'guest',
      deviceId: 'test',
      mediaType: WellnessMediaType.movie,
      source: WellnessPlaybackSource.streaming,
      contentId: 'movie-one',
      title: 'Sample film',
      startedAtUtc: now.subtract(const Duration(hours: 1)),
      endedAtUtc: now,
      timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
      watchedMs: const Duration(hours: 1).inMilliseconds,
      durationMs: const Duration(hours: 1).inMilliseconds,
      progressEndMs: const Duration(hours: 1).inMilliseconds,
      completed: true,
      segments: <WellnessPlaybackSegment>[
        WellnessPlaybackSegment(
          startedAtUtc: now.subtract(const Duration(hours: 1)),
          endedAtUtc: now,
        ),
      ],
      genres: const <String>['Drama'],
      updatedAtUtc: now,
    );
    final focusController = TvScreenFocusController();
    final railKey = GlobalKey<TvNavigationRailState>();
    var range = WellnessRange.week;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppDependencyProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Row(
                children: <Widget>[
                  SizedBox(
                    width: metrics.railWidth,
                    child: TvNavigationRail(
                      key: railKey,
                      destinations: const <TvNavigationDestination>[
                        TvNavigationDestination(
                          id: 'wellness',
                          label: 'Insights',
                          icon: Icons.bar_chart,
                        ),
                      ],
                      selectedId: 'wellness',
                      autofocusId: 'wellness',
                      metrics: metrics,
                      onDestinationSelected: (_) {},
                      onMoveRight: (_) {
                        focusController.requestFocus();
                        return true;
                      },
                    ),
                  ),
                  Expanded(
                    child: TvWellnessContent(
                      metrics: metrics,
                      insights: WellnessInsights.fromSessions(
                        <WellnessViewingSession>[session],
                        period: WellnessPeriod.forRange(range, DateTime.now()),
                      ),
                      range: range,
                      loading: false,
                      onRangeSelected: (selected) =>
                          setState(() => range = selected),
                      focusController: focusController,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    railKey.currentState!.requestFocus('wellness');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV insights week');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(range, WellnessRange.month);
    expect(find.text('What held your attention'), findsOneWidget);
    expect(find.text('The shape of your taste'), findsOneWidget);
    expect(find.text('When stories fit your day'), findsOneWidget);

    for (var step = 0; step < 12; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final reportScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(TvWellnessContent),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(reportScroll.position.pixels, greaterThan(0));
    expect(find.text('Parts of the day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty insights still offers a remote focus target',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TvScreenFocusController()..requestFocus();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TvWellnessContent(
          metrics: metrics,
          insights: WellnessInsights.fromSessions(
            const <WellnessViewingSession>[],
            period: WellnessPeriod.forRange(WellnessRange.week, DateTime.now()),
          ),
          range: WellnessRange.week,
          loading: false,
          onRangeSelected: (_) {},
          focusController: controller,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV insights week');
    expect(find.text('Your story starts here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
