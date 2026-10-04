import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flixquest/widgets/ad_impression_tracker.dart';

void main() {
  testWidgets(
      'requires continuous half visibility for a second and reports once per mount',
      (tester) async {
    final controller = VisibilityDetectorController.instance;
    final oldInterval = controller.updateInterval;
    controller.updateInterval = Duration.zero;
    addTearDown(() => controller.updateInterval = oldInterval);
    final scroll = ScrollController();
    var impressions = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 200,
                child: ListView(controller: scroll, children: [
                  const SizedBox(height: 250),
                  AdImpressionTracker(
                      onImpression: () {
                        impressions++;
                      },
                      child: const SizedBox(
                          height: 100, child: ColoredBox(color: Colors.red))),
                  const SizedBox(height: 1000)
                ])))));
    await tester.pump(const Duration(seconds: 2));
    expect(impressions, 0);
    scroll.jumpTo(99);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(impressions, 0);
    scroll.jumpTo(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(impressions, 0);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(impressions, 0);
    scroll.jumpTo(100);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(impressions, 1);
    scroll.jumpTo(0);
    await tester.pump();
    scroll.jumpTo(100);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(impressions, 1);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
  testWidgets('backgrounding and a covering route interrupt impression dwell',
      (tester) async {
    final detector = VisibilityDetectorController.instance;
    final interval = detector.updateInterval;
    detector.updateInterval = Duration.zero;
    addTearDown(() => detector.updateInterval = interval);
    final navigator = GlobalKey<NavigatorState>();
    var impressions = 0;
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
            body: AdImpressionTracker(
                onImpression: () {
                  impressions++;
                },
                child: const SizedBox.expand(
                    child: ColoredBox(color: Colors.red))))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    expect(impressions, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 700));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering route'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(impressions, 0);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(impressions, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
