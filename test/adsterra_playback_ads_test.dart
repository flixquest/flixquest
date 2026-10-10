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
import 'package:flutter/services.dart';
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
const tvCatalog = '''{
  "popunder":{"enabled":true,"script_url":"https://ads.example/pop","load_timeout_ms":10000,"max_duration_seconds":30},
  "tv_popunder":{"enabled":true,"mode":"smartlink","url":"https://ads.example/smartlink","sub_id":"fqtv","load_timeout_ms":10000,"max_duration_seconds":30}
}''';

/// The default `close_fallback_seconds`.
const closeFallback = Duration(seconds: 15);
const slowPopunderCatalog = '''{
  "popunder":{"enabled":true,"script_url":"https://ads.example/pop","load_timeout_ms":10000,"max_duration_seconds":30}
}''';
const experimentCatalog = '''{
  "stream_found_experiment": {
    "enabled":true,"id":"formats_v1","variants":[
      {"id":"pop","enabled":true,"mode":"script","script_url":"https://ads.example/pop","browser":"in_app","load_timeout_ms":1000,"max_duration_seconds":5},
      {"id":"smart","enabled":true,"mode":"smartlink","url":"https://ads.example/smartlink?existing=1","sub_id":"fqsmartinapp","browser":"in_app","load_timeout_ms":1000,"max_duration_seconds":5}
    ]
  }
}''';

