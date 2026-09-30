import 'dart:math' as math;

import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/widgets/tv_pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A translucent colour as it lands on [page].
Color _over(Color color, Color page) => Color.alphaBlend(color, page);

/// The app's own theme for [mode], built the way the app builds it on a TV.
ThemeData _appTheme(BuildContext context, String mode) => Styles.themeData(
      appThemeMode: mode,
      isM3Enabled: true,
      lightDynamicColor: null,
      darkDynamicColor: null,
      context: context,
      appColor: AppColorsList().appColors(mode != 'light').first,
    );

Future<Map<String, TvPalette>> _palettes(WidgetTester tester) async {
  late Map<String, TvPalette> palettes;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        palettes = <String, TvPalette>{
          for (final mode in const <String>['dark', 'amoled', 'light'])
            mode: TvPalette.fromTheme(_appTheme(context, mode)),
        };
        return const SizedBox();
      },
    ),
  );
  return palettes;
}

void main() {
  testWidgets('each theme mode gives the TV the phone\'s page colour',
      (tester) async {
    final palettes = await _palettes(tester);
    expect(palettes['dark']!.page, const Color(0xFF111315));
    expect(palettes['amoled']!.page, Colors.black);
    expect(palettes['light']!.page, const Color(0xFFFCFCFD));

    expect(palettes['dark']!.dark, isTrue);
    expect(palettes['amoled']!.dark, isTrue);
    expect(palettes['light']!.dark, isFalse);
    // Dark and AMOLED are distinct pages, not the same one.
    expect(palettes['dark']!.page, isNot(palettes['amoled']!.page));
  });

  testWidgets('text stays readable on every page', (tester) async {
    final palettes = await _palettes(tester);
    for (final MapEntry(key: mode, value: palette) in palettes.entries) {
      expect(
        _contrast(palette.foreground, palette.page),
        greaterThan(12),
        reason: '$mode foreground',
      );
      expect(
        _contrast(palette.secondaryText, palette.page),
        greaterThan(7),
        reason: '$mode secondary text',
      );
      expect(
        _contrast(palette.mutedText, palette.page),
        greaterThan(4.5),
        reason: '$mode muted text',
      );
      expect(
        _contrast(palette.mutedText, palette.raisedSurface),
        greaterThan(4.5),
        reason: '$mode muted text on a raised panel',
      );
      // A focused control's label against its fill.
      final fill = _over(palette.focusFill, palette.page);
      expect(
        _contrast(palette.onFocus, fill),
        greaterThan(12),
        reason: '$mode focused label',
      );
      // Resting fills stay visible on the page, and panels are a step off it.
      expect(_over(palette.idleFill, palette.page), isNot(palette.page));
      expect(palette.surface, isNot(palette.page));
      expect(palette.raisedSurface, isNot(palette.surface));
    }
  });

  testWidgets('focus inverts in Light: a dark pill with a light label',
      (tester) async {
    late ThemeData light;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          light = _appTheme(context, 'light');
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: light,
        home: const Scaffold(
          body: Center(
            child: TvPillButton(
              label: 'Play',
              autofocus: true,
              onActivate: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final palette = TvPalette.fromTheme(light);
    final fill = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .firstWhere((color) => color != null);
    expect(fill, palette.focusFill);
    expect(fill!.computeLuminance(), lessThan(0.1));
    final label = tester.widget<Text>(find.text('Play'));
    expect(label.style?.color, Colors.white);
  });
}

void _noop() {}
