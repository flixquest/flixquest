import 'package:flixquest/mobile/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  testWidgets('right to left, Play still points forward; other icons mirror',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: <Widget>[
              PillButton(
                label: 'Play',
                icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                onPressed: () {},
              ),
              PillButton(
                label: 'My List',
                icon: PhosphorIcons.plus(),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    TextDirection directionOf(IconData icon) => Directionality.of(
          tester.element(find.byIcon(icon)),
        );
    expect(directionOf(PhosphorIcons.play(PhosphorIconsStyle.fill)),
        TextDirection.ltr);
    expect(directionOf(PhosphorIcons.plus()), TextDirection.rtl);
  });
}
