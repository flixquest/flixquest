import 'package:flixquest/design/app_tokens.dart';
import 'package:flixquest/screens/common/player/player_feedback_ui.dart';
import 'package:flixquest/screens/common/player/player_sheet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recovery actions remain reachable in a short playback area',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 320,
            height: 180,
            child: PlayerErrorView(
              title: 'Playback failed',
              message:
                  'This stream couldn’t play. Try another provider or retry.',
              actions: [
                PlayerActionButton(
                  label: 'Switch Provider',
                  icon: Icons.storage,
                  primary: true,
                  onPressed: () {},
                ),
                PlayerActionButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => retries++,
                ),
                PlayerActionButton(
                  label: 'Close',
                  icon: Icons.close,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('player actions use Figtree and support remote activation',
      (tester) async {
    var skips = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerActionButton(
          label: 'Skip intro',
          icon: Icons.skip_next,
          autofocus: true,
          onPressed: () => skips++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(button.style!.textStyle!.resolve({})!.fontFamily, AppType.semiBold);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(skips, 1);
  });

  testWidgets('player sheets keep Figtree even above a default navigator theme',
      (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(MaterialApp(
      home: PlayerTheme(
        child: Builder(builder: (context) {
          theme = Theme.of(context);
          return const SizedBox();
        }),
      ),
    ));
    expect(theme.textTheme.bodyMedium!.fontFamily, AppType.regular);
    expect(theme.filledButtonTheme.style!.textStyle!.resolve({})!.fontFamily,
        AppType.semiBold);
    expect(theme.outlinedButtonTheme.style!.textStyle!.resolve({})!.fontFamily,
        AppType.semiBold);
  });
}
