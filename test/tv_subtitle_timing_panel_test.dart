import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/screens/common/player/tv_subtitle_timing_panel.dart';
import 'package:flixquest/translations/codegen_loader.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<(BetterPlayerController, List<String>)> pumpPanel(
    WidgetTester tester, {
    String language = 'en',
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        BetterPlayerController(const BetterPlayerConfiguration());
    final closes = <String>[];
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
          Locale('es'),
          Locale('hi'),
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
            theme: theme,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: TvSubtitleTimingPanel(
                controller: controller,
                onClose: () => closes.add('close'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (controller, closes);
  }

  String value(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('tv_subtitle_timing_value')))
      .data!;

  testWidgets('the dial takes focus and Left/Right move the captions',
      (tester) async {
    final (controller, _) = await pumpPanel(tester);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV subtitle timing dial',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.subtitleOffset, const Duration(milliseconds: 200));
    expect(value(tester), '+0.2s');

    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    }
    await tester.pump();
    expect(controller.subtitleOffset, const Duration(milliseconds: -300));
    expect(value(tester), '−0.3s');
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding a direction speeds up and stops at ten seconds',
      (tester) async {
    final (controller, _) = await pumpPanel(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 40; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.subtitleOffset, const Duration(seconds: 10));
    expect(value(tester), '+10.0s');
  });

  testWidgets('Down reaches Reset and Close; Back closes', (tester) async {
    final (controller, closes) = await pumpPanel(tester);
    controller.setSubtitleOffset(const Duration(milliseconds: 1500));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV subtitle timing reset',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(controller.subtitleOffset, Duration.zero);
    expect(value(tester), '0.0s');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV subtitle timing done',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV subtitle timing dial',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closes, ['close']);
  });

  final defaultColor = AppColor(
    cs: const ColorScheme.dark(),
    index: AppColor.defaultIndex,
  );
  final themes = <String, ThemeData>{
    'Dark': darkThemeData(true, null, defaultColor),
    'Light': lightThemeData(true, null, defaultColor),
    'Lights Out': lightsOutThemeData(true, null, defaultColor),
  };
  for (final MapEntry(key: name, value: theme) in themes.entries) {
    testWidgets('follows the $name theme', (tester) async {
      await pumpPanel(tester, theme: theme);
      final colors = BetterPlayerTvPanelColors.fromTheme(theme);
      final page = theme.scaffoldBackgroundColor;

      // The card is a shade off the page, never a fixed dark grey.
      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(tr('subtitle_timing').toUpperCase()),
              matching: find.byType(Container),
            )
            .last,
      );
      final panel = (card.decoration! as BoxDecoration).color!;
      expect(panel, colors.panel);
      expect(
        (panel.computeLuminance() - page.computeLuminance()).abs(),
        lessThan(.1),
      );

      // The focused dial is filled with the page's ink, and its offset is
      // written in the colour that sits on that fill.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('tv_subtitle_timing_value')))
            .style!
            .color,
        colors.onFocus,
      );
      expect(colors.onFocus,
          theme.brightness == Brightness.light ? Colors.white : Colors.black);
      expect(tester.takeException(), isNull);
    });
  }

  for (final language in ['ar', 'es', 'hi']) {
    testWidgets('lays out at TV size in $language', (tester) async {
      await pumpPanel(tester, language: language);
      expect(tester.takeException(), isNull);
    });
  }
}