class _PlaybackRouteObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

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

  Future<void> pumpHost(WidgetTester tester,
      {NavigatorObserver? observer}) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        navigatorObservers: [if (observer != null) observer],
        home: Scaffold(body: Builder(builder: (context) {
          host = context;
          return const Text('Title details');
        })),
      ),
    ));
  }

  Future<void> pumpAd(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  final android = const TargetPlatformVariant({TargetPlatform.android});

  test('the landing check waits for complete loading and reports its URL',
      () async {
    final process = await Process.start(
        'node', ['test/support/playback_ad_content_fixture.js']);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(playbackAdContentScript);
    await process.stdin.close();
    expect(await process.exitCode, 0,
        reason: '${await output}\n${await errors}');
  });

  testWidgets('native JSON content reports reveal the preloaded advertiser',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    await tester.pump();
    final page = platform.controllers.single
      ..contentReport = jsonEncode({
        'ready': true,
        'textLength': 80,
        'visibleElements': 1,
        'title': 'A "sponsored" offer',
        'type': 'text/html',
      });
    page.delegate!.onPageStarted!('https://offer.example/ad');
    page.delegate!.onPageFinished!('https://offer.example/ad');
    final result = service.streamFound(host, preload: preload);
    await pumpAd(tester);
    expect(find.text('Your video is ready'), findsNothing);
    expect(find.text('Sponsored · offer.example'), findsOneWidget);
    await tester.pump(AdsterraPlaybackAdScreen.minimumView);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('Smartlink preload is reused and counts only its visible view',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    await tester.pump();
    final page = platform.controllers.single;
    expect(page.requests.single, Uri.parse('https://ads.example/smartlink'));
    expect(page.assignedUserAgents.single, isNot(contains('; wv')));
    expect(platform.widgetParams, isEmpty);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    page.delegate!.onPageStarted!('https://offer.example/ad');
    page.delegate!.onPageFinished!('https://offer.example/ad');
    await tester.pump(const Duration(seconds: 5));

    final result = service.streamFound(host, preload: preload);
    await pumpAd(tester);
    expect(platform.controllers, hasLength(1));
    expect(page.requests, hasLength(1));
    expect(find.text('Sponsored · offer.example'), findsOneWidget);
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(page.javaScriptMode, JavaScriptMode.disabled);
  }, variant: android);

  testWidgets('an in-flight preload keeps its original load deadline',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final result = service.streamFound(host, preload: preload);
    await pumpAd(tester);
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    expect(platform.controllers, hasLength(1));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(
        platform.controllers.single.requests
            .where((url) => url.scheme == 'https'),
        hasLength(1));
  }, variant: android);

  testWidgets('a preload timeout skips the ad without another request',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(preload.unavailable, isTrue);
    expect(await service.streamFound(host, preload: preload), isTrue);
    await tester.pump();
    expect(platform.controllers, hasLength(1));
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets('disposing during preload setup cannot start a late ad request',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    platform.setupGate = Completer<void>();
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    preload.dispose();
    platform.setupGate!.complete();
    await tester.pump();
    expect(await preload.ready, isNull);
    expect(platform.controllers.single.requests,
        everyElement(Uri.parse('about:blank')));
    expect(platform.controllers.single.javaScriptMode, JavaScriptMode.disabled);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets('config changes and backgrounding stop unpresented preloads',
      (tester) async {
    final config =
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true);
    provider.setAdsterraPlaybackAdsConfig(config);
    await pumpHost(tester);
    var preload = service.preloadStreamFound(host)!;
    await tester.pump();
    provider.setAdsterraPlaybackAdsConfig(const AdsterraPlaybackAdsConfig());
    await tester.pump();
    expect(preload.unavailable, isTrue);
    expect(platform.controllers.single.javaScriptMode, JavaScriptMode.disabled);

    provider.setAdsterraPlaybackAdsConfig(config);
    preload = service.preloadStreamFound(host)!;
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(preload.unavailable, isTrue);
    expect(platform.controllers.last.javaScriptMode, JavaScriptMode.disabled);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets('ad timeout cancels a preload whose setup is still pending',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    platform.setupGate = Completer<void>();
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    final result = service.streamFound(host, preload: preload);
    await pumpAd(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(preload.unavailable, isTrue);
    platform.setupGate!.complete();
    await tester.pump();
    expect(await preload.ready, isNull);
    expect(platform.controllers.single.requests,
        everyElement(Uri.parse('about:blank')));
  }, variant: android);

  testWidgets('a reused preload forwards later redirects and HTTP failures',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    await tester.pump();
    final page = platform.controllers.single;
    page.delegate!.onPageStarted!('https://offer.example/ad');
    page.delegate!.onPageFinished!('https://offer.example/ad');
    final result = service.streamFound(host, preload: preload);
    await pumpAd(tester);
    page.delegate!.onPageStarted!('https://offer.example/final');
    page.delegate!.onHttpError!(HttpResponseError(
      request:
          WebResourceRequest(uri: Uri.parse('https://offer.example/final')),
      response: WebResourceResponse(
          uri: Uri.parse('https://offer.example/final'), statusCode: 503),
    ));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(platform.controllers, hasLength(1));
  }, variant: android);

  testWidgets('TV preloads use the tracked TV placement', (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(tvCatalog, enabled: true));
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host, television: true)!;
    await tester.pump();
    expect(platform.controllers.single.requests.single,
        Uri.parse('https://ads.example/smartlink?psid=fqtv'));
    preload.dispose();
    await tester.pump();
  }, variant: android);

  testWidgets('preloaded no-ad redirects continue without an ad route',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    await tester.pump();
    expect(
        await platform.controllers.single.delegate!.onNavigationRequest!(
            const NavigationRequest(
                url: 'https://www.google.com/', isMainFrame: true)),
        NavigationDecision.prevent);
    await tester.pump();
    expect(await service.streamFound(host, preload: preload), isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets('preloading an install offer follows only its web fallback',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final preload = service.preloadStreamFound(host)!;
    await tester.pump();
    final page = platform.controllers.single;
    expect(
        await page.delegate!.onNavigationRequest!(const NavigationRequest(
            url: 'market://details?id=com.example.app', isMainFrame: true)),
        NavigationDecision.prevent);
    await tester.pump();
    expect(
        page.requests.last,
        Uri.parse(
            'https://play.google.com/store/apps/details?id=com.example.app'));
    expect(storeLaunches, isEmpty);
    preload.dispose();
    await tester.pump();
  }, variant: android);

  testWidgets('downloads, disabled ads, scripts and experiments do not preload',
      (tester) async {
    await pumpHost(tester);
    expect(service.preloadStreamFound(host), isNull);
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    expect(service.preloadStreamFound(host, download: true), isNull);
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: false));
    expect(service.preloadStreamFound(host), isNull);
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(experimentCatalog, enabled: true));
    expect(service.preloadStreamFound(host), isNull);
    expect(platform.controllers, isEmpty);
    expect(sharedPrefsSingleton.getInt('adsterra_playback.rotation.formats_v1'),
        isNull);
  }, variant: android);

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
    controller.send('{"event":"done"}');
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
    platform.controllers.single.send('{"event":"done"}');
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
    platform.controllers.last.send('{"event":"done"}');
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
    platform.controllers.single.send('{"event":"done"}');
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
    expect(html, contains('Play now'));
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

  test('placements bound the fallback and TV takes only touch-free formats',
      () {
    PlaybackAdPlacement? placement(Object? fallback) =>
        PlaybackAdPlacement.parse({
          'enabled': true,
          'mode': 'smartlink',
          'url': 'https://ads.example/smartlink',
          if (fallback != null) 'close_fallback_seconds': fallback,
        });
    expect(placement(null)!.closeFallback, const Duration(seconds: 15));
    expect(placement(8)!.closeFallback, const Duration(seconds: 8));
    // Google Play allows at most 15 seconds without a way out.
    expect(placement(60)!.closeFallback, const Duration(seconds: 15));
    expect(placement(1)!.closeFallback, const Duration(seconds: 5));

    final config = AdsterraPlaybackAdsConfig.parse(tvCatalog, enabled: true);
    expect(config.forStage(PlaybackAdStage.streamFound, television: true)?.mode,
        'smartlink');
    expect(config.forStage(PlaybackAdStage.beforeLoader, television: true),
        isNull);
    expect(config.forStage(PlaybackAdStage.streamFound)?.scriptUrl,
        Uri.parse('https://ads.example/pop'));
    // A tag that opens its popup only from a touch cannot run on a remote.
    expect(
        AdsterraPlaybackAdsConfig.parse(
                '{"tv_popunder":{"enabled":true,'
                '"script_url":"https://ads.example/pop"}}',
                enabled: true)
            .tvPopunder,
        isNull);
    final monetag = PopunderAdsConfig.parse(
        '{"tv_popunder":{"enabled":true,"script_url":"https://m.example/tag.js",'
        '"zone_id":"1"}}',
        network: AdNetwork.monetag,
        enabled: true);
    expect(monetag.activeFor(television: true)?.zoneId, '1');
    expect(monetag.activeFor(television: false), isNull);
  });

  testWidgets('the TV popup is driven by the remote', (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(tvCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host, television: true);
    await pumpAd(tester);
    final page = platform.controllers.single;
    expect(
        page.requests, [Uri.parse('https://ads.example/smartlink?psid=fqtv')]);
    // Before the ad is seen, OK and the arrows stay on FlixQuest's screen.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown), isTrue);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.select), isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    page.delegate!.onPageFinished!('https://offer.example/tv');
    await tester.pump();
    await tester.pump(AdsterraPlaybackAdScreen.minimumView);
    await tester.pump();
    // The way on takes focus as it appears; OK plays.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'ad continue');
    expect(find.text('Play now'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

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
    expect(find.text('Ad loading'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    // The final ad shows: its minimum view is counted from now.
    delegate.onPageFinished!('https://offer.example/final');
    await tester.pump();
    expect(find.byTooltip('Close ad'), findsNothing);
    expect(find.text('Continue in 3'), findsOneWidget);
    await tester.pump(AdsterraPlaybackAdScreen.redirectSettle);
    // Final, but seen for less than the minimum view: the countdown runs on.
    expect(find.text('Your video is ready'), findsNothing);
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.pump(AdsterraPlaybackAdScreen.minimumView -
        AdsterraPlaybackAdScreen.redirectSettle -
        const Duration(milliseconds: 1));
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byTooltip('Close ad'), findsOneWidget);
    expect(find.text('Play now'), findsOneWidget);
    expect(find.text('Sponsored · offer.example'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(page.javaScriptMode, JavaScriptMode.disabled);
    expect(page.requests.last, Uri.parse('about:blank'));
  }, variant: android);

  testWidgets('the way on appears at the fallback when the ad never settles',
      (tester) async {
    platform.pageHasContent = false;
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final delegate = platform.controllers.single.delegate!;
    // A chain that keeps redirecting never serves its final ad.
    var elapsed = const Duration(milliseconds: 350);
    var hop = 0;
    while (elapsed < closeFallback - const Duration(seconds: 1)) {
      delegate.onPageStarted!('https://offer.example/hop$hop');
      delegate.onPageFinished!('https://offer.example/hop$hop');
      hop++;
      await tester.pump(const Duration(milliseconds: 500));
      elapsed += const Duration(milliseconds: 500);
    }
    expect(find.byTooltip('Close ad'), findsNothing);
    expect(find.text('Your video is ready'), findsOneWidget);
    expect(find.text('Ad loading'), findsOneWidget);
    await tester.pump(closeFallback - elapsed);
    expect(find.byTooltip('Close ad'), findsOneWidget);
    // The placeholder gives way to whatever the page has.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Your video is ready'), findsNothing);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  test('only a search home page counts as an ad chain with no ad', () {
    for (final url in [
      'https://www.google.com',
      'https://www.google.com/',
      'https://google.co.uk/?gws_rd=ssl',
      'http://www.bing.com/',
      'https://yahoo.com',
      'https://www.yahoo.com/',
    ]) {
      expect(isNoAdFallback(Uri.parse(url)), isTrue, reason: url);
    }
    for (final url in [
      'https://play.google.com/store/apps/details?id=com.game',
      'https://www.google.com/search?q=offer',
      'https://yahoo.com/search?p=offer',
      'https://yahoo.com.evil.example/',
      'https://google.example.com/',
      'https://offer.example/',
      'market://details?id=com.game',
    ]) {
      expect(isNoAdFallback(Uri.parse(url)), isFalse, reason: url);
    }
    expect(isNoAdFallback(null), isFalse);
  });

  testWidgets('a redirect chain that ends on google.com continues at once',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    // Caught as the redirect is requested...
    var result = service.streamFound(host);
    await pumpAd(tester);
    expect(
        await platform.controllers.last.delegate!.onNavigationRequest!(
            NavigationRequest(
                url: 'https://www.google.com/', isMainFrame: true)),
        NavigationDecision.prevent);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    // ...or once it starts loading, for redirects the WebView never asked about.
    result = service.streamFound(host);
    await pumpAd(tester);
    platform
        .controllers.last.delegate!.onPageStarted!('https://www.google.co.uk/');
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets('a content check that never answers is asked again',
      (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final page = platform.controllers.single..hangingChecks = 1;
    page.delegate!.onPageFinished!('https://offer.example/ad');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Your video is ready'), findsOneWidget);
    // The lost check times out and the next tick finds the ad.
    await tester.pump(AdsterraPlaybackAdScreen.contentCheckTimeout);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Your video is ready'), findsNothing);
    expect(find.text('Sponsored · offer.example'), findsOneWidget);
    await tester.pump(AdsterraPlaybackAdScreen.minimumView);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets('the tag page offers Skip only at the fallback', (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowPopunderCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    platform.controllers.single.send('{"event":"loaded"}');
    // Its own Play button leads on; Back waits like the ad page's close.
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
    await tester.pump(closeFallback - const Duration(seconds: 1));
    expect(find.byTooltip('Close ad'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Skip'), findsOneWidget);
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
    page.delegate!.onPageFinished!(page.requests.last.toString());
    await tester.pump();
    await tester.pump(AdsterraPlaybackAdScreen.minimumView);
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
    page.delegate!.onPageFinished!('https://ads.example/smartlink');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('fake-webview')),
        warnIfMissed: false);
    await page.delegate!.onNavigationRequest!(NavigationRequest(
        url: 'market://details?id=com.game', isMainFrame: true));
    await tester.pump();
    expect(storeLaunches, [Uri.parse('market://details?id=com.game')]);
    // Leaving for the store closes the ad; no web listing is loaded instead.
    expect(page.requests,
        [Uri.parse('https://ads.example/smartlink'), Uri.parse('about:blank')]);
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
    expect(find.byTooltip('Close ad'), findsNothing);
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
    await tester.pump(AdsterraPlaybackAdScreen.minimumView);
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

  testWidgets('Android removes WebView UA markers before tag and popup loads',
      (tester) async {
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final opener = platform.controllers.single;
    const expectedAgent = 'Mozilla/5.0 (Linux; Android 16; TestDevice) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/153.0.8010.36 Mobile Safari/537.36';
    expect(opener.documentUserAgents.first, expectedAgent);
    opener.send('{"event":"offer","url":"https://offer.example/ad"}');
    await tester.pump();
    final page = platform.controllers.last;
    expect(platform.controllers, hasLength(2));
    expect(page.requests.first, Uri.parse('https://offer.example/ad'));
    expect(page.documentUserAgents.first, expectedAgent);
    page.delegate!.onPageFinished!('https://offer.example/ad');
    await tester.pump();
    await tester.pump(AdsterraPlaybackAdScreen.minimumView);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: android);

  testWidgets('iOS keeps its system user agent', (tester) async {
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(slowSmartlinkCatalog, enabled: true));
    await pumpHost(tester);
    final result = service.streamFound(host);
    await pumpAd(tester);
    final page = platform.controllers.single;
    expect(page.assignedUserAgents, isEmpty);
    page.delegate!.onPageFinished!('https://ads.example/smartlink');
    await tester.pump();
    await tester.pump(AdsterraPlaybackAdScreen.minimumView);
    await tester.tap(find.byTooltip('Close ad'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

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
        builder: (context) => AdsterraPlaybackGate.buildLoader(
              context,
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

  testWidgets('disabled interstitial builds the loader on its first frame',
      (tester) async {
    // Leave the popunder enabled: its switch must not create a before-loader
    // gate when the independent interstitial placement is disabled.
    provider.setAdsterraPlaybackAdsConfig(
        AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true));
    await pumpHost(tester);
    var builds = 0;
    final route = Navigator.of(host).push<void>(MaterialPageRoute(
      builder: (context) => AdsterraPlaybackGate.buildLoader(
        context,
        builder: (_) {
          builds++;
          return const Scaffold(body: Text('Media loader'));
        },
      ),
    ));
    await tester.pump();
    expect(builds, greaterThan(0));
    // MaterialPageRoute measures its first frame offstage before animating.
    expect(find.text('Media loader', skipOffstage: false), findsOneWidget);
    expect(
        find.byType(AdsterraPlaybackGate, skipOffstage: false), findsNothing);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(platform.controllers, isEmpty);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Media loader'))).pop();
    await tester.pumpAndSettle();
    await route;
  }, variant: android);

  testWidgets('disabled interstitial never pushes an advertisement route',
      (tester) async {
    final observer = _PlaybackRouteObserver();
    await pumpHost(tester, observer: observer);
    observer.pushed.clear();
    for (final config in [
      // The master switch is off, though both catalog placements are enabled.
      AdsterraPlaybackAdsConfig.parse(catalog, enabled: false),
      // Only the interstitial switch is off; the popunder remains enabled.
      AdsterraPlaybackAdsConfig.parse(
          catalog.replaceFirst('"interstitial":{"enabled":true',
              '"interstitial":{"enabled":false'),
          enabled: true),
      // No interstitial placement was supplied.
      AdsterraPlaybackAdsConfig.parse(smartlinkCatalog, enabled: true),
    ]) {
      provider.setAdsterraPlaybackAdsConfig(config);
      expect(await service.beforeLoader(host), isTrue);
      await tester.pump();
      expect(observer.pushed, isEmpty);
      expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
      expect(platform.controllers, isEmpty);
    }
  }, variant: android);

  group('Clickadu popup', () {
    final clickadu = File('docs/clickadu_playback_ads.json').readAsStringSync();

    PopunderAdsConfig parseClickadu(String raw, {required bool enabled}) =>
        PopunderAdsConfig.parse(raw,
            network: AdNetwork.clickadu, enabled: enabled);

    void selectClickadu() => provider
      ..setPopunderAdsConfig(parseClickadu(clickadu, enabled: true))
      ..setPlaybackPopunderNetwork(AdNetwork.clickadu);

    testWidgets('cold WebView setup does not consume the tag loading budget',
        (tester) async {
      final setup = Completer<void>();
      platform.setupGate = setup;
      var taps = 0;
      service = AdsterraPlaybackAdsService(continueTap: (_, __) async {
        taps++;
        return true;
      });
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      await tester.pump(const Duration(seconds: 11));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      expect(opener.htmlLoads, isEmpty);
      expect(taps, 0);
      setup.complete();
      await tester.pump();
      await tester.pump();
      expect(opener.htmlLoads, hasLength(1));
      await tester.pump(const Duration(seconds: 9));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      opener.send('{"event":"script"}');
      opener.send('{"event":"loaded"}');
      await tester.pump();
      expect(taps, 1);
      await opener.delegate!.onNavigationRequest!(NavigationRequest(
          url: 'https://clickadu.example/offer', isMainFrame: true));
      await tester.pump();
      await tester.pump();
      final page = platform.controllers.last;
      expect(page.requests, [Uri.parse('https://clickadu.example/offer')]);
      page.delegate!.onPageFinished!('https://advertiser.example/');
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('an ad closed during WebView setup never loads the tag later',
        (tester) async {
      final setup = Completer<void>();
      platform.setupGate = setup;
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      await tester.pump(closeFallback);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      setup.complete();
      await tester.pump();
      await tester.pump();
      expect(opener.htmlLoads, isEmpty);
      expect(platform.controllers, hasLength(1));
    }, variant: android);

    testWidgets('stalled WebView setup is bounded by the screen duration',
        (tester) async {
      final setup = Completer<void>();
      platform.setupGate = setup;
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      setup.complete();
      await tester.pump();
      await tester.pump();
      expect(opener.htmlLoads, isEmpty);
    }, variant: android);

    test('the published catalog runs the onclick tag for zone 2150355', () {
      final config = parseClickadu(clickadu, enabled: true);
      final popunder = config.activePopunder!;
      expect(popunder.network, AdNetwork.clickadu);
      expect(popunder.scriptUrl,
          Uri.parse('https://driverhugoverblown.com/on.js'));
      expect(popunder.zoneId, '2150355');
      expect(popunder.loadTimeout, const Duration(seconds: 10));
      expect(parseClickadu(clickadu, enabled: false).activePopunder, isNull);
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
            parseClickadu(jsonEncode({'popunder': popunder}), enabled: true)
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
      expect(html, contains('Play now'));
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

    testWidgets('one automatic touch opens a delayed popup after the tag arms',
        (tester) async {
      var taps = 0;
      service =
          AdsterraPlaybackAdsService(continueTap: (controller, document) async {
        taps++;
        expect(controller.platform, same(platform.controllers.single));
        expect(document,
            Uri.parse('https://appassets.androidplatform.net/adsterra/'));
        return true;
      });
      selectClickadu();
      await pumpHost(tester);
      expect(service.preloadStreamFound(host), isNull);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      opener.send('{"event":"script"}');
      opener.delegate!
          .onPageFinished!('https://appassets.androidplatform.net/adsterra/');
      await tester.pump();
      expect(taps, 0);
      opener.send('{"event":"loaded"}');
      opener.send('{"event":"loaded"}');
      await tester.pump();
      expect(taps, 1);
      expect(opener.evaluatedScripts, isEmpty);
      opener.send('{"event":"done"}');
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      expect(opener.javaScriptMode, JavaScriptMode.unrestricted);
      await opener.delegate!.onNavigationRequest!(NavigationRequest(
          url: 'https://clickadu.example/delayed', isMainFrame: true));
      await tester.pump();
      await tester.pump();
      final page = platform.controllers.last;
      expect(page.requests, [Uri.parse('https://clickadu.example/delayed')]);
      expect(opener.javaScriptMode, JavaScriptMode.disabled);
      page.delegate!.onPageFinished!('https://advertiser.example/');
      await tester.pump();
      expect(find.byTooltip('Close ad'), findsNothing);
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(taps, 1);
    }, variant: android);

    testWidgets('an automatic touch without a popup has a bounded wait',
        (tester) async {
      var taps = 0;
      service = AdsterraPlaybackAdsService(continueTap: (_, __) async {
        taps++;
        return true;
      });
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      opener.send('{"event":"loaded"}');
      await tester.pump(const Duration(seconds: 4));
      opener.send('{"event":"loaded"}');
      opener.send('{"event":"done"}');
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(taps, 1);
      expect(opener.javaScriptMode, JavaScriptMode.disabled);
      expect(platform.controllers, hasLength(1));
    }, variant: android);

    testWidgets('unavailable native input retains manual Continue',
        (tester) async {
      var taps = 0;
      service = AdsterraPlaybackAdsService(continueTap: (_, __) async {
        taps++;
        return false;
      });
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single
        ..send('{"event":"script"}')
        ..send('{"event":"loaded"}');
      await tester.pump();
      expect(taps, 1);
      expect(opener.evaluatedScripts, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      opener.send('{"event":"done"}');
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('disabling during native input prevents a late popup',
        (tester) async {
      final input = Completer<bool>();
      service =
          AdsterraPlaybackAdsService(continueTap: (_, __) => input.future);
      selectClickadu();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      opener.send('{"event":"loaded"}');
      await tester.pump();
      provider.setPopunderAdsConfig(parseClickadu(clickadu, enabled: false));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(opener.javaScriptMode, JavaScriptMode.disabled);
      input.complete(true);
      opener.send('{"event":"loaded"}');
      await tester.pump();
      expect(opener.evaluatedScripts, isEmpty);
      expect(platform.controllers, hasLength(1));
    }, variant: android);

    testWidgets('a TV tag also opens with one automatic native touch',
        (tester) async {
      final tv = jsonDecode(clickadu) as Map<String, dynamic>;
      tv['tv_popunder'] = tv.remove('popunder');
      provider
        ..setPopunderAdsConfig(parseClickadu(jsonEncode(tv), enabled: true))
        ..setPlaybackPopunderNetwork(AdNetwork.clickadu);
      var taps = 0;
      service = AdsterraPlaybackAdsService(continueTap: (_, __) async {
        taps++;
        return true;
      });
      await pumpHost(tester);
      final result = service.streamFound(host, television: true);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      expect(opener.htmlLoads.single, contains('data-clocid="2150355"'));
      opener.send('{"event":"loaded"}');
      await tester.pump();
      expect(taps, 1);
      await opener.delegate!.onNavigationRequest!(NavigationRequest(
          url: 'https://clickadu.example/tv', isMainFrame: true));
      await tester.pump();
      await tester.pump();
      final page = platform.controllers.last;
      expect(page.requests, [Uri.parse('https://clickadu.example/tv')]);
      page.delegate!.onPageFinished!('https://advertiser.example/');
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
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
      expect(
          provider.popunderAdsFor(AdNetwork.clickadu).activePopunder, isNull);
      remote
        ..setMockBool(AppRemoteConfig.clickaduPlaybackEnabledKey, true)
        ..setMockString(AppRemoteConfig.playbackPopunderNetworkKey, 'Clickadu');
      AppRemoteConfig.apply(remote, provider);
      expect(provider.playbackPopunderNetwork, AdNetwork.clickadu);
      expect(provider.popunderAdsFor(AdNetwork.clickadu).activePopunder?.zoneId,
          '2150355');
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
      // A URL returned by the tag is shown in the same ad page.
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
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
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

  for (final network in [AdNetwork.exoclick, AdNetwork.monetag]) {
    group('${network.name} redirect completion', () {
      const intermediate = 'https://tracker.example/redirect';
      const landing = 'https://advertiser.example/offer';

      Future<({FakeAdsterraWebViewController page, Future<bool> result})>
          openAd(WidgetTester tester) async {
        provider
          ..setPopunderAdsConfig(PopunderAdsConfig.parse(slowSmartlinkCatalog,
              enabled: true, network: network))
          ..setPlaybackPopunderNetwork(network);
        await pumpHost(tester);
        final result = service.streamFound(host);
        await pumpAd(tester);
        return (page: platform.controllers.single, result: result);
      }

      String report(String url, {String state = 'complete'}) => jsonEncode({
            'ready': true,
            'url': url,
            'readyState': state,
            'type': 'text/html',
            'textLength': 80,
            'visibleElements': 1,
          });

      testWidgets('stale page finishes cannot serve the next redirect',
          (tester) async {
        final ad = await openAd(tester);
        final delegate = ad.page.delegate!;
        delegate.onPageStarted!(intermediate);
        delegate.onPageFinished!(intermediate);
        await tester.pump(const Duration(seconds: 1));
        delegate.onPageStarted!(landing);
        delegate.onPageFinished!(intermediate);
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        expect(find.byTooltip('Close ad'), findsNothing);
        expect(find.text('Ad loading'), findsOneWidget);
        delegate.onPageFinished!(landing);
        await tester.pump();
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets('visible content in an unfinished document cannot serve it',
          (tester) async {
        final ad = await openAd(tester);
        ad.page.contentReport = report(landing, state: 'interactive');
        ad.page.delegate!.onPageStarted!(landing);
        ad.page.delegate!.onPageFinished!(landing);
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        expect(find.byTooltip('Close ad'), findsNothing);
        ad.page.contentReport = report(landing);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets('content from a replacement document cannot serve an old URL',
          (tester) async {
        final ad = await openAd(tester);
        ad.page.contentReport = report(landing);
        ad.page.delegate!.onPageStarted!(intermediate);
        ad.page.delegate!.onPageFinished!(intermediate);
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        expect(find.byTooltip('Close ad'), findsNothing);
        ad.page.delegate!.onPageStarted!(landing);
        ad.page.delegate!.onPageFinished!(landing);
        await tester.pump();
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets(
          'an automatic redirect holds close as soon as it is requested',
          (tester) async {
        final ad = await openAd(tester);
        final delegate = ad.page.delegate!;
        delegate.onPageStarted!(intermediate);
        delegate.onPageFinished!(intermediate);
        await tester.pump();
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        expect(find.byTooltip('Close ad'), findsOneWidget);
        expect(
            await delegate.onNavigationRequest!(
                NavigationRequest(url: landing, isMainFrame: true)),
            NavigationDecision.navigate);
        await tester.pump();
        expect(find.byTooltip('Close ad'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
        delegate.onPageStarted!(landing);
        delegate.onPageFinished!(landing);
        await tester.pump();
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets('redirects preserve the original close fallback deadline',
          (tester) async {
        final started = tester.binding.clock.now();
        final ad = await openAd(tester);
        final delegate = ad.page.delegate!;
        delegate.onPageStarted!(intermediate);
        delegate.onPageFinished!(intermediate);
        await tester.pump();
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await delegate.onNavigationRequest!(
            NavigationRequest(url: landing, isMainFrame: true));
        delegate.onPageStarted!(landing);
        delegate.onPageFinished!(landing);
        await tester.pump();
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await delegate.onNavigationRequest!(const NavigationRequest(
            url: 'https://advertiser.example/later', isMainFrame: true));
        await tester.pump();
        expect(find.byTooltip('Close ad'), findsNothing);
        final elapsed = tester.binding.clock.now().difference(started);
        await tester.pump(closeFallback - elapsed);
        expect(find.byTooltip('Close ad'), findsOneWidget);
        expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets('late redirects keep close available after the fallback',
          (tester) async {
        final ad = await openAd(tester);
        final delegate = ad.page.delegate!;
        delegate.onPageStarted!(intermediate);
        delegate.onPageFinished!(intermediate);
        await tester.pump();
        await tester.pump(closeFallback);
        await delegate.onNavigationRequest!(
            NavigationRequest(url: landing, isMainFrame: true));
        delegate.onPageStarted!(landing);
        await tester.pump();
        expect(find.byTooltip('Close ad'), findsOneWidget);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets('a viewer following a link can still close the ad',
          (tester) async {
        final ad = await openAd(tester);
        final delegate = ad.page.delegate!;
        delegate.onPageStarted!(intermediate);
        delegate.onPageFinished!(intermediate);
        await tester.pump();
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await tester.tap(find.byKey(const ValueKey('fake-webview')),
            warnIfMissed: false);
        await delegate.onNavigationRequest!(
            NavigationRequest(url: landing, isMainFrame: true));
        delegate.onPageStarted!(landing);
        await tester.pump();
        expect(find.byTooltip('Close ad'), findsOneWidget);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets('errors from an earlier hop do not cancel the current page',
          (tester) async {
        final ad = await openAd(tester);
        final delegate = ad.page.delegate!;
        delegate.onPageStarted!(intermediate);
        delegate.onPageStarted!(landing);
        delegate.onWebResourceError!(const WebResourceError(
            errorCode: -1,
            description: 'Previous redirect cancelled',
            isForMainFrame: true,
            url: intermediate));
        await tester.pump();
        expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
        delegate.onPageFinished!(landing);
        await tester.pump();
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets('failed inspections cannot enable close as a served ad',
          (tester) async {
        final ad = await openAd(tester);
        ad.page.contentError = StateError('Document inspection unavailable');
        ad.page.delegate!.onPageStarted!(landing);
        ad.page.delegate!.onPageFinished!(landing);
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        expect(find.byTooltip('Close ad'), findsNothing);
        expect(find.text('Ad loading'), findsOneWidget);
        ad.page.contentError = null;
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets('a fragment change preserves the current landing countdown',
          (tester) async {
        final ad = await openAd(tester);
        ad.page.delegate!.onPageStarted!(landing);
        ad.page.delegate!.onPageFinished!(landing);
        await tester.pump(const Duration(seconds: 1));
        await ad.page.delegate!.onNavigationRequest!(
            NavigationRequest(url: '$landing#details', isMainFrame: true));
        await tester.pump(const Duration(seconds: 2));
        expect(find.byTooltip('Close ad'), findsOneWidget);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);

      testWidgets(
          'the final redirect can finish without its own start callback',
          (tester) async {
        final ad = await openAd(tester);
        ad.page.delegate!.onPageStarted!(intermediate);
        ad.page.currentPageUrl = landing;
        ad.page.contentReport = report(landing);
        ad.page.delegate!.onPageFinished!(landing);
        await tester.pump();
        expect(find.text('Sponsored · advertiser.example'), findsOneWidget);
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        await tester.tap(find.byTooltip('Close ad'));
        await tester.pumpAndSettle();
        expect(await ad.result, isTrue);
      }, variant: android);
    });
  }

  group('ExoClick popup', () {
    final exoclick = File('docs/exoclick_playback_ads.json').readAsStringSync();
    final redirect = Uri.parse(
        'https://s.pemsrv.com/v1/link.php?cat=&idzone=6050984&type=8');

    PopunderAdsConfig parseExoclick(String raw, {bool enabled = true}) =>
        PopunderAdsConfig.parse(raw,
            network: AdNetwork.exoclick, enabled: enabled);

    void selectExoclick() => provider
      ..setPopunderAdsConfig(parseExoclick(exoclick))
      ..setPlaybackPopunderNetwork(AdNetwork.exoclick);

    testWidgets('a direct link gets its full loading budget after cold setup',
        (tester) async {
      final setup = Completer<void>();
      platform.setupGate = setup;
      selectExoclick();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final page = platform.controllers.single;
      await tester.pump(const Duration(seconds: 11));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      expect(page.requests, isEmpty);
      setup.complete();
      await tester.pump();
      await tester.pump();
      expect(page.requests, [redirect]);
      await tester.pump(const Duration(seconds: 9));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      page.delegate!.onPageFinished!('https://advertiser.example/');
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    test('the catalog uses the generated redirect on mobile and TV', () {
      final config = parseExoclick(exoclick);
      for (final television in [false, true]) {
        final placement = config.activeFor(television: television)!;
        expect(placement.network, AdNetwork.exoclick);
        expect(placement.mode, 'smartlink');
        expect(placement.trackedSmartlinkUrl, redirect);
        expect(placement.playsWithoutTouch, isTrue);
      }
      expect(parseExoclick(exoclick, enabled: false).activePopunder, isNull);
      expect(parseExoclick('{').activePopunder, isNull);
      final decoded = jsonDecode(exoclick) as Map<String, dynamic>;
      for (final change in [
        {'enabled': false},
        {'url': 'http://s.pemsrv.com/v1/link.php?idzone=6050984&type=8'},
        {'url': ''},
        {'sub_id': 'adsterra_only'},
      ]) {
        expect(
            parseExoclick(jsonEncode({
              'popunder': {...decoded['popunder'] as Map, ...change}
            })).activePopunder,
            isNull);
      }
    });

    test('Remote Config requires the popup switch independently of VAST',
        () async {
      final remote = FakeFirebaseRemoteConfig();
      await AppRemoteConfig.configure(remote);
      expect(
          remote.defaults[AppRemoteConfig.exoclickPlaybackEnabledKey], false);
      expect(remote.defaults[AppRemoteConfig.exoclickPlaybackAdsKey], '{}');
      remote
        ..setMockString(AppRemoteConfig.exoclickPlaybackAdsKey, exoclick)
        ..setMockString(AppRemoteConfig.playbackPopunderNetworkKey, 'ExoClick')
        ..setMockBool(AppRemoteConfig.vastPrerollEnabledKey, true);
      // A local default cannot authorize network requests.
      remote.defaults[AppRemoteConfig.exoclickPlaybackEnabledKey] = true;
      AppRemoteConfig.apply(remote, provider);
      expect(provider.playbackPopunderNetwork, AdNetwork.exoclick);
      expect(
          provider.popunderAdsFor(AdNetwork.exoclick).activePopunder, isNull);
      remote.setMockBool(AppRemoteConfig.exoclickPlaybackEnabledKey, true);
      AppRemoteConfig.apply(remote, provider);
      expect(
          provider
              .popunderAdsFor(AdNetwork.exoclick)
              .activePopunder
              ?.trackedSmartlinkUrl,
          redirect);
      remote.setMockString(AppRemoteConfig.exoclickPlaybackAdsKey, '{}');
      AppRemoteConfig.apply(remote, provider);
      expect(
          provider.popunderAdsFor(AdNetwork.exoclick).activePopunder, isNull);
    });

    testWidgets('the rotating catalog opens the server redirect without a tag',
        (tester) async {
      final catalog =
          File('docs/exoclick_rotating_playback_ads.json').readAsStringSync();
      final config = parseExoclick(catalog);
      final relay = Uri.parse('https://flix.quest/api/exoclick-popup');
      for (final television in [false, true]) {
        expect(config.activeFor(television: television)!.trackedSmartlinkUrl,
            relay);
      }
      provider
        ..setPopunderAdsConfig(config)
        ..setPlaybackPopunderNetwork(AdNetwork.exoclick);
      await pumpHost(tester);
      expect(service.preloadStreamFound(host), isNull);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final page = platform.controllers.single;
      expect(page.requests, [relay]);
      expect(page.htmlLoads, isEmpty);
      expect(
          page.delegate!.onNavigationRequest!(NavigationRequest(
              url:
                  'https://s.delivery.example/v1/link.php?cat=&idzone=6050984&type=8',
              isMainFrame: true)),
          NavigationDecision.navigate);
      page.delegate!.onPageStarted!('https://offer.example/exoclick');
      page.delegate!.onPageFinished!('https://offer.example/exoclick');
      await tester.pump();
      expect(find.text('Sponsored · offer.example'), findsOneWidget);
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('ExoClick Yahoo no-fill redirects continue without an ad view',
        (tester) async {
      selectExoclick();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final page = platform.controllers.single;
      expect(
          page.delegate!.onNavigationRequest!(
              NavigationRequest(url: 'https://yahoo.com', isMainFrame: true)),
          NavigationDecision.prevent);
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
      expect(page.javaScriptMode, JavaScriptMode.disabled);
    }, variant: android);

    for (final television in [false, true]) {
      testWidgets(
          'loads only when presented on ${television ? 'TV' : 'mobile'}',
          (tester) async {
        selectExoclick();
        await pumpHost(tester);
        expect(
            service.preloadStreamFound(host, television: television), isNull);
        await tester.pump(const Duration(seconds: 12));
        expect(platform.controllers, isEmpty);
        expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);

        final result = service.streamFound(host, television: television);
        await pumpAd(tester);
        final page = platform.controllers.single;
        expect(platform.controllers, hasLength(1));
        expect(page.requests, [redirect]);
        expect(page.htmlLoads, isEmpty);
        page.delegate!.onPageStarted!('https://offer.example/exoclick');
        page.delegate!.onPageFinished!('https://offer.example/exoclick');
        await tester.pump();
        expect(find.text('Sponsored · offer.example'), findsOneWidget);
        expect(find.byTooltip('Close ad'), findsNothing);
        await tester.pump(AdsterraPlaybackAdScreen.minimumView);
        if (television) {
          expect(FocusManager.instance.primaryFocus?.debugLabel, 'ad continue');
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
        } else {
          await tester.tap(find.byTooltip('Close ad'));
        }
        await tester.pumpAndSettle();
        expect(await result, isTrue);
        expect(page.javaScriptMode, JavaScriptMode.disabled);
      }, variant: android);
    }

    testWidgets('requests the redirect directly and skips a stalled ad',
        (tester) async {
      selectExoclick();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final page = platform.controllers.single;
      expect(page.requests, [redirect]);
      expect(page.htmlLoads, isEmpty);
      expect(storeLaunches, isEmpty);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    }, variant: android);

    testWidgets('an existing preload is discarded and a fresh ad is requested',
        (tester) async {
      selectExoclick();
      await pumpHost(tester);
      // A loader from before a hot reload may still hold a preload.
      final preload = PlaybackAdPreload(
          placement:
              provider.popunderAdsFor(AdNetwork.exoclick).activePopunder!);
      await tester.pump();
      final oldPage = platform.controllers.single;
      final result = service.streamFound(host, preload: preload);
      await pumpAd(tester);
      expect(preload.unavailable, isTrue);
      expect(oldPage.javaScriptMode, JavaScriptMode.disabled);
      expect(platform.controllers, hasLength(2));
      expect(platform.controllers.last.requests, [redirect]);
      provider.setPlaybackPopunderNetwork(AdNetwork.adsterra);
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('disable cancels its ad and prevents new requests',
        (tester) async {
      selectExoclick();
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      provider.setPopunderAdsConfig(parseExoclick(exoclick, enabled: false));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
      final requests = platform.controllers.length;
      expect(service.preloadStreamFound(host), isNull);
      expect(await service.streamFound(host), isTrue);
      expect(platform.controllers, hasLength(requests));
    }, variant: android);

    testWidgets('downloads and before-loader never request its popup',
        (tester) async {
      selectExoclick();
      provider.setAdsterraPlaybackAdsConfig(const AdsterraPlaybackAdsConfig());
      await pumpHost(tester);
      expect(service.preloadStreamFound(host, download: true), isNull);
      expect(await service.streamFound(host, download: true), isTrue);
      expect(await service.beforeLoader(host), isTrue);
      expect(await service.beforeLoader(host, television: true), isTrue);
      expect(platform.controllers, isEmpty);
    }, variant: android);
  });

  group('Monetag popup', () {
    final hosted = File('docs/monetag_playback_ads.json').readAsStringSync();
    final monetag = jsonEncode({
      'popunder': {
        'enabled': true,
        'script_url': 'https://al5sm.com/tag.min.js',
        'zone_id': '11983408',
        'load_timeout_ms': 10000,
      }
    });

    PopunderAdsConfig parseMonetag(String raw, {bool enabled = true}) =>
        PopunderAdsConfig.parse(raw,
            network: AdNetwork.monetag, enabled: enabled);

    String popunder(Map<String, Object> fields) => jsonEncode({
          'popunder': {'enabled': true, ...fields}
        });

    testWidgets('every mode skips preloading on mobile and TV', (tester) async {
      await pumpHost(tester);
      for (final raw in [
        hosted,
        monetag,
        jsonEncode({
          'popunder': {
            'enabled': true,
            'mode': 'smartlink',
            'url': 'https://monetag.example/direct',
          },
          'tv_popunder': {
            'enabled': true,
            'mode': 'smartlink',
            'url': 'https://monetag.example/direct-tv',
          },
        }),
      ]) {
        provider
          ..setPopunderAdsConfig(parseMonetag(raw))
          ..setPlaybackPopunderNetwork(AdNetwork.monetag);
        for (final television in [false, true]) {
          expect(
              service.preloadStreamFound(host, television: television), isNull);
        }
      }
      await tester.pump(const Duration(seconds: 12));
      expect(platform.controllers, isEmpty);
    }, variant: android);

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

    test('the published catalog loads the page hosted on flix.quest', () {
      final page = parseMonetag(hosted).activePopunder!;
      expect(page.mode, 'page');
      expect(page.pageUrl, Uri.parse('https://flix.quest/a/3ad05c8e4d'));
      expect(page.scriptUrl, isNull);
      expect(page.loadTimeout, const Duration(seconds: 30));
      expect(page.maxDuration, const Duration(seconds: 60));
      expect(
          parseMonetag(popunder({'mode': 'page', 'url': 'http://flix.quest/a'}))
              .activePopunder,
          isNull);
    });

    test('Monetag permits longer loading while keeping bounded timeouts', () {
      final placement = parseMonetag(popunder({
        'mode': 'page',
        'url': 'https://flix.quest/a/3ad05c8e4d',
        'load_timeout_ms': 999999,
        'max_duration_seconds': 999999,
      })).activePopunder!;
      expect(placement.loadTimeout, const Duration(seconds: 30));
      expect(placement.maxDuration, const Duration(seconds: 120));
    });

    testWidgets('a hosted page starts its popup automatically in the ad page',
        (tester) async {
      provider
        ..setPopunderAdsConfig(parseMonetag(hosted))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      expect(opener.htmlLoads, isEmpty);
      expect(opener.requests, [Uri.parse('https://flix.quest/a/3ad05c8e4d')]);
      // Vercel's own redirect for the page still loads in place.
      expect(
          await opener.delegate!.onNavigationRequest!(NavigationRequest(
              url: 'https://flix.quest/a/3ad05c8e4d/', isMainFrame: true)),
          NavigationDecision.navigate);
      // A Chrome hand-off to the publisher is not the advertiser, even if
      // it arrives before the first document-finished callback.
      expect(
          await opener.delegate!.onNavigationRequest!(NavigationRequest(
              url: 'intent://flix.quest/a/3ad05c8e4d/?intnt_r=1'
                  '#Intent;scheme=https;package=com.android.chrome;end',
              isMainFrame: true)),
          NavigationDecision.prevent);
      await tester.pump();
      expect(platform.controllers, hasLength(1));
      expect(opener.javaScriptMode, JavaScriptMode.unrestricted);
      opener.delegate!.onPageFinished!('https://flix.quest/a/3ad05c8e4d');
      opener.send('{"event":"loaded"}');
      await tester.pump();
      expect(opener.evaluatedScripts, [monetagAutomaticPlaybackScript]);
      expect(find.text('Your video is ready'), findsOneWidget);
      // Duplicate finish callbacks must not install another trigger.
      opener.delegate!.onPageFinished!('https://flix.quest/a/3ad05c8e4d');
      await tester.pump(const Duration(seconds: 1));
      expect(opener.evaluatedScripts, hasLength(1));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      // After it loads, a navigation is the tag's ad, even on flix.quest.
      expect(
          await opener.delegate!.onNavigationRequest!(NavigationRequest(
              url: 'https://ads.example/offer', isMainFrame: true)),
          NavigationDecision.prevent);
      await tester.pump();
      await tester.pump();
      expect(platform.controllers.last.requests,
          [Uri.parse('https://ads.example/offer')]);
      platform.controllers.last.delegate!
          .onPageFinished!('https://ads.example/offer');
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('an empty automatic Monetag response continues playback',
        (tester) async {
      var taps = 0;
      service = AdsterraPlaybackAdsService(continueTap: (_, __) async {
        taps++;
        return true;
      });
      provider
        ..setPopunderAdsConfig(parseMonetag(hosted))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      opener.send('{"event":"loaded"}');
      opener.send('{"event":"empty"}');
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(platform.controllers, hasLength(1));
      expect(taps, 0);
      expect(opener.javaScriptMode, JavaScriptMode.disabled);
      expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
      opener.delegate!.onPageFinished!('https://flix.quest/a/3ad05c8e4d');
      await tester.pump();
      expect(opener.evaluatedScripts, [monetagAutomaticPlaybackScript]);
    }, variant: android);

    testWidgets('one native touch waits for a delayed advertiser URL',
        (tester) async {
      var taps = 0;
      service =
          AdsterraPlaybackAdsService(continueTap: (controller, document) async {
        taps++;
        expect(controller.platform, same(platform.controllers.single));
        expect(document, Uri.parse('https://flix.quest/a/3ad05c8e4d'));
        return true;
      });
      provider
        ..setPopunderAdsConfig(parseMonetag(hosted))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      opener.send('{"event":"loaded"}');
      opener.send('{"event":"activation_ready"}');
      opener.send('{"event":"activation_ready"}');
      await tester.pump();
      expect(taps, 1);
      expect(opener.evaluatedScripts, [monetagAutomaticPlaybackScript]);
      opener.send('{"event":"done"}');
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      expect(opener.javaScriptMode, JavaScriptMode.unrestricted);
      await opener.delegate!.onNavigationRequest!(NavigationRequest(
          url: 'https://ads.example/delayed', isMainFrame: true));
      await tester.pump();
      await tester.pump();
      final page = platform.controllers.last;
      expect(page.requests, [Uri.parse('https://ads.example/delayed')]);
      page.delegate!.onPageFinished!('https://ads.example/delayed');
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(taps, 1);
    }, variant: android);

    testWidgets('an unavailable native touch uses one tag-hook fallback',
        (tester) async {
      var taps = 0;
      service = AdsterraPlaybackAdsService(continueTap: (_, __) async {
        taps++;
        return false;
      });
      provider
        ..setPopunderAdsConfig(parseMonetag(hosted))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      opener.send('{"event":"loaded"}');
      opener.send('{"event":"activation_ready"}');
      await tester.pump();
      opener.send('{"event":"activation_ready"}');
      await tester.pump();
      expect(taps, 1);
      expect(opener.evaluatedScripts,
          [monetagAutomaticPlaybackScript, monetagTriggerPlaybackScript]);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('disabling an ad during native input prevents late activation',
        (tester) async {
      final input = Completer<bool>();
      service =
          AdsterraPlaybackAdsService(continueTap: (_, __) => input.future);
      provider
        ..setPopunderAdsConfig(parseMonetag(hosted))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      opener.send('{"event":"loaded"}');
      opener.send('{"event":"activation_ready"}');
      await tester.pump();
      provider.setPopunderAdsConfig(parseMonetag(hosted, enabled: false));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(opener.javaScriptMode, JavaScriptMode.disabled);
      input.complete(false);
      await tester.pump();
      expect(opener.evaluatedScripts, [monetagAutomaticPlaybackScript]);
      expect(platform.controllers, hasLength(1));
    }, variant: android);

    testWidgets('a loaded tag without an automatic popup times out',
        (tester) async {
      provider
        ..setPopunderAdsConfig(parseMonetag(hosted))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      await tester.pump(const Duration(seconds: 20));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      platform.controllers.single.send('{"event":"loaded"}');
      await tester.pump(const Duration(seconds: 29));
      expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    }, variant: android);

    test('the tag reads its zone from data-zone and arms on load', () {
      final html = playbackAdHtml(
          parseMonetag(monetag).popunder!, PlaybackAdStage.streamFound);
      expect(
          html,
          contains('<script defer data-cfasync="false" data-zone="11983408" '
              'src="https://al5sm.com/tag.min.js"'));
      expect(html, contains('onload="fqSignal(\'loaded\')"'));
      expect(html, isNot(contains('data-clocid')));
    });

    testWidgets('a Direct Link loads automatically without a Continue tap',
        (tester) async {
      final url = Uri.parse('https://monetag.example/4/123?source=flixquest');
      provider
        ..setPopunderAdsConfig(parseMonetag(popunder({
          'mode': 'smartlink',
          'url': url.toString(),
          'load_timeout_ms': 10000,
        })))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      expect(service.preloadStreamFound(host), isNull);
      await tester.pump(const Duration(seconds: 12));
      expect(platform.controllers, isEmpty);
      final result = service.streamFound(host);
      await pumpAd(tester);
      // No tag load signal or touch is needed to request the advertiser.
      final page = platform.controllers.single;
      expect(page.requests, [url]);
      expect(page.htmlLoads, isEmpty);
      expect(page.channel, isNull);
      expect(find.text('Your video is ready'), findsOneWidget);
      expect(find.byTooltip('Close ad'), findsNothing);
      // A browser intent in the automatic redirect chain stays in this view.
      expect(
          await page.delegate!.onNavigationRequest!(NavigationRequest(
              url: 'intent://advertiser.example/offer?source=flixquest'
                  '#Intent;scheme=https;package=com.android.chrome;end',
              isMainFrame: true)),
          NavigationDecision.prevent);
      await tester.pump();
      expect(platform.controllers, hasLength(1));
      expect(page.requests.last,
          Uri.parse('https://advertiser.example/offer?source=flixquest'));
      expect(storeLaunches, isEmpty);
      page.delegate!.onPageFinished!(page.requests.last.toString());
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

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
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('an automatic intent offer opens inside the ad page',
        (tester) async {
      provider
        ..setPopunderAdsConfig(parseMonetag(hosted))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      opener.send(jsonEncode({
        'event': 'offer',
        'url': 'intent://advertiser.example/offer?source=flixquest'
            '#Intent;scheme=https;package=com.android.chrome;end',
      }));
      await tester.pump();
      await tester.pump();
      final page = platform.controllers.last;
      expect(page.requests,
          [Uri.parse('https://advertiser.example/offer?source=flixquest')]);
      expect(opener.javaScriptMode, JavaScriptMode.disabled);
      expect(storeLaunches, isEmpty);
      page.delegate!.onPageFinished!(page.requests.single.toString());
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);

    testWidgets('its hand-off to Chrome opens in the ad page instead',
        (tester) async {
      provider
        ..setPopunderAdsConfig(parseMonetag(monetag))
        ..setPlaybackPopunderNetwork(AdNetwork.monetag);
      await pumpHost(tester);
      final result = service.streamFound(host);
      await pumpAd(tester);
      final opener = platform.controllers.single;
      expect(opener.htmlLoads.single, contains('PerformanceObserver'));
      // The same-page variant points back at the placeholder origin.
      await opener.delegate!.onNavigationRequest!(NavigationRequest(
          url: 'intent://appassets.androidplatform.net/adsterra/?x=1'
              '#Intent;scheme=https;package=com.android.chrome;end',
          isMainFrame: true));
      await tester.pump();
      expect(platform.controllers, hasLength(1));
      expect(
          await opener.delegate!.onNavigationRequest!(NavigationRequest(
              url: 'intent://monetag.example/r?z=1'
                  '#Intent;scheme=https;package=com.android.chrome;end',
              isMainFrame: true)),
          NavigationDecision.prevent);
      await tester.pump();
      await tester.pump();
      expect(platform.controllers.last.requests,
          [Uri.parse('https://monetag.example/r?z=1')]);
      platform.controllers.last.delegate!
          .onPageFinished!('https://monetag.example/r?z=1');
      await tester.pump();
      await tester.pump(AdsterraPlaybackAdScreen.minimumView);
      await tester.tap(find.byTooltip('Close ad'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: android);
  });
}
