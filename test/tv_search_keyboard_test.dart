import 'package:flixquest/tv/widgets/tv_search_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<GlobalKey<TvSearchKeyboardState>> _pumpKeyboard(
  WidgetTester tester, {
  bool Function()? onExitUp,
}) async {
  final keyboard = GlobalKey<TvSearchKeyboardState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: TvSearchKeyboard(
            key: keyboard,
            onType: (_) {},
            onDelete: () {},
            onClear: () {},
            onExitUp: onExitUp,
          ),
        ),
      ),
    ),
  );
  keyboard.currentState!.requestFocus();
  await tester.pumpAndSettle();
  return keyboard;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Up off the top row stays put without onExitUp', (tester) async {
    await _pumpKeyboard(tester);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV keyboard space');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV keyboard space');
  });

  testWidgets('Up off the top row is handed to onExitUp', (tester) async {
    var exits = 0;
    await _pumpKeyboard(tester, onExitUp: () {
      exits++;
      return true;
    });
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'TV keyboard space');
    expect(exits, 0);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(exits, 1);
  });

  test('widthFor fits the keyboard into a height', () {
    const height = 240.0;
    final width = TvSearchKeyboard.widthFor(height);
    expect(TvSearchKeyboard.heightFor(width), closeTo(height, 0.001));
  });
}
