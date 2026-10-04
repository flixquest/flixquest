import 'package:visibility_detector/visibility_detector.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flixquest/models/banner_ad.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/widgets/hosted_ads_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() => dotenv.testLoad(
      fileInput: 'TMDB_API_KEY=test\nFLIXQUEST_API_URL=https://scraper.test'));
  testWidgets('a handheld tap reports its campaign while TV stays display-only',
      (tester) async {
    final clicks = <String>[];
    final launches = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
      launches.add(call);
      return true;
    });
    final provider = AppDependencyProvider();
    const ad = BannerAd(
        key: 'test',
        id: '42',
        name: 'Campaign',
        imageUrl: 'https://example.test/banner.png',
        targetUrl: 'https://example.test/join',
        altText: 'Campaign banner');
    preloadImage();
    Future<void> show(bool interactive) => tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider.value(
            value: provider,
            child: Scaffold(
                body: HostedAdsBanner(
                    ads: const [ad],
                    interactive: interactive,
                    onClick: (id) async {
                      clicks.add(id);
                    })))));
    await show(true);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(HostedAdsBanner));
    await tester.pump();
    expect(clicks, ['42']);
    expect(launches, hasLength(1));
    await show(false);
    await tester.pump();
    await tester.tap(find.byType(HostedAdsBanner), warnIfMissed: false);
    await tester.pump();
    expect(clicks, ['42']);
    expect(launches, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  testWidgets('carousel impressions belong to each loaded ad once per mount',
      (tester) async {
    final detector = VisibilityDetectorController.instance;
    final interval = detector.updateInterval;
    detector.updateInterval = Duration.zero;
    addTearDown(() => detector.updateInterval = interval);
    preloadImage();
    final provider = AppDependencyProvider();
    final impressions = <String>[];
    const ads = [
      BannerAd(
          key: 'first',
          id: '42',
          name: 'First',
          imageUrl: 'https://example.test/banner.png',
          targetUrl: 'https://example.test/first',
          altText: 'First'),
      BannerAd(
          key: 'second',
          id: '43',
          name: 'Second',
          imageUrl: 'https://example.test/banner.png',
          targetUrl: 'https://example.test/second',
          altText: 'Second'),
    ];
    Future<void> show() => tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider.value(
            value: provider,
            child: Scaffold(
                body: HostedAdsBanner(
                    ads: ads,
                    onImpression: (id) async {
                      impressions.add(id);
                    })))));
    await show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(impressions, ['42']);
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(impressions, ['42', '43']);
    await tester.drag(find.byType(PageView), const Offset(700, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(impressions, ['42', '43']);
    await tester.pumpWidget(const SizedBox());
    await show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(impressions, ['42', '43', '42']);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}

void preloadImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 100, 50),
      ui.Paint()..color = const Color(0xffffffff));
  final picture = recorder.endRecording();
  final image = picture.toImageSync(100, 50);
  picture.dispose();
  PaintingBinding.instance.imageCache.putIfAbsent(
      const CachedNetworkImageProvider('https://example.test/banner.png'),
      () => OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: image))));
}
