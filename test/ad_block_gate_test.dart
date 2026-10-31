import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/ad_block_detector.dart';
import 'package:flixquest/services/ad_block_check_cache.dart';
import 'package:flixquest/services/ad_delivery.dart';
import 'package:flixquest/services/ad_redirect_resolver.dart';
import 'package:flixquest/widgets/ad_block_gate.dart';
import 'package:flixquest/widgets/ad_block_warmup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_adsterra_webview.dart';
import 'support/tv_localization.dart';

final real = InternetAddress('104.21.27.36');

/// Local DNS answers per host; a missing host fails like NXDOMAIN.
HostLookup lookupFrom(Map<String, List<List<InternetAddress>>> answers,
        [List<String>? calls]) =>
    (host) async {
      calls?.add(host);
      if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
      final queue = answers[host];
      if (queue == null || queue.isEmpty) {
        throw SocketException('Failed host lookup: $host');
      }
      return queue.length == 1 ? queue.single : queue.removeAt(0);
    };

void main() {
  initializeTvTranslations();

  setUpAll(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  group('AdBlockDetector', () {
    AdBlockDetector detector(Map<String, List<List<InternetAddress>>> local,
            {Map<String, bool?> public = const {},
            List<String>? publicCalls}) =>
        AdBlockDetector(
          lookup: lookupFrom(local),
          publicLookup: (host) async {
            publicCalls?.add(host);
            return public[host];
          },
        );

    test('a sinkholed ad host is a blocker', () async {
      for (final sinkhole in [
        '0.0.0.0',
        '::',
        '127.0.0.1',
        '::1',
        '::ffff:127.0.0.1',
        '::ffff:0.0.0.0',
      ]) {
        final result = await detector({
          'ads.example': [
            [InternetAddress(sinkhole)]
          ],
        }).isBlocking({'ads.example'});
        expect(result, isTrue, reason: sinkhole);
      }
    });

    test('a popup blocked on a live host counts once public DNS knows it',
        () async {
      for (final (known, expected) in [
        (true, true),
        (false, false),
        (null, false)
      ]) {
        final check = AdBlockDetector(
          lookup: lookupFrom({
            'ads.example': [
              [real]
            ],
          }),
          publicLookup: (_) async => known,
        );
        expect(
            await check
                .isBlocking({'ads.example'}, observedBlocked: {'ads.example'}),
            expected,
            reason: 'public DNS: $known');
      }
    });

    test('real answers never consult public DNS', () async {
      final publicCalls = <String>[];
      final result = await detector({
        'ads.example': [
          [real]
        ],
        'cdn.example': [
          [real, InternetAddress('0.0.0.0')]
        ],
      }, publicCalls: publicCalls)
          .isBlocking({'ads.example', 'cdn.example'});
      expect(result, isFalse);
      expect(publicCalls, isEmpty);
    });

    test('a host only public DNS can resolve is a blocker', () async {
      final result = await detector({}, public: {'ads.example': true})
          .isBlocking({'ads.example'});
      expect(result, isTrue);
    });

    test('a retired ad domain is not a blocker', () async {
      final result = await detector({}, public: {'ads.example': false})
          .isBlocking({'ads.example'});
      expect(result, isFalse);
    });

    test('no public answer, as when offline, is not a blocker', () async {
      final result = await detector({}).isBlocking({'ads.example'});
      expect(result, isFalse);
    });

    test('sinkholes for the whole network do not accuse an ad blocker',
        () async {
      final brokenNetwork = AdBlockDetector(
        lookup: (_) async => [InternetAddress('0.0.0.0')],
        publicLookup: (_) async => true,
      );
      expect(await brokenNetwork.isBlocking({'ads.example'}), isFalse);
    });

    test('unexpected probe failure cannot hide another positive check',
        () async {
      final check = detector({});
      expect(
          await check.isBlocking({}, additionalChecks: [
            () async => throw StateError('unavailable WebView'),
            () async => true,
          ]),
          isTrue);
    });

    test('a one-off local failure is retried before blaming a blocker',
        () async {
      final calls = <String>[];
      final flaky = AdBlockDetector(
        lookup: (host) async {
          if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
          calls.add(host);
          if (calls.length == 1) throw const SocketException('timeout');
          return [real];
        },
        publicLookup: (_) async => true,
      );
      expect(await flaky.isBlocking({'ads.example'}), isFalse);
      expect(calls, hasLength(2));
    });

    test('a check that runs too long allows playback', () async {
      final slow = AdBlockDetector(
        lookup: (_) => Completer<List<InternetAddress>>().future,
        timeout: const Duration(milliseconds: 10),
      );
      expect(await slow.isBlocking({'ads.example'}), isFalse);
    });

    test('a stalled host cannot hide another host being sinkholed', () async {
      final probe = AdBlockDetector(
        lookup: (host) => AdBlockDetector.dnsControlHosts.contains(host)
            ? Future.value([real])
            : host == 'stalled.example'
                ? Completer<List<InternetAddress>>().future
                : Future.value([InternetAddress('0.0.0.0')]),
        timeout: const Duration(milliseconds: 50),
      );
      expect(await probe.isBlocking({'stalled.example', 'blocked.example'}),
          isTrue);
    });

    test('a stalled public resolver cannot hide a confirmed blocked host',
        () async {
      final probe = AdBlockDetector(
        lookup: (host) async => AdBlockDetector.dnsControlHosts.contains(host)
            ? [real]
            : throw const SocketException('NXDOMAIN'),
        publicLookup: (host) => host == 'stalled.example'
            ? Completer<bool?>().future
            : Future.value(true),
        timeout: const Duration(milliseconds: 50),
      );
      expect(await probe.isBlocking({'stalled.example', 'blocked.example'}),
          isTrue);
    });

    test('a fallback chain is blocked only when every network in it is',
        () async {
      final check = detector({
        'exo.example': [
          [InternetAddress('0.0.0.0')]
        ],
        'adsterra.example': [
          [real]
        ],
        'other.example': [
          [InternetAddress('0.0.0.0')]
        ],
      });
      expect(
          await check.isBlocking({}, alternatives: [
            {'exo.example', 'adsterra.example'}
          ]),
          isFalse);
      expect(
          await check.isBlocking({}, alternatives: [
            {'exo.example', 'other.example'}
          ]),
          isTrue);
    });

    test('popup and VAST fallbacks form chains; banners stand alone', () {
      final provider = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig())
        ..setPlaybackPopunderNetwork(AdNetwork.exoclick)
        ..setTvPlaybackPopunderNetwork(AdNetwork.exoclick)
        ..setPlaybackPopunderFallbackNetworks([AdNetwork.adsterra])
        ..setPopunderAdsConfig(PopunderAdsConfig.parse('''{
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://flix.quest/api/exoclick-popup"},
          "tv_popunder":{"enabled":true,"mode":"smartlink","url":"https://flix.quest/api/exoclick-popup"}
        }''', network: AdNetwork.exoclick, enabled: true))
        ..setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse('''{
          "interstitial":{"enabled":true,"script_url":"https://social.example/s"},
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://smart.example/l"},
          "tv_popunder":{"enabled":true,"mode":"smartlink","url":"https://smart.example/tv"}
        }''', enabled: true));
      final phone = AdBlockDetector.adSources(provider);
      expect(phone.required, {
        for (final unit in testAdsterraConfig().units.values) unit.scriptUrl,
        Uri.parse('https://social.example/s'),
      });
      expect(phone.alternatives, [
        {
          Uri.parse('https://flix.quest/api/exoclick-popup'),
          Uri.parse('https://smart.example/l'),
        }
      ]);
      final tv = AdBlockDetector.adSources(provider, television: true);
      expect(tv.alternatives, [
        {
          Uri.parse('https://flix.quest/api/exoclick-popup'),
          Uri.parse('https://smart.example/tv'),
        }
      ]);
    });

    test('no ad hosts means nothing to check', () async {
      expect(await detector({}).isBlocking({}), isFalse);
    });

    test('ad hosts come from live banners and Adsterra playback ads', () {
      final provider = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig())
        ..setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse('''{
          "interstitial":{"enabled":true,"script_url":"https://social.example/s"},
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://smart.example/l"}
        }''', enabled: true));
      expect(AdBlockDetector.adHosts(provider),
          {'ads.example', 'social.example', 'smart.example'});
      // TV shows neither the Social Bar nor the phone popup.
      expect(
          AdBlockDetector.adHosts(provider, television: true), {'ads.example'});

      provider
        ..setBannerAdNetwork('none')
        ..setAdsterraPlaybackAdsConfig(
            const AdsterraPlaybackAdsConfig(enabled: false));
      expect(AdBlockDetector.adHosts(provider), isEmpty);
    });

    test('selected popup networks are checked on mobile and TV', () {
      final provider = AppDependencyProvider()
        ..setPlaybackPopunderNetwork(AdNetwork.monetag)
        ..setTvPlaybackPopunderNetwork(AdNetwork.exoclick)
        ..setPopupTrigger(PlaybackAdStage.download,
            enabled: true, frequencyMinutes: 0);
      for (final network in [
        AdNetwork.monetag,
        AdNetwork.exoclick,
        AdNetwork.clickadu,
      ]) {
        provider.setPopunderAdsConfig(PopunderAdsConfig.parse('''{
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://${network.name}.example/ad"},
          "tv_popunder":{"enabled":true,"mode":"smartlink","url":"https://tv.${network.name}.example/ad"},
          "download":{"enabled":true,"mode":"script","script_url":"https://download.${network.name}.example/ad"}
        }''', network: network, enabled: true));
      }
      expect(AdBlockDetector.adHosts(provider),
          {'monetag.example', 'download.monetag.example'});
      expect(AdBlockDetector.adHosts(provider, television: true),
          {'tv.exoclick.example'});

      provider.setPlaybackPopunderFallbackNetworks([AdNetwork.clickadu]);
      expect(AdBlockDetector.adHosts(provider, television: true),
          {'tv.exoclick.example', 'tv.clickadu.example'});

      provider
        ..setPlaybackPopunderNetwork(null)
        ..setTvPlaybackPopunderNetwork(null)
        ..setPlaybackPopunderFallbackNetworks(const []);
      expect(AdBlockDetector.adHosts(provider), isEmpty);
      expect(AdBlockDetector.adHosts(provider, television: true), isEmpty);
    });

    test('FlixQuest redirectors are resolved, not probed as ad hosts', () {
      final provider = AppDependencyProvider()
        ..setPlaybackPopunderNetwork(AdNetwork.exoclick)
        ..setPopunderAdsConfig(PopunderAdsConfig.parse('''{
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://flix.quest/api/exoclick-popup"},
          "tv_popunder":{"enabled":true,"mode":"smartlink","url":"https://flix.quest/api/exoclick-popup"}
        }''', network: AdNetwork.exoclick, enabled: true));
      for (final television in [false, true]) {
        expect(
            AdBlockDetector.adHosts(provider, television: television), isEmpty);
        expect(AdBlockDetector.adRedirects(provider, television: television),
            {Uri.parse('https://flix.quest/api/exoclick-popup')});
      }
    });

    test('TV only probes banners switched on for TV', () {
      final provider = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig(tvEnabled: false));
      expect(AdBlockDetector.adHosts(provider), {'ads.example'});
      expect(AdBlockDetector.adHosts(provider, television: true), isEmpty);
    });

    test('banner slot overrides contribute their active domains', () {
      final provider = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig())
        ..setBannerAdsConfig(testClickaduConfig())
        ..setBannerAdNetworkOverrides({'movie_detail': 'clickadu'});
      expect(AdBlockDetector.adHosts(provider),
          containsAll(['ads.example', 'cl.example', 'cl2.example']));
      provider.setBannerAdNetwork('none');
      expect(AdBlockDetector.adHosts(provider), isEmpty);
    });
  });

  group('AdBlockGate', () {
    late AppDependencyProvider provider;
    late bool blocked;
    late int checks;
    late BuildContext host;

    setUp(() {
      provider = AppDependencyProvider()
        ..setBannerAdsConfig(testAdsterraConfig())
        ..adBlockGateEnabled = true;
      blocked = true;
      checks = 0;
    });

    AdBlockGate gate() => AdBlockGate(
          // Retry-dialog tests explicitly await detection. Production uses
          // zero foreground wait, covered by the background playback tests.
          cache: AdBlockCheckCache(
              foregroundWait: const Duration(milliseconds: 700)),
          additionalChecks: const [],
          detector: AdBlockDetector(
            lookup: (host) async {
              if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
              if (host == 'ads.example') checks++;
              return [blocked ? InternetAddress('0.0.0.0') : real];
            },
          ),
        );

    Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
          ChangeNotifierProvider<AppDependencyProvider>.value(
            value: provider,
            child: MaterialApp(
              home: Builder(builder: (context) {
                host = context;
                return const SizedBox();
              }),
            ),
          ),
        );

    testWidgets('does nothing until the remote switch is on', (tester) async {
      provider.adBlockGateEnabled = false;
      await pumpHost(tester);
      expect(await gate().allowPlayback(host), isTrue);
      expect(checks, 0);
    });

    testWidgets('lets viewers without a blocker straight through',
        (tester) async {
      blocked = false;
      await pumpHost(tester);
      expect(await gate().allowPlayback(host), isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('transport or WebView evidence triggers the same gate',
        (tester) async {
      await pumpHost(tester);
      final check = AdBlockGate(
        detector: AdBlockDetector(lookup: (_) async => [real]),
        additionalChecks: [
          (_, ads) async {
            expect(ads.all, {'ads.example'});
            return true;
          }
        ],
      );
      await check.warmUp(host);
      final result = check.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets(
        'playback starts immediately without losing later background evidence',
        (tester) async {
      await pumpHost(tester);
      final pending = Completer<bool>();
      final shared = AdBlockGate(
        detector: AdBlockDetector(lookup: (_) async => [real]),
        cache: AdBlockCheckCache(now: tester.binding.clock.now),
        additionalChecks: [(_, __) => pending.future],
      );
      final first = shared.allowPlayback(host);
      await tester.pump();
      expect(await first, isTrue);
      pending.complete(true);
      await tester.pump();
      final second = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await second, isFalse);
    });

    testWidgets('a remote toggle starts checking an already blocked device',
        (tester) async {
      provider.adBlockGateEnabled = false;
      await pumpHost(tester);
      final shared = gate();
      expect(await shared.allowPlayback(host), isTrue);
      expect(checks, 0);

      provider.adBlockGateEnabled = true;
      final result = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('blocked ad domains FlixQuest does not use are not evidence',
        (tester) async {
      final lookedUp = <String>[];
      var webChecks = 0;
      final probe = AdBlockGate(
        additionalChecks: [
          (_, __) async {
            webChecks++;
            return false;
          }
        ],
        detector: AdBlockDetector(lookup: (host) async {
          lookedUp.add(host);
          return [
            host == 'doubleclick.net' ? InternetAddress('0.0.0.0') : real
          ];
        }),
      );
      await pumpHost(tester);
      await probe.warmUp(host);
      expect(await probe.allowPlayback(host), isTrue);
      expect(lookedUp, contains('ads.example'));
      expect(lookedUp, isNot(contains('doubleclick.net')));
      expect(webChecks, 1);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('nothing is checked while no ad is live', (tester) async {
      provider.setBannerAdNetwork('none');
      var webChecks = 0;
      final probe = AdBlockGate(
        additionalChecks: [
          (_, __) async {
            webChecks++;
            return true;
          }
        ],
        detector: AdBlockDetector(lookup: (_) async {
          checks++;
          return [InternetAddress('0.0.0.0')];
        }),
      );
      await pumpHost(tester);
      expect(await probe.allowPlayback(host), isTrue);
      expect(checks, 0);
      expect(webChecks, 0);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('a TV is not stopped over a phone-only ad host',
        (tester) async {
      provider
        ..setBannerAdNetwork('none')
        ..setTvPlaybackPopunderNetwork(AdNetwork.adsterra)
        ..setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse('''{
          "interstitial":{"enabled":true,"script_url":"https://social.example/s"},
          "tv_popunder":{"enabled":true,"mode":"smartlink","url":"https://tv.example/l"}
        }''', enabled: true));
      final lookedUp = <String>[];
      final probe = AdBlockGate(
        cache: AdBlockCheckCache(
            foregroundWait: const Duration(milliseconds: 700)),
        additionalChecks: const [],
        detector: AdBlockDetector(lookup: (host) async {
          if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
          lookedUp.add(host);
          return [host == 'social.example' ? InternetAddress('0.0.0.0') : real];
        }),
      );
      await pumpHost(tester);
      expect(await probe.allowPlayback(host, television: true), isTrue);
      expect(lookedUp, ['tv.example']);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('a blocked ExoClick popup is fine while Adsterra falls back',
        (tester) async {
      provider
        ..setBannerAdNetwork('none')
        ..setPlaybackPopunderNetwork(AdNetwork.exoclick)
        ..setPlaybackPopunderFallbackNetworks([AdNetwork.adsterra])
        ..setPopunderAdsConfig(PopunderAdsConfig.parse('''{
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://exo.example/l"}
        }''', network: AdNetwork.exoclick, enabled: true))
        ..setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse('''{
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://smart.example/l"}
        }''', enabled: true));
      var adsterraBlocked = false;
      AdBlockGate probe() => AdBlockGate(
            cache: AdBlockCheckCache(
                foregroundWait: const Duration(milliseconds: 700)),
            additionalChecks: const [],
            detector: AdBlockDetector(lookup: (host) async {
              if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
              final blocked = host == 'exo.example' ||
                  (adsterraBlocked && host == 'smart.example');
              return [blocked ? InternetAddress('0.0.0.0') : real];
            }),
          );
      await pumpHost(tester);
      expect(await probe().allowPlayback(host), isTrue);
      expect(find.byType(Dialog), findsNothing);

      adsterraBlocked = true;
      final result = probe().allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('ExoClick\'s rotating delivery domain is what gets checked',
        (tester) async {
      provider
        ..setBannerAdNetwork('none')
        ..setPlaybackPopunderNetwork(AdNetwork.exoclick)
        ..setPopunderAdsConfig(PopunderAdsConfig.parse('''{
          "popunder":{"enabled":true,"mode":"smartlink","url":"https://flix.quest/api/exoclick-popup"}
        }''', network: AdNetwork.exoclick, enabled: true));
      final requests = <http.BaseRequest>[];
      final lookedUp = <String>[];
      final probe = AdBlockGate(
        cache: AdBlockCheckCache(
            foregroundWait: const Duration(milliseconds: 700)),
        additionalChecks: const [],
        redirects: AdRedirectResolver(
          clientFactory: () => MockClient((request) async {
            requests.add(request);
            return http.Response('', 302, headers: {
              'location': 'https://s.rotating.example/v1/link.php?idzone=1'
            });
          }),
        ),
        detector: AdBlockDetector(lookup: (host) async {
          lookedUp.add(host);
          if (AdBlockDetector.dnsControlHosts.contains(host)) return [real];
          return [
            host == 's.rotating.example' ? InternetAddress('0.0.0.0') : real
          ];
        }),
      );
      await pumpHost(tester);
      final result = probe.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(requests.single.method, 'HEAD');
      expect(lookedUp, contains('s.rotating.example'));
      expect(lookedUp, isNot(contains('flix.quest')));
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('a blocked popup stops playback; a no-fill popup does not',
        (tester) async {
      blocked = false;
      await pumpHost(tester);
      final now = DateTime(2026, 10, 31);
      final shared = AdBlockGate(
        cache: AdBlockCheckCache(
            foregroundWait: const Duration(milliseconds: 700)),
        now: () => now,
        detector: AdBlockDetector(
          lookup: (host) async => [real],
          publicLookup: (_) async => true,
        ),
      );
      expect(await shared.allowPlayback(host), isTrue);

      // The network answered with no ad: not a blocker.
      shared.observeDelivery('ads.example', AdDelivery.reached);
      expect(await shared.allowPlayback(host), isTrue);
      expect(shared.blocksPlayback(provider), isFalse);

      shared.observeDelivery('ads.example', AdDelivery.blocked);
      final result = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(shared.blocksPlayback(provider), isTrue);
      expect(find.text('Turn off your ad blocker'), findsOneWidget);

      // "I turned it off" forgets the popup and checks DNS again.
      await tester.tap(find.text('I turned it off'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('a popup that reached its network outweighs a DNS sinkhole',
        (tester) async {
      await pumpHost(tester);
      final shared = gate()..observeDelivery('ads.example', AdDelivery.reached);
      expect(await shared.allowPlayback(host), isTrue);
      expect(checks, 0);
    });

    testWidgets('waits for the blocker to go, then continues', (tester) async {
      await pumpHost(tester);
      final result = gate().allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);

      // Still blocked: the dialog returns with the reminder.
      await tester.tap(find.text('I turned it off'));
      await tester.pumpAndSettle();
      expect(find.textContaining('still on'), findsOneWidget);

      blocked = false;
      await tester.tap(find.text('I turned it off'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('cancelling stops playback', (tester) async {
      await pumpHost(tester);
      final result = gate().allowPlayback(host, download: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets(
        'network invalidation does not hide a newly enabled DNS blocker',
        (tester) async {
      blocked = false;
      await pumpHost(tester);
      final shared = gate();
      expect(await shared.allowPlayback(host), isTrue);
      expect(checks, 1);

      blocked = true;
      shared.invalidate();
      final result = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(checks, 2);
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('warmup is silent and refreshes on network changes and resume',
        (tester) async {
      final network = StreamController<List<ConnectivityResult>>(sync: true);
      final shared = gate();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
            home: AdBlockWarmup(
          gate: shared,
          networkChanges: network.stream,
          child: Builder(builder: (context) {
            host = context;
            return const Scaffold();
          }),
        )),
      ));
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(find.byType(Dialog), findsNothing);
      network.add([ConnectivityResult.wifi]);
      await tester.pumpAndSettle();
      expect(checks, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(checks, 3);
      final playback = shared.allowPlayback(host);
      await tester.pumpAndSettle();
      expect(find.text('Turn off your ad blocker'), findsOneWidget);
      expect(checks, 3);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await playback, isFalse);
      await tester.pumpWidget(const SizedBox());
      unawaited(network.close());
    });
  });
}
