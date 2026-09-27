import 'package:flixquest/constants/theme_data.dart';
import 'package:flixquest/mobile/widgets/settings_kit.dart';
import 'package:flixquest/models/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    Builder(
      builder: (context) => MaterialApp(
        theme: Styles.themeData(
          appThemeMode: 'dark',
          isM3Enabled: true,
          lightDynamicColor: null,
          darkDynamicColor: null,
          context: context,
          appColor: AppColorsList().appColors(true).first,
        ),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SettingsGroup(title: 'Group', children: <Widget>[child]),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a choice sits against its caret, not mid-row', (tester) async {
    await tester.pumpWidget(
      _app(
        ChoiceRow<String>(
          icon: PhosphorIcons.moon(),
          label: 'Theme mode',
          value: 'dark',
          options: const <String, String>{'dark': 'Dark', 'light': 'Light'},
          onChanged: (_) {},
        ),
      ),
    );

    final valueEnd = tester.getTopRight(find.text('Dark')).dx;
    final caretStart =
        tester.getTopLeft(find.byIcon(PhosphorIcons.caretRight())).dx;
    expect(caretStart - valueEnd, lessThanOrEqualTo(12));
  });

  testWidgets('a choice opens its options and reports the pick',
      (tester) async {
    String? picked;
    await tester.pumpWidget(
      _app(
        ChoiceRow<String>(
          label: 'Theme mode',
          value: 'dark',
          options: const <String, String>{'dark': 'Dark', 'light': 'Light'},
          onChanged: (value) => picked = value,
        ),
      ),
    );

    await tester.tap(find.text('Theme mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(picked, 'light');
  });

  testWidgets('tapping anywhere on a switch row toggles it', (tester) async {
    var value = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _app(
          SwitchRow(
            label: 'Ambient mode',
            subtitle: 'Match the artwork',
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Match the artwork'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(value, isFalse);
  });
}
