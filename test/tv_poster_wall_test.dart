import 'package:flixquest/tv/widgets/tv_poster_wall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWall(WidgetTester tester, {required bool reduceMotion}) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: const Scaffold(body: TvPosterWall()),
      ),
    );
  }

  testWidgets('tiles the collage into a wall of posters on a TV screen',
      (tester) async {
    await pumpWall(tester, reduceMotion: false);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    // About ten posters across, several rows deep, with overscan for the tilt.
    expect(find.byType(Image).evaluate().length, greaterThan(50));
  });

  testWidgets('holds still when animations are disabled', (tester) async {
    await pumpWall(tester, reduceMotion: true);

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
