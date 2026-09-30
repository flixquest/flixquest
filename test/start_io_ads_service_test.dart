import 'package:flixquest/services/start_io_ads_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InterstitialPacing', () {
    late DateTime now;
    late InterstitialPacing pacing;

    setUp(() {
      now = DateTime(2026, 9, 27, 20);
      pacing = InterstitialPacing(now: () => now);
    });

    test('the first play of a session may show an ad', () {
      expect(pacing.canShow(const Duration(minutes: 10)), isTrue);
    });

    test('a second play inside the interval shows none', () {
      pacing.recordShown();
      now = now.add(const Duration(minutes: 3));
      expect(pacing.canShow(const Duration(minutes: 10)), isFalse);

      now = now.add(const Duration(minutes: 7));
      expect(pacing.canShow(const Duration(minutes: 10)), isTrue);
    });
  });

  group('StartIoInterstitialMode.parse', () {
    test('reads automatic and falls back to video', () {
      expect(
        StartIoInterstitialMode.parse(' Automatic '),
        StartIoInterstitialMode.automatic,
      );
      expect(
        StartIoInterstitialMode.parse('video'),
        StartIoInterstitialMode.video,
      );
      expect(StartIoInterstitialMode.parse(''), StartIoInterstitialMode.video);
    });
  });

  test('StartIoAdsConfig compares by value', () {
    const config = StartIoAdsConfig();
    expect(config.bannerEnabled, isFalse);
    expect(config.interstitialEnabled, isFalse);
    expect(config.copyWith(), config);
    expect(
      config.copyWith(interstitialInterval: const Duration(minutes: 5)),
      isNot(config),
    );
  });

  test('TV placements carry their own tag', () {
    final ads = StartIoAdsService.instance;
    addTearDown(() => ads.setTelevision(false));
    expect(ads.tagFor('title_detail'), 'title_detail');
    ads.setTelevision(true);
    expect(ads.tagFor('title_detail'), 'title_detail_tv');
  });

  test('TV loads banners but never loads or shows interstitials', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final ads = StartIoAdsService.instance;
    final calls = <MethodCall>[];
    const channel = MethodChannel('com.startapp.flutter');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'loadBannerAd') {
        return <String, Object>{'id': 1, 'width': 320, 'height': 50};
      }
      return null;
    });
    addTearDown(() {
      ads.updateConfig(const StartIoAdsConfig());
      ads.setTelevision(false);
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    ads.setTelevision(true);
    // Even a remotely enabled interstitial must remain blocked on TV.
    ads.updateConfig(const StartIoAdsConfig(
      bannerEnabled: true,
      interstitialEnabled: true,
    ));
    await ads.preloadPlaybackInterstitial();
    await ads.showPlaybackInterstitial();
    final banner = await ads.loadBanner(
      placement: ads.tagFor('title_detail'),
      testMode: false,
    );

    expect(banner, isNotNull);
    expect(banner!.width, 320);
    final loads = calls.where((call) => call.method == 'loadBannerAd');
    expect(loads, hasLength(1));
    expect(loads.single.arguments['adTag'], 'title_detail_tv');
    expect(calls.where((call) => call.method == 'loadInterstitialAd'), isEmpty);
    expect(calls.where((call) => call.method == 'showInterstitialAd'), isEmpty);
    banner.dispose();
  });
}
