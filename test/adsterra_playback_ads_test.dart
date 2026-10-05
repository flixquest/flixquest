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
    service = AdsterraPlaybackAdsService();
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
      (experiment) => experiment['variants'][1]['browser'] = 'unknown',
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

  test('publishable catalogs enable separate format and browser experiments',
      () {
    final formats = AdsterraPlaybackAdsConfig.parse(
        File('docs/adsterra_playback_ads.json').readAsStringSync(),
        enabled: true);
    final arms = formats.streamFoundExperiment!.variants;
    expect(arms[0].placement.scriptUrl!.host, 'aarems.org');
    expect(arms[0].placement.autoActivate, isTrue);
    expect(arms[1].placement.smartlinkUrl!.host, 'directyp.org');
    expect(arms.map((arm) => arm.placement.browser),
        everyElement(PlaybackAdBrowser.external));
    final browsers = AdsterraPlaybackAdsConfig.parse(
        File('docs/adsterra_playback_browser_test.json').readAsStringSync(),
        enabled: true);
    final browserArms = browsers.streamFoundExperiment!.variants;
    expect(browserArms.map((arm) => arm.placement.browser),
        [PlaybackAdBrowser.inApp, PlaybackAdBrowser.external]);
    expect(
        browserArms[0].placement.subId, isNot(browserArms[1].placement.subId));
    expect(browserArms[0].placement.smartlinkUrl,
        browserArms[1].placement.smartlinkUrl);
  });

  testWidgets(
      'blank redirect pages keep their load timeout after a prior ready page',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    controller.delegate!.onPageFinished!('https://ads.example/smartlink');
    await tester.pump();
    expect(find.text('Loading advertisement…'), findsNothing);
    controller.pageHasContent = false;
    controller.delegate!.onPageStarted!('https://offer.example/blank');
    controller.delegate!.onPageFinished!('https://offer.example/blank');
    await tester.pump();
    expect(find.text('Loading advertisement…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets(
      'content arriving after page finished removes loading indicator without reloading',
      (tester) async {
    platform.pageHasContent = false;
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    controller.delegate!.onPageFinished!('https://offer.example/slow');
    await tester.pump();
    expect(find.text('Loading advertisement…'), findsOneWidget);
    controller.pageHasContent = true;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Loading advertisement…'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    expect(controller.requests, hasLength(1));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets(
      'programmatic Popunder activation does not treat script loading as a popup',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse(
        catalog.replaceFirst('"script_url":"https://ads.example/pop"',
            '"script_url":"https://ads.example/pop","auto_activate":true'),
        enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    controller.send('{"event":"loaded"}');
    controller.send('{"event":"activated"}');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(platform.controllers, hasLength(1));
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets(
      'external browser return before launch acknowledgement continues once',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse(
        smartlinkCatalog.replaceFirst(
            '"mode":"smartlink"', '"mode":"smartlink","browser":"external"'),
        enabled: true));
    final acknowledgement = Completer<bool>();
    var requests = 0;
    service = AdsterraPlaybackAdsService(externalLauncher: (_) {
      requests++;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return acknowledgement.future;
    });
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    acknowledgement.complete(true);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(requests, 1);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
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

    service = AdsterraPlaybackAdsService();
    final second = service.streamFound(host);
    await pumpAd(tester);
    expect(
        platform.controllers.last.requests.single,
        Uri.parse(
            'https://ads.example/smartlink?existing=1&psid=fqsmartinapp'));
    provider.setAdsterraAdsConfig(testAdsterraConfig());
    await tester.pump();
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Close ad'));
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

  testWidgets(
      'external Smartlink launches once and waits through background until return',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse(
        smartlinkCatalog.replaceFirst(
            '"mode":"smartlink"', '"mode":"smartlink","browser":"external"'),
        enabled: true));
    final requests = <Uri>[];
    service = AdsterraPlaybackAdsService(externalLauncher: (uri) async {
      requests.add(uri);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      return true;
    });
    await pumpHost(tester);
    bool continued = false;
    final result = service.streamFound(host).then((value) => continued = value);
    await pumpAd(tester);
    expect(requests, [Uri.parse('https://ads.example/smartlink')]);
    expect(platform.controllers, isEmpty);
    await tester.pump(const Duration(seconds: 10));
    expect(continued, isFalse);
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets(
      'remote disable while external browser is open waits for foreground',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse(
        smartlinkCatalog.replaceFirst(
            '"mode":"smartlink"', '"mode":"smartlink","browser":"external"'),
        enabled: true));
    service = AdsterraPlaybackAdsService(externalLauncher: (_) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      return true;
    });
    await pumpHost(tester);
    bool continued = false;
    final result = service.streamFound(host).then((value) => continued = value);
    await pumpAd(tester);
    provider.setAdsterraPlaybackAdsConfig(const AdsterraPlaybackAdsConfig());
    await tester.pumpAndSettle();
    expect(Navigator.of(host).canPop(), isFalse);
    expect(continued, isFalse);
    expect(await service.streamFound(host), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets(
      'external Popunder launches emitted advertiser URL instead of script',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse(
        catalog.replaceFirst('"script_url":"https://ads.example/pop"',
            '"script_url":"https://ads.example/pop","browser":"external"'),
        enabled: true));
    final requests = <Uri>[];
    service = AdsterraPlaybackAdsService(externalLauncher: (uri) async {
      requests.add(uri);
      return true;
    });
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    expect(requests, isEmpty);
    controller.send('{"event":"offer","url":"https://offer.example/ad"}');
    controller
        .send('{"event":"offer","url":"https://offer.example/duplicate"}');
    await tester.pump();
    await tester.pump();
    expect(requests, [Uri.parse('https://offer.example/ad')]);
    expect(controller.javaScriptMode, JavaScriptMode.disabled);
    expect(platform.controllers, hasLength(1));
    // A successful launch with no departure falls back instead of stranding playback.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets(
      'failed external browser launch continues without a second ad request',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig.parse(
        smartlinkCatalog.replaceFirst(
            '"mode":"smartlink"', '"mode":"smartlink","browser":"external"'),
        enabled: true));
    var requests = 0;
    service = AdsterraPlaybackAdsService(externalLauncher: (_) async {
      requests++;
      return false;
    });
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(requests, 1);
    expect(platform.controllers, isEmpty);
  }, variant: android);

  testWidgets(
      'stream found automatically navigates Smartlink with one WebView and no tap',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final controller = platform.controllers.single;
    expect(controller.requests, [Uri.parse('https://ads.example/smartlink')]);
    expect(controller.htmlLoads, isEmpty);
    expect(controller.channel, isNull);
    expect(find.text('Continue to player'), findsNothing);
    final delegate = controller.delegate!;
    expect(
        await delegate.onNavigationRequest!(NavigationRequest(
            url: 'https://offer.example/redirect', isMainFrame: true)),
        NavigationDecision.navigate);
    expect(
        await delegate.onNavigationRequest!(
            NavigationRequest(url: 'intent://offer', isMainFrame: true)),
        NavigationDecision.prevent);
    delegate.onPageFinished!('https://offer.example/redirect');
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    expect(platform.controllers, hasLength(1));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(controller.javaScriptMode, JavaScriptMode.disabled);
    expect(controller.requests.last, Uri.parse('about:blank'));
  }, variant: android);

  testWidgets('a stalled Smartlink continues playback on the load timeout',
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

  testWidgets(
      'a redirected Smartlink HTTP error fails without waiting for the ad duration',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
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
    expect(provider.isAdsterraBannerActive, isFalse);
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
  });

  test(
      'optional programmatic activation targets only the publisher control once',
      () {
    final placement = PlaybackAdPlacement(
        scriptUrl: Uri.parse('https://ads.example/pop'), autoActivate: true);
    final html = playbackAdHtml(placement, PlaybackAdStage.streamFound);
    expect(html, contains('document.getElementById("fq-continue").click()'));
    expect(
        html, contains('if(!fqPopReady||fqActivated)return;fqActivated=true;'));
    expect(html, isNot(contains('dispatchEvent')));
    expect(html, isNot(contains('isTrusted=')));
    expect(playbackAdHtml(placement, PlaybackAdStage.beforeLoader),
        isNot(contains('.click()')));
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(platform.controllers.single.javaScriptMode, JavaScriptMode.disabled);
    expect(await service.beforeLoader(host), isTrue);
    expect(platform.controllers, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
      'Smartlink retries immediately after a failed load despite legacy cooldown',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final first = service.streamFound(host);
    await pumpAd(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await first, isTrue);

    final second = service.streamFound(host);
    await pumpAd(tester);
    expect(platform.controllers, hasLength(2));
    expect(platform.controllers.last.requests,
        [Uri.parse('https://ads.example/smartlink')]);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await second, isTrue);
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
      'popup opens one visible advertiser page and keeps playback waiting',
      (tester) async {
    await pumpHost(tester);
    var continued = false;
    final result = service.streamFound(host).then((value) {
      continued = value;
    });
    await pumpAd(tester);
    final opener = platform.controllers.single;
    opener.send('{"event":"offer","url":"https://offer.example/ad"}');
    opener.send('{"event":"offer","url":"https://offer.example/duplicate"}');
    await tester.pump();
    await tester.pump();
    expect(platform.controllers, hasLength(2));
    final offer = platform.controllers.last;
    expect(offer.requests, [Uri.parse('https://offer.example/ad')]);
    expect(opener.javaScriptMode, JavaScriptMode.disabled);
    opener.send('{"event":"done"}');
    await tester.pump();
    expect(continued, isFalse);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    await result;
    expect(continued, isTrue);
    expect(offer.javaScriptMode, JavaScriptMode.disabled);
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
}
