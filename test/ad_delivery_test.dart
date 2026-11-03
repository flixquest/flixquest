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

  test('filters, unreachable hosts and everything else are told apart', () {
    final expected = {
      'ERR_BLOCKED_BY_CLIENT': AdDelivery.blocked,
      'ERR_CERT_COMMON_NAME_INVALID': AdDelivery.blocked,
      'ERR_SSL_PROTOCOL_ERROR': AdDelivery.blocked,
      'ERR_NAME_NOT_RESOLVED': AdDelivery.unreachable,
      'ERR_CONNECTION_REFUSED': AdDelivery.unreachable,
      'ERR_CONNECTION_RESET': AdDelivery.unreachable,
      'ERR_ADDRESS_INVALID': AdDelivery.unreachable,
      'ERR_TIMED_OUT': null,
      'ERR_INTERNET_DISCONNECTED': null,
      'ERR_CERT_AUTHORITY_INVALID': null,
      'ERR_FAILED': null,
      'ERR_HTTP_RESPONSE_CODE_FAILURE': null,
    };
    for (final MapEntry(key: code, value: delivery) in expected.entries) {
      expect(deliveryForLoadError('net::$code'), delivery, reason: code);
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

  testWidgets('an unreachable delivery host is reported for that host',
      (tester) async {
    final page = await openPopup(tester, exoclick);
    await redirectToNetwork(page);
    page.onWebResourceError!(const WebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        isForMainFrame: true,
        url: rotating));
    await tester.pump();
    expect(outcomes, [('s.rotating.example', AdDelivery.unreachable)]);
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

  testWidgets('a blocker stopping a later hop is named by that hop',
      (tester) async {
    // An Adsterra Smartlink: its first host answers, a later hop does not.
    final page = await openPopup(
        tester,
        PlaybackAdPlacement(
            smartlinkUrl: Uri.parse('https://flix.quest/api/adsterra-popup'),
            loadTimeout: const Duration(seconds: 10)));
    for (final hop in [
      'https://smart.example/4/abc',
      'https://track.example/r?c=1',
    ]) {
      await page
          .onNavigationRequest!(NavigationRequest(url: hop, isMainFrame: true));
    }
    expect(outcomes, isEmpty, reason: 'moving on is not the ad showing');
    page.onWebResourceError!(const WebResourceError(
        errorCode: -6,
        description: 'net::ERR_CONNECTION_REFUSED',
        isForMainFrame: true,
        url: 'https://track.example/r?c=1'));
    await tester.pump();
    expect(outcomes, [('track.example', AdDelivery.unreachable)]);
  }, variant: android);

  testWidgets('a page that moves on, such as a bot check, is not the ad',
      (tester) async {
    final page = await openPopup(tester, exoclick);
    await redirectToNetwork(page);
    page.onPageStarted!('https://start.check.example/');
    page.onPageFinished!('https://start.check.example/');
    await tester.pump();
    expect(outcomes, isEmpty, reason: 'the chain has not ended');
    await page.onNavigationRequest!(const NavigationRequest(
        url: 'https://next.example/', isMainFrame: true));
    page.onWebResourceError!(const WebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        isForMainFrame: true,
        url: 'https://next.example/'));
    await tester.pump();
    expect(outcomes, [('next.example', AdDelivery.unreachable)]);
  }, variant: android);

  testWidgets('a popup that ends on its ad reached the network',
      (tester) async {
    final page = await openPopup(tester, exoclick);
    await redirectToNetwork(page);
    page.onPageStarted!('https://offer.example/ad');
    page.onPageFinished!('https://offer.example/ad');
    await tester.pump();
    expect(outcomes, isEmpty);
    await tester.pumpWidget(const SizedBox());
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

  testWidgets('a tag page judges only its tag\'s host', (tester) async {
    final tag = await openPopup(
        tester,
        PlaybackAdPlacement(
            scriptUrl: Uri.parse('https://tags.example/14/abc'),
            loadTimeout: const Duration(seconds: 10)));
    // A loaded tag is not an ad yet, and its other requests may fail.
    platform.controllers.last.send('{"event":"script"}');
    tag.onWebResourceError!(const WebResourceError(
        errorCode: -11,
        description: 'net::ERR_BLOCKED_BY_CLIENT',
        isForMainFrame: false,
        url: 'https://pixel.example/p.gif'));
    await tester.pump();
    expect(outcomes, isEmpty);
    tag.onWebResourceError!(const WebResourceError(
        errorCode: -11,
        description: 'net::ERR_BLOCKED_BY_CLIENT',
        isForMainFrame: false,
        url: 'https://tags.example/14/abc'));
    await tester.pump();
    expect(outcomes, [('tags.example', AdDelivery.blocked)]);
  }, variant: android);
}
