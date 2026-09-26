import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flixquest/models/occasional_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('seasonal accent reaches the accent controls; the rest stay ink',
      (tester) async {
    late ThemeData seasonalTheme;
    final occasionalTheme = OccasionalTheme.fromJson(<String, dynamic>{
      'id': 'custom_launch',
      'enabled': true,
      'colors': <String>['#7B1FA2', '#00897B'],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            seasonalTheme = Styles.themeData(
              appThemeMode: 'dark',
              isM3Enabled: true,
              lightDynamicColor: null,
              darkDynamicColor: null,
              context: context,
              appColor: AppColor(
                cs: AppColor.colorGetter(Colors.deepPurple, true),
                index: 1,
              ),
              occasionalTheme: occasionalTheme,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final accent = occasionalTheme.primaryColor;
    // The accent is kept for selection, progress and small marks.
    expect(seasonalTheme.colorScheme.primary, accent);
    expect(
      seasonalTheme.radioTheme.fillColor?.resolve(<WidgetState>{}),
      accent,
    );
    expect(
      seasonalTheme.checkboxTheme.fillColor
          ?.resolve(<WidgetState>{WidgetState.selected}),
      accent,
    );
    expect(seasonalTheme.progressIndicatorTheme.color, accent);
    expect(seasonalTheme.sliderTheme.activeTrackColor, accent);
    expect(seasonalTheme.sliderTheme.thumbColor, accent);
    expect(seasonalTheme.textSelectionTheme.cursorColor, accent);
    expect(seasonalTheme.badgeTheme.backgroundColor, accent);

    // Icons, buttons and navigation are ink, whatever the season.
    const ink = Color(0xFFF7F7F7);
    expect(seasonalTheme.iconTheme.color, ink);
    expect(
      seasonalTheme.iconButtonTheme.style?.foregroundColor
          ?.resolve(<WidgetState>{}),
      ink,
    );
    expect(seasonalTheme.floatingActionButtonTheme.foregroundColor, ink);
    expect(seasonalTheme.bottomNavigationBarTheme.selectedItemColor, ink);
    expect(seasonalTheme.navigationRailTheme.selectedIconTheme?.color, ink);

    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: seasonalTheme,
        home: Scaffold(
          body: Row(
            children: <Widget>[
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.share),
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.bookmark),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final shareContext = tester.element(find.byIcon(Icons.share));
    expect(Theme.of(shareContext).useMaterial3, seasonalTheme.useMaterial3);
    expect(Theme.of(shareContext).iconTheme.color, ink);
    expect(IconTheme.of(shareContext).color, ink);
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.bookmark))).color,
      isNot(Colors.deepPurple),
    );
  });
}
