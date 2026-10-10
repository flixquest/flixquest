import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/screens/common/player/player_sheet_ui.dart';
import 'package:flixquest/screens/common/player/player_subtitle_timing_sheet.dart';
import 'package:flixquest/translations/codegen_loader.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<BetterPlayerController> openSheet(WidgetTester tester,
      {required Size size,
      double textScale = 1,
      String language = 'en'}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        BetterPlayerController(const BetterPlayerConfiguration());
    addTearDown(() => controller.dispose(forceDispose: true));
    await tester.pumpWidget(EasyLocalization(
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
      child: Builder(
          builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                    body: Builder(
                        builder: (context) => TextButton(
                              child: const Text('Open timing'),
                              onPressed: () => showPlayerSheet<void>(
                                context: context,
                                builder: (context) => PlayerSubtitleTimingSheet(
                                  controller: controller,
                                  onClose: () => Navigator.pop(context),
                                ),
                              ),
                            ))),
              )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open timing'));
    await tester.pumpAndSettle();
    return controller;
  }

  for (final size in [
    const Size(800, 360),
    const Size(640, 320),
    const Size(390, 844)
  ]) {
    testWidgets('timing controls fit on opening at $size', (tester) async {
      final controller = await openSheet(tester, size: size);
      final scrollable = tester.state<ScrollableState>(find.descendant(
        of: find.byType(PlayerSubtitleTimingSheet),
        matching: find.byType(Scrollable),
      ));
      expect(scrollable.position.maxScrollExtent, 0);
      expect(find.byKey(const Key('subtitle_timing_later')).hitTestable(),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('subtitle_timing_later')));
      await tester.pumpAndSettle();
      expect(controller.subtitleOffset, const Duration(milliseconds: 500));
      expect(find.byKey(const Key('subtitle_timing_reset')).hitTestable(),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('subtitle_timing_reset')));
      await tester.pumpAndSettle();
      expect(controller.subtitleOffset, Duration.zero);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large translated text stays reachable on a short screen',
      (tester) async {
    final controller = await openSheet(tester,
        size: const Size(640, 320), textScale: 2, language: 'es');
    expect(tester.takeException(), isNull);
    await tester
        .ensureVisible(find.byKey(const Key('subtitle_timing_earlier')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subtitle_timing_earlier')));
    await tester.pumpAndSettle();
    expect(controller.subtitleOffset, const Duration(milliseconds: -500));
    await tester.ensureVisible(find.byKey(const Key('subtitle_timing_reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subtitle_timing_reset')));
    await tester.pumpAndSettle();
    expect(controller.subtitleOffset, Duration.zero);
    expect(tester.takeException(), isNull);
  });
}
