import 'dart:io';

import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/data/ads/ads_policy.dart';
import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/models/banner_ad.dart';
import 'package:flixquest/models/vast_preroll_config.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/screens/common/player/player_preroll_ad.dart';
import 'package:flixquest/services/ad_block_check_cache.dart';
import 'package:flixquest/services/ad_block_detector.dart';
import 'package:flixquest/services/adsterra_playback_ads_service.dart';
import 'package:flixquest/services/hosted_ads_repository.dart';
import 'package:flixquest/services/vast/vast_client.dart';
import 'package:flixquest/widgets/ad_block_gate.dart';
import 'package:flixquest/widgets/adsterra_playback_ad_screen.dart';
import 'package:flixquest/widgets/hosted_ads_banner.dart';
import 'package:flixquest/widgets/network_banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/fake_adsterra_webview.dart';

const _catalog = '''{
  "interstitial":{"enabled":true,"script_url":"https://ads.example/social","load_timeout_ms":1000,"max_duration_seconds":5},
  "popunder":{"enabled":true,"script_url":"https://ads.example/pop","load_timeout_ms":1000,"max_duration_seconds":5}
}''';

/// FlixQuest Plus means no ad requests and no ad side effects anywhere,
/// while playback and browsing keep working.
void main() {
  late AppDependencyProvider provider;
  late FakeAdsterraWebViewPlatform platform;
  late BuildContext host;

  setUpAll(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  setUp(() {
    platform = FakeAdsterraWebViewPlatform()..signalLoaded = false;
    WebViewPlatform.instance = platform;
    provider = AppDependencyProvider()
      ..setBannerAdsConfig(testAdsterraConfig())
      ..setAdsterraPlaybackAdsConfig(
          AdsterraPlaybackAdsConfig.parse(_catalog, enabled: true))
      ..adBlockGateEnabled = true;
    AdsPolicy.update(adFree: true);
  });

  tearDown(() => AdsPolicy.update(adFree: false));

  Future<void> pumpHost(WidgetTester tester, {Widget? child}) =>
      tester.pumpWidget(ChangeNotifierProvider<AppDependencyProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(body: Builder(builder: (context) {
            host = context;
            return child ?? const Text('Title details');
          })),
        ),
      ));

  final android = const TargetPlatformVariant({TargetPlatform.android});

  testWidgets('playback popups never open and playback still proceeds',
      (tester) async {
    final service = AdsterraPlaybackAdsService();
    await pumpHost(tester);

    expect(service.needsBeforeLoader(host), isFalse);
    expect(service.preloadStreamFound(host), isNull);
    expect(await service.beforeLoader(host), isTrue);
    expect(await service.streamFound(host), isTrue);
    await tester.pump();

    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(platform.controllers, isEmpty);
  }, variant: android);

  testWidgets('Plus that starts during a popup closes it and plays on',
      (tester) async {
    AdsPolicy.update(adFree: false);
    final service = AdsterraPlaybackAdsService();
    await pumpHost(tester);
    final result = service.streamFound(host);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);

    AdsPolicy.update(adFree: true);
    await tester.pumpAndSettle();

    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(await result, isTrue);
  }, variant: android);

  testWidgets('an owed player-exit popup is settled, not replayed later',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'playback_ads.player_exit_owed_at': DateTime.now().millisecondsSinceEpoch,
    });
    final service = AdsterraPlaybackAdsService();
    await pumpHost(tester);

    await service.showOwedPlayerExitOnLaunch(host);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('playback_ads.player_exit_owed_at'), isNull);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets('no ad-blocker check runs and nobody is asked to turn one off',
      (tester) async {
    var lookups = 0;
    final gate = AdBlockGate(
      cache: AdBlockCheckCache(),
      additionalChecks: [
        (_) async {
          lookups++;
          return true;
        }
      ],
      detector: AdBlockDetector(lookup: (_) async {
        lookups++;
        return [InternetAddress('0.0.0.0')];
      }),
    );
    await pumpHost(tester);

    await gate.warmUp(host);
    expect(await gate.allowPlayback(host), isTrue);
    expect(gate.blocksPlayback(provider), isFalse);

    expect(lookups, 0);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('empty announcement slots collapse without rendering advertising',
      (tester) async {
    var loads = 0;
    await pumpHost(tester,
        child: RemoteHostedAdsBanner(
          placement: 'downloads',
          loadAds: () async {
            loads++;
            return const <BannerAd>[];
          },
        ));
    await tester.pump();

    expect(loads, 1);
    expect(find.byType(NetworkBannerWidget), findsNothing);
    expect(platform.controllers, isEmpty);
    expect(tester.getSize(find.byType(RemoteHostedAdsBanner)), Size.zero);
  });

  testWidgets('a banner on screen goes away the moment Plus starts',
      (tester) async {
    AdsPolicy.update(adFree: false);
    const ad = BannerAd(
      key: 'announcement',
      id: '1',
      name: 'Announcement',
      imageUrl: 'https://example.test/ad.png',
      targetUrl: 'https://example.test/join',
      altText: 'Join',
    );
    await pumpHost(tester,
        child: const HostedAdsBanner(ads: [ad], interactive: false));
    expect(find.byType(PageView), findsOneWidget);

    AdsPolicy.update(adFree: true);
    await tester.pump();

    expect(find.byType(PageView), findsNothing);
  });

  test('Plus can fetch the catalog for app announcements', () async {
    var fetches = 0;
    HostedAdsRepository.instance.useFetcherForTesting((_) async {
      fetches++;
      return const <BannerAd>[];
    });

    expect(
        await HostedAdsRepository.instance.load('https://api.test'), isEmpty);
    expect(fetches, 1);
    HostedAdsRepository.instance.clear();
  });

  test('video pre-rolls ask no ad network', () async {
    final requests = <http.Request>[];
    final preroll = PlayerPrerollAd(
      television: false,
      client: VastClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('<VAST version="4.0"/>', 200);
        }),
        userAgent: () async => 'test',
      ),
    );
    final config = VastPrerollConfig.parse(
        '{"tag_url":"https://a.example/t.xml"}',
        enabled: true,
        networks: [AdNetwork.clickadu]);

    expect(await preroll.load(config), isNull);
    expect(requests, isEmpty);
    preroll.dispose();
  });
}
