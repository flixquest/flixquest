import 'dart:io';

import 'package:flixquest/catalog/catalog_controller.dart';
import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/data/ads/ads_policy.dart';
import 'package:flixquest/data/ads/content_ads.dart';
import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/models/banner_ad.dart';
import 'package:flixquest/models/genres.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/tv.dart';
import 'package:flixquest/models/vast_preroll_config.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/player/player_preroll_ad.dart';
import 'package:flixquest/services/ad_block_check_cache.dart';
import 'package:flixquest/services/ad_block_detector.dart';
import 'package:flixquest/services/adsterra_playback_ads_service.dart';
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

/// Kids and Family titles show no ads, Plus or not: no request, no WebView,
/// no ad-blocker check and nothing owed, on their own screens only.
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
    AdsPolicy.update(adFree: false);
  });

  tearDown(ContentAds.reset);

  Future<void> pumpHost(WidgetTester tester,
          {Widget? child, bool adFree = true}) =>
      tester.pumpWidget(ChangeNotifierProvider<AppDependencyProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: ContentAdScope(
              adFree: adFree,
              child: Builder(builder: (context) {
                host = context;
                return child ?? const Text('Title details');
              }),
            ),
          ),
        ),
      ));

  final android = const TargetPlatformVariant({TargetPlatform.android});

  group('which titles', () {
    test('Family movies and series, and Kids series', () {
      bool movie(List<int> ids) =>
          FamilyGenres.includes(series: false, genreIds: ids);
      bool series(List<int> ids) =>
          FamilyGenres.includes(series: true, genreIds: ids);

      expect(movie([10751]), isTrue);
      expect(series([10751]), isTrue);
      expect(series([10762]), isTrue);
      // One qualifying genre among others is enough.
      expect(movie([28, 10751, 35]), isTrue);
      expect(series([18, 10762]), isTrue);
      // Animation alone is not; TMDB's movies have no Kids genre.
      expect(movie([16]), isFalse);
      expect(series([16]), isFalse);
      expect(movie([10762]), isFalse);
      expect(movie([]), isFalse);
    });

    test('a title without genre ids is not decided by them', () {
      expect(const AdContent(series: false, id: 1).knownAdFree, isNull);
      expect(const AdContent(series: false, id: 1, genreIds: []).knownAdFree,
          isNull);
      expect(
          AdContent.of(MediaItem.fromSeries(
              TV(id: 2, name: 'Bluey', genreIds: [16, 10762]))).knownAdFree,
          isTrue);
      expect(
          AdContent.of(MediaItem.fromMovie(
              Movie(id: 3, title: 'Heat', genreIds: [28, 80]))).knownAdFree,
          isFalse);
    });

    test('a movie and a series sharing an id are told apart', () async {
      final asked = <bool>[];
      ContentAds.lookup = (_, content) async {
        asked.add(content.series);
        return content.series ? [10762] : [28];
      };
      final context = _FakeContext();
      expect(
          await ContentAds.resolve(
              context, const AdContent(series: true, id: 9)),
          isTrue);
      expect(
          await ContentAds.resolve(
              context, const AdContent(series: false, id: 9)),
          isFalse);
      // Remembered: neither is asked about again.
      expect(ContentAds.known(const AdContent(series: true, id: 9)), isTrue);
      expect(ContentAds.known(const AdContent(series: false, id: 9)), isFalse);
      await ContentAds.resolve(context, const AdContent(series: true, id: 9));
      expect(asked, [true, false]);
    });

    test('genres that cannot be read mean no ads now, and a later retry',
        () async {
      var lookups = 0;
      ContentAds.lookup = (_, __) async {
        lookups++;
        throw Exception('offline');
      };
      const content = AdContent(series: false, id: 4);
      expect(await ContentAds.resolve(_FakeContext(), content), isTrue);
      expect(ContentAds.known(content), isNull);
      await ContentAds.resolve(_FakeContext(), content);
      expect(lookups, 2);
    });

    test('Kids and Family genre pages are ad-free, Animation is not', () {
      final settings = SettingsProvider();
      MediaCollection genre(MediaKind kind, int id) =>
          const CatalogController().genreCollection(
            kind: kind,
            genre: Genres(genreID: id, genreName: '$id'),
            settings: settings,
            dependencies: provider,
          );
      expect(genre(MediaKind.movie, 10751).adFree, isTrue);
      expect(genre(MediaKind.series, 10751).adFree, isTrue);
      expect(genre(MediaKind.series, 10762).adFree, isTrue);
      expect(genre(MediaKind.movie, 16).adFree, isFalse);
      expect(genre(MediaKind.series, 16).adFree, isFalse);
    });
  });

  testWidgets('the exemption is the screen\'s, never Plus\'s', (tester) async {
    await pumpHost(tester);
    expect(AdsPolicy.adFreeAt(host), isTrue);
    expect(AdsPolicy.adFree, isFalse);

    await pumpHost(tester, adFree: false);
    expect(AdsPolicy.adFreeAt(host), isFalse);
  });

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

  testWidgets('a Family title skips the before-loader ad from any screen',
      (tester) async {
    final service = AdsterraPlaybackAdsService();
    await pumpHost(tester, adFree: false);
    const family = AdContent(series: false, id: 5, genreIds: [10751]);

    expect(service.needsBeforeLoader(host, content: family), isFalse);
    expect(await service.beforeLoader(host, content: family), isTrue);
    await tester.pump();

    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
    expect(platform.controllers, isEmpty);
  }, variant: android);

  testWidgets('other titles keep their popup', (tester) async {
    final service = AdsterraPlaybackAdsService();
    await pumpHost(tester, adFree: false);
    final result = service.streamFound(host);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(AdsterraPlaybackAdScreen), findsOneWidget);

    Navigator.of(host).pop();
    await tester.pumpAndSettle();
    await result;
  }, variant: android);

  testWidgets('nothing owed is earned, and an older one waits for later',
      (tester) async {
    final owedAt = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(
        {'playback_ads.player_exit_owed_at': owedAt});
    final service = AdsterraPlaybackAdsService();
    await pumpHost(tester);

    service.notePlayerWatch(host, const Duration(hours: 2));
    await service.showOwedPlayerExitOnLaunch(host);
    await service.playerExit(host, watched: const Duration(hours: 2));
    await tester.pump();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('playback_ads.player_exit_owed_at'), owedAt);
    expect(find.byType(AdsterraPlaybackAdScreen), findsNothing);
  }, variant: android);

  testWidgets('no ad-blocker check runs and nobody is asked to turn one off',
      (tester) async {
    var lookups = 0;
    final gate = AdBlockGate(
      cache: AdBlockCheckCache(),
      additionalChecks: [
        (_, __) async {
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

  testWidgets('a held page shows its banner once the title proves ordinary',
      (tester) async {
    ContentAds.lookup = (_, __) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const [28];
    };
    await tester.pumpWidget(ChangeNotifierProvider<AppDependencyProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: ContentAdGate(
            content: const AdContent(series: false, id: 6),
            child: Builder(builder: (context) {
              host = context;
              return const BannerAdSlot(placement: 'title_detail');
            }),
          ),
        ),
      ),
    ));
    expect(AdsPolicy.adFreeAt(host), isTrue);
    expect(find.byType(NetworkBannerWidget), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(AdsPolicy.adFreeAt(host), isFalse);
  }, variant: android);

  testWidgets('a loader waits for the answer before it asks for anything',
      (tester) async {
    ContentAds.lookup = (_, __) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const [10751];
    };
    await tester.pumpWidget(MaterialApp(
      home: ContentAdGate(
        content: const AdContent(series: false, id: 7),
        holdChild: true,
        child: Builder(builder: (context) {
          host = context;
          return const Text('Loader');
        }),
      ),
    ));
    expect(find.text('Loader'), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.text('Loader'), findsOneWidget);
    expect(AdsPolicy.adFreeAt(host), isTrue);
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

    expect(await preroll.load(config, adFreeContent: true), isNull);
    expect(requests, isEmpty);
    preroll.dispose();
  });
}

/// Enough of a context for [ContentAds.resolve] with a replaced lookup.
class _FakeContext extends Fake implements BuildContext {}
