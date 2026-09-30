import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/models/wellness_insights.dart';
import 'package:flixquest/screens/wellness/widgets/insights_dashboard.dart';
import 'package:flixquest/screens/wellness/wellness_screen.dart';
import 'package:flixquest/provider/wellness_provider.dart';
import 'package:flixquest/services/wellness_sync_service.dart';
import 'package:provider/provider.dart';
import 'package:flixquest/translations/codegen_loader.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('full report links reach sections beyond the viewport',
      (tester) async {
    final provider = _ReportProvider(_sample().sessions);
    addTearDown(provider.dispose);
    await tester.pumpWidget(_app(
      ChangeNotifierProvider<WellnessProvider>.value(
          value: provider, child: const WellnessScreen()),
      scroll: false,
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Favorite genre'));
    await tester.tap(find.text('Favorite genre'));
    await tester.pumpAndSettle();
    final taste = find.byType(InsightsTasteBreadth);
    expect(tester.getTopLeft(taste).dy, lessThan(400));
    expect(tester.getBottomLeft(taste).dy, greaterThan(0));
    expect(find.byType(InsightsPlaybackPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('complete $locale report fits a narrow phone with larger text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = _ReportProvider(_sample().sessions);
      addTearDown(provider.dispose);
      await tester.pumpWidget(_app(
        ChangeNotifierProvider<WellnessProvider>.value(
            value: provider, child: const WellnessScreen()),
        language: locale,
        scale: 1.3,
        scroll: false,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('rankings reveal all values and can collapse again',
      (tester) async {
    await tester.pumpWidget(_app(InsightsRankedPanel(
      title: 'Ranking',
      values: List.generate(
          8, (i) => WellnessRankedValue('Title $i', 600000 - i * 10000)),
      emptyMessage: 'Empty',
    )));
    await tester.pumpAndSettle();
    expect(find.text('5. Title 4'), findsOneWidget);
    expect(find.text('6. Title 5'), findsNothing);
    await tester.tap(find.text('Show all 8'));
    await tester.pumpAndSettle();
    expect(find.text('8. Title 7'), findsOneWidget);
    await tester.ensureVisible(find.text('Show less'));
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('6. Title 5'), findsNothing);
  });

  testWidgets('snapshot facts open their relevant sections', (tester) async {
    var destination = '';
    await tester.pumpWidget(_app(InsightsSnapshot(
      insights: _sample(),
      onTitles: () => destination = 'titles',
      onTaste: () => destination = 'taste',
      onPatterns: () => destination = 'patterns',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Most watched title'));
    expect(destination, 'titles');
    await tester.tap(find.text('Favorite genre'));
    expect(destination, 'taste');
    await tester.tap(find.text('Peak viewing window'));
    expect(destination, 'patterns');
  });

  testWidgets('measured zero bytes differs from unmeasured playback',
      (tester) async {
    await tester
        .pumpWidget(_app(InsightsPlaybackPanel(insights: _sample(bytes: 0))));
    await tester.pumpAndSettle();
    expect(find.text('0 B · 100%'), findsOneWidget);
    expect(
        find.textContaining('Measured for 100% of playback'), findsOneWidget);
    await tester.pumpWidget(
        _app(InsightsPlaybackPanel(insights: _sample(bytes: null))));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Network usage was not measured'), findsOneWidget);
    expect(find.textContaining('Measured for'), findsNothing);
  });

  for (final mode in ['dark', 'amoled', 'light']) {
    for (final locale in ['en', 'ar']) {
      testWidgets('$mode report fits a narrow $locale phone at 1.3 text scale',
          (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
            _app(_report(), mode: mode, language: locale, scale: 1.3));
        await tester.pumpAndSettle();
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -1800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(InsightsPlaybackPanel), findsOneWidget);
        expect(
            Directionality.of(
                tester.element(find.byType(InsightsPlaybackPanel))),
            locale == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        if (locale == 'ar') {
          expect(find.text('الاثنين'), findsOneWidget);
        }
      });
    }
  }

  testWidgets('snapshot becomes three columns on a tablet', (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_report()));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Most watched title')).dy,
        tester.getTopLeft(find.text('Favorite genre')).dy);
    expect(tester.takeException(), isNull);
  });
}

Widget _report() {
  final insights = _sample();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InsightsSnapshot(
          insights: insights,
          onTitles: () {},
          onTaste: () {},
          onPatterns: () {}),
      const SizedBox(height: 18),
      InsightsDiscoveryPanel(insights: insights),
      const SizedBox(height: 18),
      InsightsTasteBreadth(insights: insights),
      const SizedBox(height: 18),
      InsightsPlaybackPanel(insights: insights),
    ],
  );
}

Widget _app(Widget child,
    {String mode = 'dark',
    String language = 'en',
    double scale = 1,
    bool scroll = true}) {
  return EasyLocalization(
    key: ValueKey('$mode-$language'),
    supportedLocales: const [
      Locale('en'),
      Locale('ar'),
      Locale('es'),
      Locale('hi')
    ],
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    startLocale: Locale(language),
    saveLocale: false,
    child: Builder(builder: (context) {
      final light = mode == 'light';
      return MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              brightness: light ? Brightness.light : Brightness.dark),
          scaffoldBackgroundColor: light
              ? const Color(0xFFFCFCFD)
              : mode == 'amoled'
                  ? Colors.black
                  : const Color(0xFF111315),
        ),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: scroll
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  )
                : child,
          ),
        ),
      );
    }),
  );
}

WellnessInsights _sample({int? bytes = 1073741824}) {
  final start = DateTime.utc(2026, 9, 21, 20);
  final end = start.add(const Duration(hours: 1));
  return WellnessInsights.fromSessions([
    WellnessViewingSession(
      id: 'one',
      ownerId: 'guest',
      deviceId: 'first',
      mediaType: WellnessMediaType.movie,
      source: WellnessPlaybackSource.streaming,
      contentId: 'one',
      title: 'The Grand Budapest Hotel',
      startedAtUtc: start,
      endedAtUtc: end,
      timezoneOffsetMinutes: 0,
      watchedMs: 3600000,
      durationMs: 3600000,
      progressEndMs: 3600000,
      completed: true,
      segments: [WellnessPlaybackSegment(startedAtUtc: start, endedAtUtc: end)],
      genres: const ['Comedy', 'Drama'],
      languages: const ['English'],
      countries: const ['Germany', 'United States'],
      releaseYear: 2014,
      networkBytes: bytes,
      updatedAtUtc: end,
    ),
  ],
      period:
          WellnessPeriod.forRange(WellnessRange.month, DateTime(2026, 9, 30)));
}

class _ReportProvider extends ChangeNotifier implements WellnessProvider {
  _ReportProvider(this.sessions);

  @override
  final List<WellnessViewingSession> sessions;
  @override
  WellnessRange range = WellnessRange.month;
  @override
  bool get loading => false;
  @override
  bool get canSync => false;
  @override
  bool get shouldOfferGuestMerge => false;
  @override
  final WellnessSyncService syncService = _ReportSync();
  @override
  WellnessInsights get insights => WellnessInsights.fromSessions(sessions,
      period: WellnessPeriod.forRange(range, DateTime(2026, 9, 30)));
  @override
  WellnessInsights get previousInsights => WellnessInsights.empty();
  @override
  Future<void> reload() async {}
  @override
  Future<bool> syncNow() async => false;
  @override
  void setRange(WellnessRange value) {
    range = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReportSync implements WellnessSyncService {
  @override
  final status = ValueNotifier(WellnessSyncStatus.idle);
  @override
  final lastSynced = ValueNotifier<DateTime?>(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
