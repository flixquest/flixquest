import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/adsterra_playback_ads_service.dart';
import 'package:flixquest/services/app_remote_config.dart';
import 'package:flixquest/services/device_presentation_service.dart';
import 'package:flixquest/widgets/adsterra_playback_ad_screen.dart';
import 'package:flixquest/widgets/adsterra_playback_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/fake_adsterra_webview.dart';
import 'support/fake_remote_config.dart';

const catalog = '''{
  "interstitial":{"enabled":true,"script_url":"https://ads.example/social","load_timeout_ms":1000,"max_duration_seconds":5,"cooldown_seconds":60},
  "popunder":{"enabled":true,"script_url":"https://ads.example/pop","load_timeout_ms":1000,"max_duration_seconds":5,"cooldown_seconds":60}
}''';
const smartlinkCatalog = '''{
  "popunder":{"enabled":true,"mode":"smartlink","url":"https://ads.example/smartlink","load_timeout_ms":1000,"max_duration_seconds":5,"cooldown_seconds":60}
}''';
const slowSmartlinkCatalog = '''{
  "popunder":{"enabled":true,"mode":"smartlink","url":"https://ads.example/smartlink","load_timeout_ms":10000,"max_duration_seconds":30}
}''';
const experimentCatalog = '''{
  "stream_found_experiment": {
    "enabled":true,"id":"formats_v1","variants":[
      {"id":"pop","enabled":true,"mode":"script","script_url":"https://ads.example/pop","browser":"in_app","load_timeout_ms":1000,"max_duration_seconds":5},
      {"id":"smart","enabled":true,"mode":"smartlink","url":"https://ads.example/smartlink?existing=1","sub_id":"fqsmartinapp","browser":"in_app","load_timeout_ms":1000,"max_duration_seconds":5}
    ]
  }
}''';

