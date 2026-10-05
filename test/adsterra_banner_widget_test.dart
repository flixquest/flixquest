import 'dart:convert';

import 'package:flixquest/models/adsterra_ads_config.dart';
import 'package:flixquest/models/banner_ad.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/device_presentation_service.dart';
import 'package:flixquest/widgets/hosted_ads_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/fake_adsterra_webview.dart';

void main() {
  late FakeAdsterraWebViewPlatform platform;
  late AppDependencyProvider provider;

  setUpAll(
      () => dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test'));
  setUp(() {
    platform = FakeAdsterraWebViewPlatform();
    WebViewPlatform.instance = platform;
    provider = AppDependencyProvider()
      ..setHostedBannerMode(HostedBannerMode.off)
      ..setAdsterraAdsConfig(testAdsterraConfig());
  });
  tearDown(() {
    DevicePresentationService.instance.isTelevision = false;
  });

  Future<void> pump(WidgetTester tester,
      {bool tall = false, double width = 800}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: ChangeNotifierProvider.value(
        value: provider,
        child: SizedBox(
            width: width,
            child: RemoteHostedAdsBanner(
              placement: 'downloads',
              padding: EdgeInsets.zero,
              variant: tall
                  ? HostedBannerVariant.tall
                  : HostedBannerVariant.standard,
            )),
      ),
    )));
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'a real controller gets the correct code and unscaled dimensions',
    (tester) async {
      await pump(tester, tall: true);
      final controller = platform.controllers.single;
      expect(controller.htmlLoads.single, contains('rectangle_key/invoke.js'));
      // A null/data origin throws when the ad script reads document.cookie.
      expect(controller.baseUrls.single,
          'https://appassets.androidplatform.net/adsterra/');
      expect(controller.htmlLoads.single,
          contains("window.addEventListener('error'"));
      expect(controller.javaScriptMode, JavaScriptMode.unrestricted);
      expect(tester.getSize(find.byType(WebViewWidget)), const Size(300, 250));
      expect(find.text('AD'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(controller.javaScriptMode, JavaScriptMode.disabled);
      expect(controller.requests.last, Uri.parse('about:blank'));
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'ordinary rebuilds reuse the view; changed codes replace it',
    (tester) async {
      await pump(tester);
      await pump(tester);
      expect(platform.controllers, hasLength(1));
      final first = platform.controllers.single;
      final json = jsonDecode(testAdsterraCatalog) as Map<String, dynamic>;
      json['defaults']['standard'] = ['rectangle'];
      provider.setAdsterraAdsConfig(
          AdsterraAdsConfig.parse(jsonEncode(json), enabled: true));
      await tester.pump();
      await tester.pump();
      expect(platform.controllers, hasLength(2));
      expect(first.requests, contains(Uri.parse('about:blank')));
      expect(tester.getSize(find.byType(WebViewWidget)), const Size(300, 250));
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'kill switches remove existing WebViews and disabled slots load none',
    (tester) async {
      await pump(tester);
      provider.setAdsterraAdsConfig(testAdsterraConfig(enabled: false));
      await tester.pump();
      await tester.pump();
      expect(find.byType(WebViewWidget), findsNothing);
      expect(
          platform.controllers.single.requests.last, Uri.parse('about:blank'));
      provider.setAdsterraAdsConfig(testAdsterraConfig());
      provider.setBannerAdNetwork('none');
      await tester.pump();
      expect(platform.controllers, hasLength(1));
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'a too narrow slot sends no ad request',
    (tester) async {
      await pump(tester, width: 290);
      expect(platform.controllers, isEmpty);
      expect(find.byType(WebViewWidget), findsNothing);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'script failure collapses the slot without interrupting its screen',
    (tester) async {
      await pump(tester);
      platform.controllers.single.send('failed');
      await tester.pump();
      expect(find.byType(WebViewWidget), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'a stalled script times out and does not reload',
    (tester) async {
      platform.signalLoaded = false;
      await pump(tester);
      await tester.pump(const Duration(seconds: 21));
      await tester.pump();
      expect(find.byType(WebViewWidget), findsNothing);
      expect(platform.controllers.single.htmlLoads, hasLength(1));
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'TV is display-only and cannot launch an offer',
    (tester) async {
      DevicePresentationService.instance.isTelevision = true;
      await pump(tester);
      final view = find.byType(WebViewWidget);
      expect(
          find.ancestor(
              of: view,
              matching: find.byWidgetPredicate(
                  (widget) => widget is IgnorePointer && widget.ignoring)),
          findsOneWidget);
      expect(find.ancestor(of: view, matching: find.byType(ExcludeFocus)),
          findsWidgets);
      final navigate =
          platform.controllers.single.delegate!.onNavigationRequest!;
      expect(
          await navigate(const NavigationRequest(
              url: 'https://offer.example', isMainFrame: true)),
          NavigationDecision.prevent);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'only a user interaction can open one external offer',
    (tester) async {
      final launcher = _FakeOfferLauncher();
      final original = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);
      await pump(tester);
      final navigate =
          platform.controllers.single.delegate!.onNavigationRequest!;
      const offer =
          NavigationRequest(url: 'https://offer.example', isMainFrame: true);
      await navigate(offer);
      expect(launcher.urls, isEmpty);
      await tester.tap(find.byKey(const ValueKey('fake-webview')));
      expect(await navigate(offer), NavigationDecision.prevent);
      await tester.pump();
      expect(launcher.urls, ['https://offer.example']);
      await navigate(offer);
      expect(launcher.urls, hasLength(1));
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'programmatic main-frame redirects and non-web schemes are blocked',
    (tester) async {
      await pump(tester);
      final navigate =
          platform.controllers.single.delegate!.onNavigationRequest!;
      for (final url in [
        'https://offer.example',
        'intent://offer',
        'file:///private'
      ]) {
        expect(await navigate(NavigationRequest(url: url, isMainFrame: true)),
            NavigationDecision.prevent);
      }
      expect(
          await navigate(const NavigationRequest(
              url: 'https://ads.example/creative', isMainFrame: false)),
          NavigationDecision.navigate);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}

class _FakeOfferLauncher extends UrlLauncherPlatform {
  final urls = <String>[];

  @override
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    return true;
  }
}
