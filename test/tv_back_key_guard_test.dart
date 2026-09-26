import 'package:flixquest/tv/focus/tv_keymap.dart';
import 'package:flixquest/tv/navigation/tv_back_key_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The only simulated platform whose key map covers the remote's Back button.
const _platform = 'web';

/// On Android TV one press of the remote's Back button reaches Flutter twice:
/// as a goBack key event, which TV screens act on, and as a system Back (a
/// route pop), which the shell's PopScope acts on. Which arrives first
/// depends on the device. Either way the press must be handled once.
void main() {
  late int keyBacks;
  late int systemBacks;

  Future<void> pumpApp(WidgetTester tester, {bool appHandlesKey = true}) async {
    keyBacks = 0;
    systemBacks = 0;
    await tester.pumpWidget(
      TvBackKeyGuard(
        child: MaterialApp(
          home: PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) systemBacks++;
            },
            child: Scaffold(
              body: TvKeymap(
                onBack: appHandlesKey ? () => keyBacks++ : null,
                child: const Focus(autofocus: true, child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<bool> keyDown(WidgetTester tester, [LogicalKeyboardKey? key]) {
    final logical = key ?? LogicalKeyboardKey.goBack;
    return tester.sendKeyDownEvent(
      logical,
      physicalKey: _physicalKeys[logical],
      platform: _platform,
    );
  }

  Future<bool> keyUp(WidgetTester tester, [LogicalKeyboardKey? key]) {
    final logical = key ?? LogicalKeyboardKey.goBack;
    return tester.sendKeyUpEvent(
      logical,
      physicalKey: _physicalKeys[logical],
      platform: _platform,
    );
  }

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  for (final key in _physicalKeys.keys) {
    testWidgets(
        'the key-up of a ${key.keyLabel} press the app handled is '
        'kept from the platform', (tester) async {
      await pumpApp(tester);

      expect(await keyDown(tester, key), isTrue);
      expect(await keyUp(tester, key), isTrue);
      await settle(tester);

      expect(keyBacks, 1);
    });
  }

  testWidgets('a system Back after a handled Back key is dropped',
      (tester) async {
    await pumpApp(tester);

    await keyDown(tester);
    await systemBack(tester);
    await keyUp(tester);
    await settle(tester);

    expect(keyBacks, 1);
    expect(systemBacks, 0);
  });

  testWidgets('a system Back that beats its handled Back key is dropped',
      (tester) async {
    await pumpApp(tester);

    await systemBack(tester);
    await keyDown(tester);
    await keyUp(tester);
    await settle(tester);

    expect(keyBacks, 1);
    expect(systemBacks, 0);
  });

  testWidgets('a system Back with no key behind it still goes back',
      (tester) async {
    await pumpApp(tester);

    await systemBack(tester);
    await settle(tester);

    expect(systemBacks, 1);
  });

  testWidgets('a Back key the app ignores is left to the system Back',
      (tester) async {
    await pumpApp(tester, appHandlesKey: false);

    expect(await keyDown(tester), isFalse);
    await systemBack(tester);
    expect(await keyUp(tester), isFalse);
    await settle(tester);

    expect(systemBacks, 1);
  });

  testWidgets(
      'a system Back that beats a Back key the app ignores still '
      'goes back once', (tester) async {
    await pumpApp(tester, appHandlesKey: false);

    await systemBack(tester);
    await keyDown(tester);
    await keyUp(tester);
    await settle(tester);

    expect(systemBacks, 1);
  });
}

// An Android TV remote's Back button arrives as goBack; keyboards send Escape.
final _physicalKeys = <LogicalKeyboardKey, PhysicalKeyboardKey>{
  LogicalKeyboardKey.goBack: PhysicalKeyboardKey.browserBack,
  LogicalKeyboardKey.escape: PhysicalKeyboardKey.escape,
};