void main() {
  late FakeAdsterraWebViewPlatform platform;
  late AppDependencyProvider provider;
  late AdsterraPlaybackAdsService service;
  late BuildContext host;
  late List<Uri> storeLaunches;

  Future<bool> recordStoreLaunch(Uri uri) async {
    storeLaunches.add(uri);
    return true;
  }

  setUpAll(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    platform = FakeAdsterraWebViewPlatform()..signalLoaded = false;
    WebViewPlatform.instance = platform;
    provider = AppDependencyProvider()
      ..setAdsterraPlaybackAdsConfig(
          AdsterraPlaybackAdsConfig.parse(catalog, enabled: true));
    storeLaunches = [];
    service = AdsterraPlaybackAdsService(storeLauncher: recordStoreLaunch);
  });
  tearDown(() {
    DevicePresentationService.instance.isTelevision = false;
    TestWidgetsFlutterBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        host = context;
        return const Text('Title details');
      }))),
    ));
  }

  Future<void> pumpAd(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  final android = const TargetPlatformVariant({TargetPlatform.android});

  test('config rejects malformed, disabled, unsafe and dashboard ID values',
      () {
    for (final raw in [
      '',
      '{',
      '[]',
      '{"popunder":31570989}',
      '{"popunder":{"script_url":"https://ads.example/tag"}}'
    ]) {
      expect(
          AdsterraPlaybackAdsConfig.parse(raw, enabled: true).popunder, isNull);
    }
    for (final url in [
      'http://ads.example/tag',
      'javascript:alert(1)',
      'https://u:p@ads.example/',
      'https://ads.example/"<script>'
    ]) {
      final raw = jsonEncode({
        'popunder': {'enabled': true, 'script_url': url}
      });
      expect(
          AdsterraPlaybackAdsConfig.parse(raw, enabled: true).popunder, isNull);
    }
    expect(
        AdsterraPlaybackAdsConfig.parse(catalog, enabled: false)
            .forStage(PlaybackAdStage.streamFound),
        isNull);
  });

  test('timeouts are bounded', () {
    final config = AdsterraPlaybackAdsConfig.parse(
            jsonEncode({
              'popunder': {
                'enabled': true,
                'script_url': 'https://ads.example/tag',
                'load_timeout_ms': 999999,
                'max_duration_seconds': -1,
              }
            }),
            enabled: true)
        .popunder!;
    expect(config.loadTimeout, const Duration(seconds: 10));
    expect(config.maxDuration, const Duration(seconds: 5));
  });

  test('Smartlinks require an explicit mode and a valid HTTPS URL', () {
    final placement =
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true)
            .popunder!;
    expect(placement.isSmartlink, isTrue);
    expect(placement.scriptUrl, isNull);
    expect(placement.smartlinkUrl, Uri.parse('https://ads.example/smartlink'));
    for (final raw in [
      smartlinkCatalog.replaceFirst(
          'https://ads.example/smartlink', 'javascript:alert(1)'),
      smartlinkCatalog.replaceFirst('smartlink"', 'unknown"'),
      '{"popunder":{"enabled":true,"url":"https://ads.example/"}}',
    ]) {
      expect(
          AdsterraPlaybackAdsConfig.parse(raw, enabled: true).popunder, isNull);
    }
  });

  test(
      'experiments reject duplicate arms and invalid modes without legacy fallback',
      () {
    final valid = jsonDecode(experimentCatalog) as Map<String, dynamic>;
    final config =
        AdsterraPlaybackAdsConfig.parse(experimentCatalog, enabled: true);
    expect(config.streamFoundExperiment!.variants, hasLength(2));
    expect(config.popunder, isNull);
    for (final corrupt in <void Function(Map<String, dynamic>)>[
      (experiment) =>
          experiment['variants'][1]['id'] = experiment['variants'][0]['id'],
      (experiment) => experiment['variants'][1]['mode'] = 'popup',
      (experiment) => experiment['variants'][1]['sub_id'] = '<bad>',
      (experiment) => experiment['id'] = '',
    ]) {
      final raw = jsonDecode(experimentCatalog) as Map<String, dynamic>;
      corrupt(raw['stream_found_experiment'] as Map<String, dynamic>);
      raw['popunder'] = (jsonDecode(smartlinkCatalog) as Map)['popunder'];
      final invalid =
          AdsterraPlaybackAdsConfig.parse(jsonEncode(raw), enabled: true);
      expect(invalid.forStage(PlaybackAdStage.streamFound), isNull);
      expect(invalid.streamFoundExperiment, isNull);
    }
    valid['stream_found_experiment']['enabled'] = false;
    valid['popunder'] = (jsonDecode(smartlinkCatalog) as Map)['popunder'];
    expect(
        AdsterraPlaybackAdsConfig.parse(jsonEncode(valid), enabled: true)
            .forStage(PlaybackAdStage.streamFound)!
            .isSmartlink,
        isTrue);
  });

  test('Smartlink tracking preserves other query parameters and uses psid', () {
    final placement =
        AdsterraPlaybackAdsConfig.parse(experimentCatalog, enabled: true)
            .streamFoundExperiment!
            .variants[1]
            .placement;
    expect(placement.trackedSmartlinkUrl!.queryParameters,
        {'existing': '1', 'psid': 'fqsmartinapp'});
  });

  test('the published catalog shows the Smartlink on stream found', () {
    final supplied = AdsterraPlaybackAdsConfig.parse(
        File('docs/adsterra_playback_ads.json').readAsStringSync(),
        enabled: true);
    expect(supplied.streamFoundExperiment, isNull);
    final smartlink = supplied.forStage(PlaybackAdStage.streamFound)!;
    expect(smartlink.smartlinkUrl!.host, 'directyp.org');
    expect(smartlink.trackedSmartlinkUrl!.queryParameters['psid'],
        'fqsmartpagev1');
  });

  testWidgets(
      'loaded Popunder waits past the load timeout for the viewer\'s tap',
      (tester) async {
    // Legacy remote values with auto_activate still parse; the key is ignored.
    provider.setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse(
        catalog.replaceFirst('"script_url":"https://ads.example/pop"',
            '"script_url":"https://ads.example/pop","auto_activate":true'),
        enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    expect(controller.htmlLoads.single, isNot(contains('.click()')));
    controller.send('{"event":"loaded"}');
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    controller.send('{"event":"done"}');
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(platform.controllers, hasLength(1));
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets(
      'Popunder page ignores script reloads of about:blank or its base URL',
      (tester) async {
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    final delegate = controller.delegate!;
    for (final url in [
      'about:blank',
      'https://appassets.androidplatform.net/adsterra/'
    ]) {
      expect(
          await delegate.onNavigationRequest!(
              NavigationRequest(url: url, isMainFrame: true)),
          NavigationDecision.prevent);
    }
    expect(controller.requests, isEmpty);
    expect(platform.controllers, hasLength(1));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets(
      'experiment alternates across service recreation without cooldown',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(experimentCatalog, enabled: true));
    await pumpHost(tester);
    final first = service.streamFound(host);
    await pumpAd(tester);
    expect(platform.controllers.single.htmlLoads.single,
        contains('https://ads.example/pop'));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await first, isTrue);

    service = AdsterraPlaybackAdsService(storeLauncher: recordStoreLaunch);
    final second = service.streamFound(host);
    await pumpAd(tester);
    expect(
        platform.controllers.last.requests.single,
        Uri.parse(
            'https://ads.example/smartlink?existing=1&psid=fqsmartinapp'));
    provider.setBannerAdsConfig(testAdsterraConfig());
    await tester.pump();
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    // This arm's 1 s load timeout ends a page that never loads.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await second, isTrue);

    final third = service.streamFound(host);
    await pumpAd(tester);
    expect(platform.controllers.last.htmlLoads.single,
        contains('https://ads.example/pop'));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await third, isTrue);
  }, variant: android);

  testWidgets(
      'experiment skips do not consume a variant and preference work is locked',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(experimentCatalog, enabled: true));
    final preferences = Completer<SharedPreferences>();
    service = AdsterraPlaybackAdsService(preferences: () => preferences.future);
    await pumpHost(tester);
    expect(await service.streamFound(host, download: true), isTrue);
    expect(await service.streamFound(host, television: true), isTrue);
    final result = service.streamFound(host);
    expect(await service.streamFound(host), isFalse);
    expect(platform.controllers, isEmpty);
    preferences.complete(sharedPrefsSingleton);
    await pumpAd(tester);
    expect(platform.controllers.single.htmlLoads.single,
        contains('https://ads.example/pop'));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets('disabling during variant selection prevents a late ad',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(experimentCatalog, enabled: true));
    final preferences = Completer<SharedPreferences>();
    service = AdsterraPlaybackAdsService(preferences: () => preferences.future);
    await pumpHost(tester);
    final result = service.streamFound(host);
    provider.setAdsterraPlaybackAdsConfig(const AdsterraPlaybackAdsConfig());
    preferences.complete(sharedPrefsSingleton);
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(platform.controllers, isEmpty);
  }, variant: android);

  test('published kill switch is required and applies independently of banners',
      () async {
    final remote = FakeFirebaseRemoteConfig();
    await AppRemoteConfig.configure(remote);
    remote.setMockString(AppRemoteConfig.adsterraPlaybackAdsKey, catalog);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.adsterraPlaybackAds.forStage(PlaybackAdStage.beforeLoader),
        isNull);
    remote.setMockBool(AppRemoteConfig.adsterraPlaybackEnabledKey, true);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.adsterraPlaybackAds.interstitial?.scriptUrl.toString(),
        'https://ads.example/social');
    expect(provider.isNetworkBannerActive, isFalse);
    remote.setMockBool(AppRemoteConfig.adsterraPlaybackEnabledKey, false);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.adsterraPlaybackAds.forStage(PlaybackAdStage.streamFound),
        isNull);
  });

  test('pop script receives a real DOM button with no fabricated clicks', () {
    final config = AdsterraPlaybackAdsConfig.parse(catalog, enabled: true);
    final html = playbackAdHtml(config.popunder!, PlaybackAdStage.streamFound);
    expect(html, contains('https://ads.example/pop'));
    expect(html, contains('Continue to player'));
    expect(html, contains('addEventListener("click"'));
    expect(html, isNot(contains('.click()')));
    expect(html, isNot(contains('dispatchEvent')));
    expect(html, isNot(contains('window.open=')));
    expect(html, contains('data-cfasync="false"'));
    expect(html, contains('<script defer data-cfasync="false"'));
  });

  test('Continue stays disabled until the Popunder tag has loaded', () {
    final placement =
        PlaybackAdPlacement(scriptUrl: Uri.parse('https://ads.example/pop'));
    final html = playbackAdHtml(placement, PlaybackAdStage.streamFound);
    expect(html, contains('<button id="fq-continue" type="button" disabled>'));
    expect(html, contains('b.disabled=false'));
    expect(html, contains('Sponsored: an ad may open'));
    expect(html, isNot(contains('.click()')));
    expect(html, isNot(contains('isTrusted')));
  });

  testWidgets('TV and downloads issue no requests at either stage',
      (tester) async {
    await pumpHost(tester);
    for (final stage in PlaybackAdStage.values) {
      expect(await service.show(host, stage, download: true), isTrue);
      expect(await service.show(host, stage, television: true), isTrue);
      DevicePresentationService.instance.isTelevision = true;
      expect(await service.show(host, stage), isTrue);
      DevicePresentationService.instance.isTelevision = false;
    }
    expect(platform.controllers, isEmpty);
  }, variant: android);

  testWidgets('unsupported desktop bypasses ads', (tester) async {
    await pumpHost(tester);
    expect(await service.beforeLoader(host), isTrue);
    expect(platform.controllers, isEmpty);
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets(
      'backgrounding stops an active ad and starts no hidden ad requests',
      (tester) async {
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    var continued = false;
    unawaited(result.then((value) => continued = value));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(platform.controllers.single.javaScriptMode, JavaScriptMode.disabled);
    expect(await service.beforeLoader(host), isTrue);
    expect(platform.controllers, hasLength(1));
    // Playback is not handed off while FlixQuest is in the background.
    expect(continued, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets('blank interstitial times out even when its script loaded',
      (tester) async {
    await pumpHost(tester);
    final result = service.beforeLoader(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    controller.send('{"event":"loaded"}');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(controller.javaScriptMode, JavaScriptMode.disabled);
    expect(controller.requests.last, Uri.parse('about:blank'));
  }, variant: android);

  testWidgets(
      'rendered interstitial stays visible until close or maximum duration',
      (tester) async {
    await pumpHost(tester);
    final result = service.beforeLoader(host);
    await pumpAd(tester);
    platform.controllers.single.send('{"event":"rendered"}');
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets(
      'overlapping requests are blocked but closing allows immediate repeat despite legacy cooldown',
      (tester) async {
    await pumpHost(tester);
    final result = service.beforeLoader(host);
    await pumpAd(tester);
    expect(await service.beforeLoader(host), isFalse);
    expect(platform.controllers, hasLength(1));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    final repeat = service.beforeLoader(host);
    await pumpAd(tester);
    expect(platform.controllers, hasLength(2));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await repeat, isTrue);
    final pop = service.streamFound(host);
    await pumpAd(tester);
    expect(platform.controllers, hasLength(3));
    platform.controllers.last.send('{"event":"done"}');
    await tester.pumpAndSettle();
    expect(await pop, isTrue);
  }, variant: android);

  testWidgets(
      'remote disable closes active ad and late popup messages do nothing',
      (tester) async {
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    provider.setAdsterraPlaybackAdsConfig(const AdsterraPlaybackAdsConfig());
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    controller.send('{"event":"offer","url":"https://offer.example/"}');
    await tester.pump();
    expect(platform.controllers, hasLength(1));
    expect(find.text('Title details'), findsOneWidget);
  }, variant: android);

  testWidgets(
      'Smartlink close and Back wait until the final redirect is served',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final page = platform.controllers.single;
    expect(page.requests, [Uri.parse('https://ads.example/smartlink')]);
    expect(page.htmlLoads, isEmpty);
    expect(find.byTooltip('Close ad'), findsNothing);
    final delegate = page.delegate!;
    expect(
        await delegate.onNavigationRequest!(NavigationRequest(
            url: 'https://offer.example/redirect', isMainFrame: true)),
        NavigationDecision.navigate);
    // An intermediate page with content is not the final ad if it redirects.
    delegate.onPageStarted!('https://offer.example/redirect');
    delegate.onPageFinished!('https://offer.example/redirect');
    await tester.pump(const Duration(milliseconds: 400));
    delegate.onPageStarted!('https://offer.example/final');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    delegate.onPageFinished!('https://offer.example/final');
    await tester.pump();
    expect(find.text('Loading advertisement…'), findsNothing);
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.pump(AdsterraPlaybackAdScreen.redirectSettle);
    expect(find.byTooltip('Close ad'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(page.javaScriptMode, JavaScriptMode.disabled);
    expect(page.requests.last, Uri.parse('about:blank'));
  }, variant: android);

  testWidgets('close appears at the cap when the ad never settles',
      (tester) async {
    platform.pageHasContent = false;
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    platform.controllers.single.delegate!
        .onPageFinished!('https://offer.example/blank');
    await tester.pump(const Duration(seconds: 4));
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Close ad'), findsOneWidget);
    expect(find.text('Loading advertisement…'), findsOneWidget);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets('a link that answers with XML closes the ad page at once',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final page = platform.controllers.single
      ..contentReport = '{"ready":false,"textLength":180,"type":"text/xml"}';
    page.delegate!.onPageFinished!('https://ads.example/click');
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets('a stalled ad page continues playback on the load timeout',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(platform.controllers, hasLength(1));
  }, variant: android);

  testWidgets('a redirected Smartlink HTTP error continues playback',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final delegate = platform.controllers.single.delegate!;
    await delegate.onNavigationRequest!(NavigationRequest(
        url: 'https://offer.example/redirect', isMainFrame: true));
    delegate.onHttpError!(HttpResponseError(
      request:
          WebResourceRequest(uri: Uri.parse('https://offer.example/redirect')),
      response: WebResourceResponse(
          uri: Uri.parse('https://offer.example/redirect'), statusCode: 403),
    ));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  test('app-store offer links map to the store app and a web page', () {
    final market =
        offerAppLink(Uri.parse('market://details?id=com.game&referrer=x'))!;
    expect(market.app, Uri.parse('market://details?id=com.game&referrer=x'));
    expect(
        market.web,
        Uri.parse('https://play.google.com/store/apps/details'
            '?id=com.game&referrer=x'));
    final intent = offerAppLink(Uri.parse('intent://open#Intent;'
        'package=com.game;S.browser_fallback_url='
        'https%3A%2F%2Foffer.example%2Flp;end'))!;
    expect(intent.app, Uri.parse('market://details?id=com.game'));
    expect(intent.web, Uri.parse('https://offer.example/lp'));
    expect(
        offerAppLink(Uri.parse('intent://offer.example/lp?a=1#Intent;'
                'scheme=https;end'))!
            .web,
        Uri.parse('https://offer.example/lp?a=1'));
    expect(
        offerAppLink(Uri.parse('intent://x#Intent;package=com.game;end'))!.web,
        Uri.parse('https://play.google.com/store/apps/details?id=com.game'));
    expect(offerAppLink(Uri.parse('tel:123')), isNull);
    expect(offerAppLink(Uri.parse('market://search?q=x')), isNull);
  });

  testWidgets('an automatic Play Store redirect shows the web listing in place',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final page = platform.controllers.single;
    expect(
        await page.delegate!.onNavigationRequest!(NavigationRequest(
            url: 'market://details?id=com.game', isMainFrame: true)),
        NavigationDecision.prevent);
    await tester.pump();
    expect(storeLaunches, isEmpty);
    expect(page.requests.last,
        Uri.parse('https://play.google.com/store/apps/details?id=com.game'));
    await tester.pump(AdsterraPlaybackAdScreen.closeDelayCap);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets(
      'tapping Install hands off to the store app and resumes playback on return',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    service = AdsterraPlaybackAdsService(storeLauncher: (uri) async {
      storeLaunches.add(uri);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      return true;
    });
    await pumpHost(tester);
    var continued = false;
    final result = service.streamFound(host).then((value) => continued = value);
    await pumpAd(tester);
    final page = platform.controllers.single;
    await tester.tap(find.byKey(const ValueKey('fake-webview')),
        warnIfMissed: false);
    await page.delegate!.onNavigationRequest!(NavigationRequest(
        url: 'market://details?id=com.game', isMainFrame: true));
    await tester.pump();
    expect(storeLaunches, [Uri.parse('market://details?id=com.game')]);
    // Leaving for the store closes the ad; no web listing is loaded instead.
    expect(page.requests, [
      Uri.parse('https://ads.example/smartlink'),
      Uri.parse('about:blank')
    ]);
    expect(continued, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets('a script popup opens once in the ad page and stops the tag',
      (tester) async {
    await pumpHost(tester);
    var continued = false;
    final result = service.streamFound(host).then((value) {
      continued = value;
    });
    await pumpAd(tester);
    final opener = platform.controllers.single;
    expect(find.byTooltip('Close ad'), findsOneWidget);
    expect(
        await opener.delegate!.onNavigationRequest!(NavigationRequest(
            url: 'https://offer.example/ad', isMainFrame: true)),
        NavigationDecision.prevent);
    opener.send('{"event":"offer","url":"https://offer.example/duplicate"}');
    await tester.pump();
    await tester.pump();
    expect(platform.controllers, hasLength(2));
    final page = platform.controllers.last;
    expect(page.requests, [Uri.parse('https://offer.example/ad')]);
    expect(opener.javaScriptMode, JavaScriptMode.disabled);
    expect(find.byTooltip('Close ad'), findsNothing);
    opener.send('{"event":"done"}');
    await tester.pump();
    expect(continued, isFalse);
    page.delegate!.onPageFinished!('https://offer.example/ad');
    await tester.pump();
    await tester.pump(AdsterraPlaybackAdScreen.redirectSettle);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    await result;
    expect(continued, isTrue);
    expect(page.javaScriptMode, JavaScriptMode.disabled);
  }, variant: android);

  testWidgets('Social Bar cannot open unsolicited advertiser redirects',
      (tester) async {
    await pumpHost(tester);
    final result = service.beforeLoader(host);
    await pumpAd(tester);
    platform.controllers.single
        .send('{"event":"offer","url":"https://offer.example/"}');
    await tester.pump();
    expect(platform.controllers, hasLength(1));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets('failed script releases playback without another request',
      (tester) async {
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    platform.controllers.single.send('{"event":"failed"}');
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(platform.controllers, hasLength(1));
  }, variant: android);

  testWidgets('media loader is constructed only after interstitial dismissal',
      (tester) async {
    await pumpHost(tester);
    var builds = 0;
    final route = Navigator.of(host).push<void>(MaterialPageRoute(
        builder: (_) => AdsterraPlaybackGate(
              builder: (_) {
                builds++;
                return const Scaffold(body: Text('Media loader'));
              },
            )));
    await pumpAd(tester);
    await tester.pump();
    expect(builds, 0);
    expect(find.text('Media loader'), findsNothing);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(builds, greaterThan(0));
    expect(find.text('Media loader'), findsOneWidget);
    Navigator.of(tester.element(find.text('Media loader'))).pop();
    await tester.pumpAndSettle();
    await route;
  }, variant: android);

  group('Clickadu popup', () {
    final clickadu = File('docs/clickadu_playback_ads.json').readAsStringSync();

    PopunderAdsConfig parseClickadu(String raw, {required bool enabled}) =>
        PopunderAdsConfig.parse(raw,
            network: AdNetwork.clickadu, enabled: enabled);

    void selectClickadu() => provider
      ..setPopunderAdsConfig(parseClickadu(clickadu, enabled: true))
      ..setPlaybackPopunderNetwork(AdNetwork.clickadu);

    test('the published catalog runs the onclick tag for zone 2150355', () {
      final config = parseClickadu(clickadu, enabled: true);
      final popunder = config.activePopunder!;
      expect(popunder.network, AdNetwork.clickadu);
      expect(popunder.scriptUrl,
          Uri.parse('https://driverhugoverblown.com/on.js'));
      expect(popunder.zoneId, '2150355');
      expect(popunder.loadTimeout, const Duration(seconds: 10));
      expect(
          parseClickadu(clickadu, enabled: false)
              .activePopunder,
          isNull);
    });

    test('config rejects a tag without a zone and Adsterra sub IDs', () {
      for (final popunder in [
        {'enabled': true, 'script_url': 'https://driverhugoverblown.com/on.js'},
        {
          'enabled': true,
          'script_url': 'https://driverhugoverblown.com/on.js',
          'zone_id': '21503"55'
        },
        {
          'enabled': true,
          'mode': 'smartlink',
          'url': 'https://clickadu.example/direct',
          'sub_id': 'fq'
        },
      ]) {
        expect(
            parseClickadu(jsonEncode({'popunder': popunder}),
                    enabled: true)
                .activePopunder,
            isNull);
      }
      final direct = parseClickadu(
              jsonEncode({
                'popunder': {
                  'enabled': true,
                  'mode': 'smartlink',
                  'url': 'https://clickadu.example/direct'
                }
              }),
              enabled: true)
          .activePopunder!;
      expect(direct.trackedSmartlinkUrl,
          Uri.parse('https://clickadu.example/direct'));
      expect(
          parseClickadu(
                  jsonEncode({
                    'popunder': {
                      'enabled': true,
                      'script_url': 'https://driverhugoverblown.com/on.js',
                      'zone_id': 2150355
                    }
                  }),
                  enabled: true)
              .activePopunder
              ?.zoneId,
          '2150355');
    });

    test('the tag finds its zone on its own script element', () {
      final html = playbackAdHtml(
          parseClickadu(clickadu, enabled: true).popunder!,
          PlaybackAdStage.streamFound);
      expect(
          html,
          contains('<script defer data-cfasync="false" data-clocid="2150355" '
              'src="https://driverhugoverblown.com/on.js"'));
      expect(html, contains('Continue to player'));
      // Continue waits for the tag's own ad request, not its script load.
      expect(html, contains('onload="fqTagLoaded()"'));
      expect(html, contains("indexOf('/adx/get/')"));
      final adsterra = playbackAdHtml(
          AdsterraPlaybackAdsConfig.parse(catalog, enabled: true).popunder!,
          PlaybackAdStage.streamFound);
      expect(adsterra, isNot(contains('data-clocid')));
      expect(adsterra, isNot(contains('fqTagLoaded')));
      expect(adsterra, contains('onload="fqSignal(\'loaded\')"'));
    });

    testWidgets('a tag that never fetches its ad continues on the load timeout',
        (tester) async {
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      platform.controllers.single.send('{"event":"script"}');
      await tester.pump(const Duration(seconds: 9));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    }, variant: android);

    testWidgets('an armed tag waits for the viewer past the load timeout',
        (tester) async {
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single
        ..send('{"event":"script"}')
        ..send('{"event":"loaded"}');
      await tester.pump(const Duration(seconds: 12));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      opener.send('{"event":"done"}');
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    test('Remote Config picks the network and needs Clickadu\'s own switch',
        () async {
      final remote = FakeFirebaseRemoteConfig();
      await AppRemoteConfig.configure(remote);
      remote.setMockString(AppRemoteConfig.clickaduPlaybackAdsKey, clickadu);
      AppRemoteConfig.apply(remote, provider);
      expect(provider.playbackPopunderNetwork, AdNetwork.adsterra);
      expect(provider.popunderAdsFor(AdNetwork.clickadu).activePopunder, isNull);
      remote
        ..setMockBool(AppRemoteConfig.clickaduPlaybackEnabledKey, true)
        ..setMockString(AppRemoteConfig.playbackPopunderNetworkKey, 'Clickadu');
      AppRemoteConfig.apply(remote, provider);
      expect(provider.playbackPopunderNetwork, AdNetwork.clickadu);
      expect(provider.popunderAdsFor(AdNetwork.clickadu).activePopunder?.zoneId, '2150355');
      for (final value in ['none', 'popads']) {
        remote.setMockString(AppRemoteConfig.playbackPopunderNetworkKey, value);
        AppRemoteConfig.apply(remote, provider);
        expect(provider.playbackPopunderNetwork, isNull);
      }
    });

    testWidgets('its popup opens in the ad page with the held close',
        (tester) async {
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      expect(opener.htmlLoads.single, contains('data-clocid="2150355"'));
      // The tag opens its window from the viewer's tap on Continue.
      expect(
          await opener.delegate!.onNavigationRequest!(NavigationRequest(
              url: 'https://driverhugoverblown.com/click', isMainFrame: true)),
          NavigationDecision.prevent);
      await tester.pump();
      await tester.pump();
      final page = platform.controllers.last;
      expect(
          page.requests, [Uri.parse('https://driverhugoverblown.com/click')]);
      expect(opener.javaScriptMode, JavaScriptMode.disabled);
      expect(find.byTooltip('Close ad'), findsNothing);
      page.delegate!.onPageFinished!('https://advertiser.example/');
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.redirectSettle);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('the Social Bar stays with Adsterra', (tester) async {
      selectClickadu();
      await pumpHost(tester);
      final result = service.beforeLoader(host);
      await pumpAd(tester);
      final html = platform.controllers.single.htmlLoads.single;
      expect(html, contains('https://ads.example/social'));
      expect(html, isNot(contains('data-clocid')));
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('switching networks closes an active popup', (tester) async {
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      provider.setPlaybackPopunderNetwork(AdNetwork.adsterra);
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    }, variant: android);

    testWidgets('no network shows no popup', (tester) async {
      selectClickadu();
      provider.setPlaybackPopunderNetwork(null);
      await pumpHost(tester);
      expect(await service.streamFound(host), isTrue);
      expect(platform.controllers, isEmpty);
    }, variant: android);
  });

  group('Monetag popup', () {
    final monetag = File('docs/monetag_playback_ads.json').readAsStringSync();

    PopunderAdsConfig parseMonetag(String raw, {bool enabled = true}) =>
        PopunderAdsConfig.parse(raw,
            network: AdNetwork.monetag, enabled: enabled);

    String popunder(Map<String, Object> fields) =>
        jsonEncode({'popunder': {'enabled': true, ...fields}});

    test('config takes a zoned tag, a /401/ tag or a Direct Link', () {
      final tag = parseMonetag(monetag).activePopunder!;
      expect(tag.network, AdNetwork.monetag);
      expect(tag.scriptUrl, Uri.parse('https://al5sm.com/tag.min.js'));
      expect(tag.zoneId, '11983408');
      expect(tag.loadTimeout, const Duration(seconds: 10));
      expect(parseMonetag(monetag, enabled: false).activePopunder, isNull);
      // Monetag's inline onclick snippet puts the zone in the script path.
      final inline = parseMonetag(
              popunder({'script_url': 'https://monetag.example/401/11983408'}))
          .activePopunder!;
      expect(inline.zoneId, isNull);
      expect(
          parseMonetag(popunder(
                  {'mode': 'smartlink', 'url': 'https://monetag.example/4/1'}))
              .activePopunder
              ?.trackedSmartlinkUrl,
          Uri.parse('https://monetag.example/4/1'));
      for (final invalid in [
        {'script_url': 'https://monetag.example/tag.min.js', 'zone_id': '1"2'},
        {
          'mode': 'smartlink',
          'url': 'https://monetag.example/4/1',
          'sub_id': 'fq'
        },
      ]) {
        expect(parseMonetag(popunder(invalid)).activePopunder, isNull);
      }
    });

    test('the tag reads its zone from data-zone and arms on load', () {
      final html = playbackAdHtml(parseMonetag(monetag).popunder!,
          PlaybackAdStage.streamFound);
      expect(
          html,
          contains('<script defer data-cfasync="false" data-zone="11983408" '
              'src="https://al5sm.com/tag.min.js"'));
      expect(html, contains('onload="fqSignal(\'loaded\')"'));
      expect(html, isNot(contains('data-clocid')));
    });

    test('Remote Config needs Monetag\'s own switch', () async {
      final remote = FakeFirebaseRemoteConfig();
      await AppRemoteConfig.configure(remote);
      remote
        ..setMockString(AppRemoteConfig.monetagPlaybackAdsKey, monetag)
        ..setMockString(AppRemoteConfig.playbackPopunderNetworkKey, 'monetag');
      AppRemoteConfig.apply(remote, provider);
      expect(provider.playbackPopunderNetwork, AdNetwork.monetag);
      expect(provider.popunderAdsFor(AdNetwork.monetag).activePopunder, isNull);
      remote.setMockBool(AppRemoteConfig.monetagPlaybackEnabledKey, true);
      AppRemoteConfig.apply(remote, provider);
      expect(provider.popunderAdsFor(AdNetwork.monetag).activePopunder?.zoneId,
          '11983408');
    });

    testWidgets('its popup opens in the ad page', (tester) async {
      provider
        ..setPopunderAdsConfig(parseMonetag(monetag))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      expect(opener.htmlLoads.single, contains('data-zone="11983408"'));
      expect(
          await opener.delegate!.onNavigationRequest!(NavigationRequest(
              url: 'https://monetag.example/click', isMainFrame: true)),
          NavigationDecision.prevent);
      await tester.pump();
      await tester.pump();
      final page = platform.controllers.last;
      expect(page.requests, [Uri.parse('https://monetag.example/click')]);
      expect(find.byTooltip('Close ad'), findsNothing);
      page.delegate!.onPageFinished!('https://advertiser.example/');
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.redirectSettle);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);
  });
}
