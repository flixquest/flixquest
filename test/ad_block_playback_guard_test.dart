import 'dart:async';
import 'dart:io';

import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/ad_block_detector.dart';
import 'package:flixquest/services/ad_block_check_cache.dart';
import 'package:flixquest/widgets/ad_block_gate.dart';
import 'package:flixquest/widgets/ad_block_playback_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_adsterra_webview.dart';
import 'support/tv_localization.dart';

const message = 'Playback stopped because an ad blocker was detected. '
    'Turn it off for FlixQuest, then try playing again.';

void main() {
  initializeTvTranslations();
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });
  late AppDependencyProvider provider;
  late AdBlockGate gate;
  late Completer<bool> evidence;
  late BuildContext home;
  late BuildContext player;
  var stops = 0;
  var disposals = 0;
  setUp(() {
    provider = AppDependencyProvider()
      ..setBannerAdsConfig(testAdsterraConfig())
      ..adBlockGateEnabled = true;
    stops = 0;
    disposals = 0;
  });

  Future<void> openPlayer(WidgetTester tester,
      {bool television = false, bool rootPlayer = false}) async {
    evidence = Completer<bool>();
    gate = AdBlockGate(
      cache: AdBlockCheckCache(now: tester.binding.clock.now),
      detector:
          AdBlockDetector(lookup: (_) async => [InternetAddress('1.1.1.1')]),
      additionalChecks: [(_, __) => evidence.future],
    );
    if (rootPlayer) {
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
              home: _StreamingPlayer(
                  gate: gate,
                  television: television,
                  onStop: () => stops++,
                  onDispose: () => disposals++,
                  onContext: (context) => player = context))));
      await tester.pumpAndSettle();
      return;
    }
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: Builder(builder: (context) {
        home = context;
        return Scaffold(
            body: TextButton(
                child: const Text('Play'),
                onPressed: () {
                  Navigator.of(context).push<void>(MaterialPageRoute(
                      builder: (_) => _StreamingPlayer(
                          gate: gate,
                          television: television,
                          onStop: () => stops++,
                          onDispose: () => disposals++,
                          onContext: (context) => player = context)));
                }));
      })),
    ));
    // This returns without advancing a clock or completing any network probe.
    expect(await gate.allowPlayback(home), isTrue);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Streaming'), findsOneWidget);
  }

  testWidgets('a late positive stops and exits before showing one message',
      (tester) async {
    await openPlayer(tester);
    expect(stops, 0);
    evidence.complete(true);
    await tester.pump();
    expect(stops, 1);
    await tester.pumpAndSettle();
    expect(disposals, 1);
    expect(find.text('Streaming'), findsNothing);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fullscreen and an open menu cannot hide a player exit',
      (tester) async {
    await openPlayer(tester);
    await tester.tap(find.text('Fullscreen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Player menu'), findsOneWidget);
    evidence.complete(true);
    await tester.pumpAndSettle();
    expect(stops, 1);
    expect(disposals, 1);
    expect(find.text('Player menu'), findsNothing);
    expect(find.text('Fullscreen video'), findsNothing);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabling the gate ignores a late positive', (tester) async {
    await openPlayer(tester);
    provider.adBlockGateEnabled = false;
    evidence.complete(true);
    await tester.pumpAndSettle();
    expect(stops, 0);
    expect(find.text('Streaming'), findsOneWidget);
    expect(find.text(message), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an obsolete network result cannot stop the current stream',
      (tester) async {
    await openPlayer(tester);
    final obsolete = evidence;
    evidence = Completer<bool>();
    gate.invalidate();
    final current = gate.warmUp(player);
    obsolete.complete(true);
    await tester.pump();
    expect(stops, 0);
    evidence.complete(false);
    await current;
    await tester.pumpAndSettle();
    expect(stops, 0);
    expect(find.text('Streaming'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving the player unsubscribes before a late detection',
      (tester) async {
    await openPlayer(tester);
    Navigator.of(player).pop();
    await tester.pumpAndSettle();
    evidence.complete(true);
    await tester.pumpAndSettle();
    expect(stops, 0);
    expect(disposals, 1);
    expect(find.text(message), findsNothing);
  });

  testWidgets('active playback checks again in the background', (tester) async {
    await openPlayer(tester);
    evidence.complete(false);
    await tester.pumpAndSettle();
    evidence = Completer<bool>();
    await tester.pump(
        AdBlockPlaybackGuard.recheckInterval + const Duration(seconds: 1));
    evidence.complete(true);
    await tester.pumpAndSettle();
    expect(stops, 1);
    expect(find.text(message), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TV receives the stopped-playback message too', (tester) async {
    await openPlayer(tester, television: true);
    evidence.complete(true);
    await tester.pumpAndSettle();
    expect(stops, 1);
    expect(find.text(message), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a player used as the initial route is replaced safely',
      (tester) async {
    await openPlayer(tester, rootPlayer: true);
    evidence.complete(true);
    await tester.pumpAndSettle();
    expect(stops, 1);
    expect(disposals, 1);
    expect(find.text('Streaming'), findsNothing);
    expect(find.text(message), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _StreamingPlayer extends StatefulWidget {
  const _StreamingPlayer(
      {required this.gate,
      required this.onStop,
      required this.onDispose,
      required this.onContext,
      required this.television});
  final AdBlockGate gate;
  final VoidCallback onStop;
  final VoidCallback onDispose;
  final ValueChanged<BuildContext> onContext;
  final bool television;
  @override
  State<_StreamingPlayer> createState() => _StreamingPlayerState();
}

class _StreamingPlayerState extends State<_StreamingPlayer> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onContext(context);
    return AdBlockPlaybackGuard(
      gate: widget.gate,
      stopPlayback: widget.onStop,
      television: widget.television,
      child: PopScope(
          canPop: false,
          child: Scaffold(
              body: Column(children: [
            const Text('Streaming'),
            TextButton(
                child: const Text('Fullscreen'),
                onPressed: () => Navigator.of(context, rootNavigator: true)
                    .push<void>(MaterialPageRoute(
                        builder: (context) => Scaffold(
                                body: Column(children: [
                              const Text('Fullscreen video'),
                              TextButton(
                                  child: const Text('Open menu'),
                                  onPressed: () => showDialog<void>(
                                      context: context,
                                      builder: (_) => const AlertDialog(
                                          title: Text('Player menu')))),
                            ]))))),
          ]))),
    );
  }
}
