import 'package:better_player_plus/better_player_plus.dart';
import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/design/app_tokens.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/models/occasional_theme.dart';
import 'package:flixquest/screens/common/player/player_feedback_ui.dart';
import 'package:flixquest/screens/common/player/player_sheet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overlay text clears the MaterialApp debug fallback style',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PlayerTheme(
        onVideo: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('NEXT EPISODE'),
            const Text('S4:E9 Mae Rides the Bus',
                style: TextStyle(fontFamily: AppType.semiBold, fontSize: 18)),
            PlayerActionButton(
              label: 'Watch credits',
              icon: Icons.close,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ));
    for (final label in [
      'NEXT EPISODE',
      'S4:E9 Mae Rides the Bus',
      'Watch credits'
    ]) {
      final richText = tester.widget<RichText>(find.descendant(
        of: find.text(label),
        matching: find.byType(RichText),
      ));
      expect(richText.text.style!.decoration ?? TextDecoration.none,
          TextDecoration.none);
      expect(richText.text.style!.fontFamily,
          label == 'NEXT EPISODE' ? AppType.regular : AppType.semiBold);
    }
    expect(tester.takeException(), isNull);
  });

  for (final mode in [
    'dark',
    'light',
    'amoled',
    'custom',
    'seasonal',
    'ambient'
  ]) {
    testWidgets('$mode player sheets retain the app palette and snackbar',
        (tester) async {
      late ThemeData appTheme;
      final appMode = mode == 'light' || mode == 'amoled' ? mode : 'dark';
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        appTheme = Styles.themeData(
          appThemeMode: appMode,
          isM3Enabled: true,
          lightDynamicColor: null,
          darkDynamicColor: null,
          context: context,
          appColor: AppColor(
            cs: AppColor.colorGetter(Colors.purple, appMode != 'light',
                useExactPrimary: true),
            index:
                mode == 'custom' ? AppColor.customIndex : AppColor.defaultIndex,
          ),
          occasionalTheme: mode == 'seasonal'
              ? OccasionalTheme.fromJson({
                  'id': 'custom_launch',
                  'enabled': true,
                  'colors': ['#7B1FA2', '#00897B'],
                  'background': {'dark': '#191221'},
                })
              : null,
          ambientColor: mode == 'ambient' ? Colors.blue : null,
        );
        return const SizedBox();
      })));

      late BuildContext pageContext;
      late ThemeData sheetTheme;
      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: Builder(builder: (context) {
          pageContext = context;
          return const Scaffold();
        }),
      ));
      await tester.pumpAndSettle();
      showPlayerSheet<void>(
        context: pageContext,
        builder: (context) {
          // The builder itself must see the player theme, not only descendants.
          sheetTheme = Theme.of(context);
          return const SizedBox(height: 200);
        },
      );
      await tester.pumpAndSettle();

      for (final theme in [sheetTheme, betterPlayerPanelTheme(appTheme)]) {
        expect(theme.scaffoldBackgroundColor, appTheme.scaffoldBackgroundColor);
        expect(theme.extension<BetterPlayerPanelColors>()!.panel,
            appTheme.scaffoldBackgroundColor);
        expect(theme.colorScheme.primary, appTheme.colorScheme.primary);
        expect(theme.colorScheme.secondary, appTheme.colorScheme.secondary);
        expect(theme.colorScheme.tertiary, appTheme.colorScheme.tertiary);
        expect(theme.snackBarTheme, appTheme.snackBarTheme);
        expect(theme.sliderTheme.thumbColor, appTheme.colorScheme.primary);
        expect(
            theme.progressIndicatorTheme.color, appTheme.colorScheme.primary);
        for (final extension in appTheme.extensions.values) {
          expect(theme.extensions[extension.type], extension);
        }
      }
      expect(
          tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
          appTheme.scaffoldBackgroundColor);

      Navigator.pop(pageContext);
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(pageContext).showSnackBar(
        playerProgressSnackBar(message: 'Downloading and processing subtitles'),
      );
      // The progress animation is indeterminate, so do not pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final labelContext =
          tester.element(find.text('Downloading and processing subtitles'));
      final foreground = DefaultTextStyle.of(labelContext).style.color!;
      final background = appTheme.snackBarTheme.backgroundColor!;
      final luminances = [
        foreground.computeLuminance(),
        background.computeLuminance()
      ]..sort();
      expect(
          (luminances.last + .05) / (luminances.first + .05), greaterThan(4.5));
      expect(
          tester
              .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator))
              .color,
          foreground);
      expect(tester.takeException(), isNull);
    });
  }
}
