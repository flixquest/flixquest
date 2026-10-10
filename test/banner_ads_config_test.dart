import 'dart:convert';

import 'package:flixquest/models/banner_ads_config.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/app_remote_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_adsterra_webview.dart';
import 'support/fake_remote_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  test('default and malformed configs make no placement eligible', () {
    for (final raw in ['', '{', '[]', '{"units":null}']) {
      for (final network in AdNetwork.values) {
        expect(
            BannerAdsConfig.parse(raw, network: network, enabled: true)
                .resolve('downloads'),
            isNull);
      }
    }
    expect(testAdsterraConfig(enabled: false).resolve('downloads'), isNull);
  });

  test('variant defaults preserve thin and rectangle sizes', () {
    final config = testAdsterraConfig();
    expect(config.resolve('downloads')?.size, const BannerSize(320, 50));
    expect(config.resolve('stream_loading', tall: true)?.size,
        const BannerSize(300, 250));
  });

  test('placement overrides and ordered width fallbacks select matching codes',
      () {
    final json = jsonDecode(testAdsterraCatalog) as Map<String, dynamic>;
    json['placements'] = {
      'downloads': {
        'units': ['wide', 'mobile']
      },
      'bookmarks': {'enabled': false},
      'movie_detail': {
        'units': ['rectangle']
      },
      'bad_mapping': {
        'units': ['missing']
      },
    };
    final config = BannerAdsConfig.parse(jsonEncode(json),
        network: AdNetwork.adsterra, enabled: true);
    expect(config.resolve('downloads', maxWidth: 800)?.code, 'wide_key');
    expect(config.resolve('downloads', maxWidth: 360)?.code, 'mobile_key');
    expect(config.resolve('downloads', maxWidth: 290), isNull);
    expect(config.resolve('bookmarks'), isNull);
    expect(config.resolve('movie_detail')?.code, 'rectangle_key');
    expect(config.resolve('bad_mapping'), isNull);
    expect(config.resolve('movie_detail', maxHeight: 100), isNull);
  });

  test('TV has its own gate and never borrows mobile placement rules', () {
    expect(
        testAdsterraConfig(tvEnabled: false)
            .resolve('title_detail', television: true),
        isNull);
    final json = jsonDecode(testAdsterraCatalog) as Map<String, dynamic>;
    json['defaults'] = {
      'standard': ['mobile']
    };
    json['placements'] = {
      'title_detail': {
        'units': ['rectangle']
      },
      'live_tv_strip_tv': {
        'units': ['wide', 'mobile']
      },
    };
    final config = BannerAdsConfig.parse(jsonEncode(json),
        network: AdNetwork.adsterra, enabled: true, tvEnabled: true);
    expect(config.resolve('title_detail', television: true), isNull);
    expect(config.resolve('live_tv_strip', television: true)?.code, 'wide_key');
  });

  test('invalid codes and insecure or injectable script URLs are rejected', () {
    final valid = {
      'key': 'banner_key',
      'script_url': 'https://ads.example/banner_key/invoke.js',
      'size': '320x50',
    };
    for (final change in [
      {'key': "bad'</script>"},
      {'script_url': 'http://ads.example/invoke.js'},
      {'script_url': 'javascript:alert(1)'},
      {'script_url': 'https://user:pass@ads.example/invoke.js'},
      {'size': '320x100'},
      {'size': null},
    ]) {
      expect(AdsterraBannerUnit.parse({...valid, ...change}), isNull);
    }
    final unit = AdsterraBannerUnit.parse({
      ...valid,
      'script_url': 'https://ads.example/invoke.js?x="&y=1',
    })!;
    expect(unit.html, contains('%22&amp;y=1'));
    expect(unit.html, contains('"width":320'));
    expect(unit.html, contains('"height":50'));
  });

  test('banner options remain removable by the network script', () {
    final html = testAdsterraConfig().units['mobile']!.html;
    // Adsterra uses strict-mode delete window.atOptions after consuming it.
    // A global var binding would make that cleanup throw a TypeError.
    expect(html, contains('window.atOptions={'));
    expect(html, isNot(contains('var atOptions')));
    expect(html, isNot(contains('let atOptions')));
    expect(html, isNot(contains('const atOptions')));
  });

  test('remote switches and catalog changes apply without restarting',
      () async {
    final remote = FakeFirebaseRemoteConfig();
    final provider = AppDependencyProvider();
    await AppRemoteConfig.configure(remote);
    expect(remote.defaults[AppRemoteConfig.bannerAdNetworkKey], 'adsterra');
    expect(remote.defaults[AppRemoteConfig.adsterraBannerEnabledKey], false);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.isNetworkBannerActive, isFalse);

    remote.setMockBool(AppRemoteConfig.adsterraBannerEnabledKey, true);
    remote.setMockString(
        AppRemoteConfig.adsterraBannersKey, testAdsterraCatalog);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.isNetworkBannerActive, isTrue);
    expect(provider.bannerAdsFor(AdNetwork.adsterra).resolve('downloads')?.code,
        'mobile_key');

    remote.setMockString(AppRemoteConfig.adsterraBannersKey, '{');
    AppRemoteConfig.apply(remote, provider);
    expect(provider.isNetworkBannerActive, isFalse);
    expect(provider.bannerAdsFor(AdNetwork.adsterra).units, isEmpty);
  });

  test('legacy network names need the new switch; none hides every banner', () {
    final provider = AppDependencyProvider();
    for (final value in ['native', 'unity', 'startio', 'adsterra']) {
      provider.setBannerAdNetwork(value);
      expect(provider.isNetworkBannerActive, isFalse);
    }
    provider.setBannerAdsConfig(testAdsterraConfig());
    expect(provider.isNetworkBannerActive, isTrue);
    provider.setBannerAdNetwork('none');
    expect(provider.isNetworkBannerActive, isFalse);
    expect(provider.isHostedBannerActive, isFalse);
  });

  test('Clickadu units take their spot and the catalog Main Tag', () {
    final config = testClickaduConfig();
    final mobile = config.resolve('downloads')! as ClickaduBannerUnit;
    expect(mobile.network, AdNetwork.clickadu);
    expect(mobile.code, '1001');
    expect(mobile.scriptUrl, Uri.parse('https://cl.example/bn.js'));
    expect(config.resolve('downloads', tall: true)?.code, '2002');
    final wide = config.units['wide']! as ClickaduBannerUnit;
    expect(wide.scriptUrl, Uri.parse('https://cl2.example/bn.js'));

    final html = mobile.html;
    expect(html, contains('<div data-cl-spot="1001"></div>'));
    expect(
        html,
        contains('<script async data-cfasync="false" data-clbaid="" '
            'src="https://cl.example/bn.js"'));
    expect(html, contains('body{width:320px;height:50px;}'));
    // A loaded Main Tag is not a filled spot: only a visible creative counts.
    expect(html, isNot(contains('onload=')));
    expect(html, contains("BannerStatus.postMessage('loaded')"));
  });

  test('invalid Clickadu spots, sizes and script URLs are rejected', () {
    const valid = {'spot_id': '2150724', 'size': '300x250'};
    const tag = 'https://cl.example/bn.js';
    expect(ClickaduBannerUnit.parse(valid, scriptUrl: tag), isNotNull);
    expect(ClickaduBannerUnit.parse(valid), isNull);
    for (final change in <Map<String, Object?>>[
      {'spot_id': '21507"24'},
      {'spot_id': -4},
      {'spot_id': null},
      {'size': '300'},
      {'size': '5000x250'},
      {'script_url': '//cl.example/bn.js'},
      {'script_url': 'http://cl.example/bn.js'},
      {'enabled': false},
    ]) {
      expect(ClickaduBannerUnit.parse({...valid, ...change}, scriptUrl: tag),
          isNull,
          reason: '$change');
    }
  });

  test('banner_ad_network picks which catalog serves every slot', () {
    final provider = AppDependencyProvider()
      ..setBannerAdsConfig(testAdsterraConfig())
      ..setBannerAdsConfig(testClickaduConfig());
    expect(provider.bannerNetwork, AdNetwork.adsterra);
    expect(provider.activeBannerAds?.resolve('downloads')?.code, 'mobile_key');
    provider.setBannerAdNetwork(' Clickadu ');
    expect(provider.bannerNetwork, AdNetwork.clickadu);
    expect(provider.activeBannerAds?.resolve('downloads')?.code, '1001');
    // The selected network's own switch still has to be on.
    provider.setBannerAdsConfig(testClickaduConfig(enabled: false));
    expect(provider.isNetworkBannerActive, isFalse);
    expect(provider.isHostedBannerActive, isTrue);
    for (final value in ['none', 'admob']) {
      provider.setBannerAdNetwork(value);
      expect(provider.bannerNetwork, isNull);
      expect(provider.isNetworkBannerActive, isFalse);
    }
    provider.setBannerAdNetwork('startio');
    expect(provider.activeBannerAds?.network, AdNetwork.adsterra);
  });

  test('Clickadu banners apply from Remote Config', () async {
    final remote = FakeFirebaseRemoteConfig();
    final provider = AppDependencyProvider();
    await AppRemoteConfig.configure(remote);
    expect(remote.defaults[AppRemoteConfig.clickaduBannerEnabledKey], false);
    expect(remote.defaults[AppRemoteConfig.clickaduTvEnabledKey], false);
    remote
      ..setMockString(AppRemoteConfig.bannerAdNetworkKey, 'clickadu')
      ..setMockString(AppRemoteConfig.clickaduBannersKey, testClickaduCatalog)
      ..setMockString(AppRemoteConfig.adsterraBannersKey, testAdsterraCatalog)
      ..setMockBool(AppRemoteConfig.adsterraBannerEnabledKey, true);
    AppRemoteConfig.apply(remote, provider);
    // Adsterra's switch does not turn on Clickadu.
    expect(provider.isNetworkBannerActive, isFalse);

    remote.setMockBool(AppRemoteConfig.clickaduBannerEnabledKey, true);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.activeBannerAds?.resolve('downloads')?.code, '1001');
    expect(provider.activeBannerAds?.resolve('title_detail', television: true),
        isNull);

    remote.setMockBool(AppRemoteConfig.clickaduTvEnabledKey, true);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.activeBannerAds?.resolve('title_detail', television: true),
        isNotNull);

    remote.setMockString(AppRemoteConfig.bannerAdNetworkKey, 'adsterra');
    AppRemoteConfig.apply(remote, provider);
    expect(provider.activeBannerAds?.resolve('downloads')?.code, 'mobile_key');
  });
}
