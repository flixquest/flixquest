import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/services/ad_delivery.dart';
import 'package:flixquest/widgets/adsterra_playback_ad_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/fake_adsterra_webview.dart';

void main() {
  late FakeAdsterraWebViewPlatform platform;
  late List<(String, AdDelivery)> outcomes;
  final android = const TargetPlatformVariant({TargetPlatform.android});
  const rotating = 'https://s.rotating.example/v1/link.php?idzone=1';

  setUp(() {
    platform = FakeAdsterraWebViewPlatform()..signalLoaded = false;
    WebViewPlatform.instance = platform;
    outcomes = [];
  });

  test('only the errors blockers cause count as blocked', () {
    for (final code in [
      'ERR_NAME_NOT_RESOLVED',
      'ERR_CONNECTION_REFUSED',
      'ERR_CONNECTION_RESET',
      'ERR_ADDRESS_INVALID',
      'ERR_BLOCKED_BY_CLIENT',
      'ERR_CERT_COMMON_NAME_INVALID',
      'ERR_SSL_PROTOCOL_ERROR',
    ]) {
      expect(isBlockingLoadError('net::$code'), isTrue, reason: code);
    }
    for (final code in [
      'ERR_TIMED_OUT',
      'ERR_INTERNET_DISCONNECTED',
      'ERR_CERT_AUTHORITY_INVALID',
      'ERR_FAILED',
      'ERR_HTTP_RESPONSE_CODE_FAILURE',
    ]) {
      expect(isBlockingLoadError('net::$code'), isFalse, reason: code);
    }
  });

  Future<FakeAdsterraNavigationDelegate> openPopup(
      WidgetTester tester, PlaybackAdPlacement placement) async {
    await tester.pumpWidget(MaterialApp(
      home: AdsterraPlaybackAdScreen(
        placement: placement,
        stage: PlaybackAdStage.streamFound,
        onDelivery: (host, delivery) => outcomes.add((host, delivery)),
      ),
    ));
    for (final wait in [
      Duration.zero,
      Duration.zero,
      Duration(milliseconds: 350)
    ]) {
      await tester.pump(wait);
    }
    return platform.controllers.last.delegate!;
  }

  // ExoClick's direct link through FlixQuest's redirector.
  final exoclick = PlaybackAdPlacement(
      smartlinkUrl: Uri.parse('https://flix.quest/api/exoclick-popup'),
      network: AdNetwork.exoclick,
      loadTimeout: const Duration(seconds: 10));

  Future<void> redirectToNetwork(FakeAdsterraNavigationDelegate page) async {
    await page.onNavigationRequest!(
        const NavigationRequest(url: rotating, isMainFrame: true));
  }

  testWidgets('a blocked delivery host is reported for that host',
      (tester) async {
    final page = await openPopup(tester, exoclick);
    await redirectToNetwork(page);
    page.onWebResourceError!(const WebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        isForMainFrame: true,
        url: rotating));
    await tester.pump();
    expect(outcomes, [('s.rotating.example', AdDelivery.blocked)]);
  }, variant: android);

  testWidgets('a network with no ad still answered', (tester) async {
    final page = await openPopup(tester, exoclick);
    await redirectToNetwork(page);
    page.onHttpError!(HttpResponseError(
        request: WebResourceRequest(uri: Uri.parse(rotating)),
        response:
            WebResourceResponse(uri: Uri.parse(rotating), statusCode: 404)));
    await tester.pump();
    expect(outcomes, [('s.rotating.example', AdDelivery.reached)]);
  }, variant: android);

  testWidgets('a redirect on to the advertiser means the network answered',
      (tester) async {
    final page = await openPopup(tester, exoclick);
    await redirectToNetwork(page);
    await page.onNavigationRequest!(const NavigationRequest(
        url: 'https://advertiser.example/offer', isMainFrame: true));
    // An advertiser blocked later is not the network being blocked.
    page.onWebResourceError!(const WebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        isForMainFrame: true,
        url: 'https://advertiser.example/offer'));
    await tester.pump();
    expect(outcomes, [('s.rotating.example', AdDelivery.reached)]);
  }, variant: android);

  testWidgets('timeouts and FlixQuest failures report nothing', (tester) async {
    final page = await openPopup(tester, exoclick);
    page.onWebResourceError!(const WebResourceError(
        errorCode: -6,
        description: 'net::ERR_CONNECTION_REFUSED',
        isForMainFrame: true,
        url: 'https://flix.quest/api/exoclick-popup'));
    await redirectToNetwork(page);
    page.onWebResourceError!(const WebResourceError(
        errorCode: -8,
        description: 'net::ERR_TIMED_OUT',
        isForMainFrame: true,
        url: rotating));
    page.onPageFinished!(rotating);
    await tester.pump();
    expect(outcomes, isEmpty);
  }, variant: android);

  testWidgets('a direct Adsterra Smartlink reports its own host',
      (tester) async {
    final page = await openPopup(
        tester,
        PlaybackAdPlacement(
            smartlinkUrl: Uri.parse('https://smart.example/4/abc'),
            loadTimeout: const Duration(seconds: 10)));
    page.onWebResourceError!(const WebResourceError(
        errorCode: -11,
        description: 'net::ERR_BLOCKED_BY_CLIENT',
        isForMainFrame: true,
        url: 'https://smart.example/4/abc?psid=x'));
    await tester.pump();
    expect(outcomes, [('smart.example', AdDelivery.blocked)]);
  }, variant: android);

  testWidgets('a tag script that loads means its network answered',
      (tester) async {
    await openPopup(
        tester,
        PlaybackAdPlacement(
            scriptUrl: Uri.parse('https://tags.example/14/abc'),
            loadTimeout: const Duration(seconds: 10)));
    platform.controllers.last.send('{"event":"script"}');
    await tester.pump();
    expect(outcomes, [('tags.example', AdDelivery.reached)]);
  }, variant: android);
}
