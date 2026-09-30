import 'dart:async';

import 'package:flixquest/models/banner_ad.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/hosted_ads_repository.dart';
import 'package:flixquest/services/start_io_ads_service.dart';
import 'package:flixquest/widgets/hosted_ads_banner.dart';
import 'package:flixquest/widgets/start_io_banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

BannerAd _ad({List<String> placements = const <String>[]}) => BannerAd(
      key: 'announcement',
      id: '1',
      name: 'Announcement',
      imageUrl: 'https://example.test/ad.png',
      targetUrl: 'https://example.test/join',
      altText: 'Join our channel',
      placements: placements,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(
      fileInput: '''
TMDB_API_KEY=test_tmdb_key
FLIXQUEST_API_URL=https://test.flixquest.api/
''',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.startapp.flutter'),
      (MethodCall call) async => null,
    );
  });

  group('BannerAd.appliesTo', () {
    test('an ad with no placements applies everywhere on a phone', () {
      expect(_ad().appliesTo('home_all_top'), isTrue);
    });

    test('a phone ad matches only the placements it lists', () {
      final ad = _ad(placements: const <String>['downloads']);
      expect(ad.appliesTo('downloads'), isTrue);
      expect(ad.appliesTo('bookmarks'), isFalse);
    });

    test('TV needs the explicit _tv placement', () {
      expect(_ad().appliesTo('title_detail', television: true), isFalse);
      expect(
        _ad(placements: const <String>['title_detail'])
            .appliesTo('title_detail', television: true),
        isFalse,
      );
      expect(
        _ad(placements: const <String>['title_detail_tv'])
            .appliesTo('title_detail', television: true),
        isTrue,
      );
    });
  });

  test('HostedBannerMode.parse falls back to stack', () {
    expect(HostedBannerMode.parse('OFF'), HostedBannerMode.off);
    expect(HostedBannerMode.parse(' priority '), HostedBannerMode.priority);
    expect(HostedBannerMode.parse('stack'), HostedBannerMode.stack);
    expect(HostedBannerMode.parse('nonsense'), HostedBannerMode.stack);
    expect(HostedBannerMode.parse(''), HostedBannerMode.stack);
  });

  group('HostedAdsRepository', () {
    tearDown(() => HostedAdsRepository.instance.useFetcherForTesting(
          (_) async => const <BannerAd>[],
        ));

    test('slots on one screen share a single request', () async {
      var requests = 0;
      HostedAdsRepository.instance.useFetcherForTesting((_) async {
        requests++;
        return <BannerAd>[_ad()];
      });

      final results = await Future.wait(<Future<List<BannerAd>>>[
        HostedAdsRepository.instance.load('https://api.test'),
        HostedAdsRepository.instance.load('https://api.test'),
        HostedAdsRepository.instance.load('https://api.test'),
      ]);

      expect(requests, 1);
      expect(results.every((ads) => ads.length == 1), isTrue);
    });

    test('a failed fetch reads as no ads instead of throwing', () async {
      HostedAdsRepository.instance.useFetcherForTesting(
        (_) async => throw StateError('offline'),
      );

      expect(
        await HostedAdsRepository.instance.load('https://api.test'),
        isEmpty,
      );
    });
  });

  group('RemoteHostedAdsBanner coexistence', () {
    late AppDependencyProvider provider;

    setUp(() {
      provider = AppDependencyProvider();
      provider.setStartIoAdsConfig(
        bannerEnabled: true,
        interstitialEnabled: false,
      );
    });

    tearDown(() => StartIoAdsService.instance.setTelevision(false));

    Future<void> pumpSlot(
      WidgetTester tester, {
      required List<BannerAd> ads,
      String placement = 'downloads',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppDependencyProvider>.value(
            value: provider,
            child: Scaffold(
              body: SingleChildScrollView(
                child: RemoteHostedAdsBanner(
                  placement: placement,
                  loadAds: () async => ads,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('stack shows the announcement and the Start.io banner',
        (tester) async {
      await pumpSlot(tester, ads: <BannerAd>[_ad()]);

      expect(find.byType(HostedAdsBanner), findsOneWidget);
      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('an ad aimed at another placement leaves Start.io alone',
        (tester) async {
      await pumpSlot(
        tester,
        ads: <BannerAd>[
          _ad(placements: const <String>['bookmarks']),
        ],
      );

      expect(find.byType(HostedAdsBanner), findsNothing);
      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('priority hands a slot with a hosted ad to the hosted ad',
        (tester) async {
      provider.setHostedBannerMode(HostedBannerMode.priority);
      await pumpSlot(tester, ads: <BannerAd>[_ad()]);

      expect(find.byType(HostedAdsBanner), findsOneWidget);
      expect(find.byType(StartIoBannerWidget), findsNothing);
    });

    testWidgets('priority keeps Start.io where there is no hosted ad',
        (tester) async {
      provider.setHostedBannerMode(HostedBannerMode.priority);
      await pumpSlot(tester, ads: const <BannerAd>[]);

      expect(find.byType(HostedAdsBanner), findsNothing);
      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('priority does not load Start.io before /ads answers',
        (tester) async {
      provider.setHostedBannerMode(HostedBannerMode.priority);
      final pending = Completer<List<BannerAd>>();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppDependencyProvider>.value(
            value: provider,
            child: Scaffold(
              body: RemoteHostedAdsBanner(
                placement: 'downloads',
                loadAds: () => pending.future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StartIoBannerWidget), findsNothing);

      pending.complete(const <BannerAd>[]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('off leaves only Start.io', (tester) async {
      provider.setHostedBannerMode(HostedBannerMode.off);
      await pumpSlot(tester, ads: <BannerAd>[_ad()]);

      expect(find.byType(HostedAdsBanner), findsNothing);
      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('hosted still shows when Start.io is switched off',
        (tester) async {
      provider.setStartIoAdsConfig(
        bannerEnabled: false,
        interstitialEnabled: false,
      );
      await pumpSlot(tester, ads: <BannerAd>[_ad()]);

      expect(find.byType(HostedAdsBanner), findsOneWidget);
      expect(find.byType(StartIoBannerWidget), findsNothing);
    });

    testWidgets('banner_ad_network none hides both', (tester) async {
      provider.setBannerAdNetwork('none');
      await pumpSlot(tester, ads: <BannerAd>[_ad()]);

      expect(find.byType(HostedAdsBanner), findsNothing);
      expect(find.byType(StartIoBannerWidget), findsNothing);
    });

    testWidgets('the per-ad banners config can still disable an ad',
        (tester) async {
      provider.setBannerConfigs(const <String, BannerDisplayConfig>{
        'announcement':
            BannerDisplayConfig(key: 'announcement', enabled: false),
      });
      await pumpSlot(tester, ads: <BannerAd>[_ad()]);

      expect(find.byType(HostedAdsBanner), findsNothing);
    });

    testWidgets('TV stacks a display-only announcement and Start.io banner',
        (tester) async {
      StartIoAdsService.instance.setTelevision(true);
      await pumpSlot(
        tester,
        placement: 'title_detail',
        ads: <BannerAd>[
          _ad(placements: const <String>['title_detail_tv']),
        ],
      );

      final banner = tester.widget<HostedAdsBanner>(
        find.byType(HostedAdsBanner),
      );
      expect(banner.interactive, isFalse);
      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('TV keeps Start.io when hosted banners are off', (tester) async {
      StartIoAdsService.instance.setTelevision(true);
      provider.setHostedBannerMode(HostedBannerMode.off);
      await pumpSlot(tester, placement: 'title_detail', ads: <BannerAd>[_ad()]);

      expect(find.byType(HostedAdsBanner), findsNothing);
      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('TV ignores an ad that is not aimed at it', (tester) async {
      StartIoAdsService.instance.setTelevision(true);
      await pumpSlot(
        tester,
        placement: 'title_detail',
        ads: <BannerAd>[_ad()],
      );

      expect(find.byType(HostedAdsBanner), findsNothing);
      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });
  });
}
