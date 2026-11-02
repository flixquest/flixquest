import 'dart:convert';
import 'dart:io';

import 'package:flixquest/models/banner_ads_config.dart';
import 'package:flixquest/models/banner_ad.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/app_remote_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show appFlavor;

import 'support/fake_adsterra_webview.dart';
import 'support/fake_remote_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  test('banner test selector is restricted to the dev flavor', () {
    for (final flavor in ['prod', 'staging', '', null]) {
      for (final value in ['adsterra', 'clickadu', 'exoclick', 'none']) {
        final selection = AppRemoteConfig.resolveBannerNetworkSelection(
            ' Adsterra ', value,
            flavor: flavor);
        expect(selection.network, 'adsterra');
        expect(selection.testMode, isFalse);
      }
    }
    expect(
        AppRemoteConfig.resolveBannerNetworkSelection('', 'exoclick',
                flavor: 'prod')
            .network,
        'adsterra');
    for (final value in ['', ' ', 'unknown', 'monetag']) {
      final selection = AppRemoteConfig.resolveBannerNetworkSelection(
          'clickadu', value,
          flavor: 'dev');
      expect(selection.network, 'clickadu');
      expect(selection.testMode, isFalse);
    }
    for (final value in ['adsterra', 'clickadu', 'exoclick', 'none']) {
      final selection = AppRemoteConfig.resolveBannerNetworkSelection(
          'adsterra', ' ${value.toUpperCase()} ',
          flavor: 'dev');
      expect(selection.network, value);
      expect(selection.testMode, isTrue);
    }
  });

  test('compiled non-dev flavor ignores the published test selector', () async {
    final remote = FakeFirebaseRemoteConfig();
    final provider = AppDependencyProvider();
    await AppRemoteConfig.configure(remote);
    remote
      ..setMockString(AppRemoteConfig.bannerAdNetworkKey, 'adsterra')
      ..setMockBool(AppRemoteConfig.adsterraBannerEnabledKey, true)
      ..setMockString(AppRemoteConfig.adsterraBannersKey, testAdsterraCatalog)
      ..setMockString(AppRemoteConfig.exoclickBannersKey, testExoclickCatalog)
      ..setMockString(AppRemoteConfig.hostedBannerModeKey, 'priority')
      ..setMockString(
          AppRemoteConfig.bannerAdNetworkOverridesKey, '{"downloads":"none"}');
    for (final testNetwork in ['exoclick', 'clickadu', 'none']) {
      remote.setMockString(AppRemoteConfig.bannerAdNetworkTestKey, testNetwork);
      AppRemoteConfig.apply(remote, provider);
      expect(provider.bannerNetwork, AdNetwork.adsterra);
      expect(provider.bannerAdsForPlacement('downloads'), isNull);
      expect(provider.bannerAdsForPlacement('movie_detail')?.network,
          AdNetwork.adsterra);
      expect(provider.hostedBannerMode, HostedBannerMode.priority);
      expect(provider.bannerAdsFor(AdNetwork.exoclick).enabled, isFalse);
      expect(provider.bannerAdsFor(AdNetwork.exoclick).tvEnabled, isFalse);
    }
  }, skip: appFlavor == 'dev');

  group('compiled dev flavor', () {
    test('banner tests use real catalogs without production enable flags',
        () async {
      final remote = FakeFirebaseRemoteConfig();
      final provider = AppDependencyProvider();
      await AppRemoteConfig.configure(remote);
      expect(remote.defaults[AppRemoteConfig.bannerAdNetworkTestKey], '');
      remote
        ..setMockString(AppRemoteConfig.bannerAdNetworkKey, 'none')
        ..setMockString(AppRemoteConfig.bannerAdNetworkOverridesKey,
            '{"downloads":"none","title_detail_tv":"none"}')
        ..setMockString(AppRemoteConfig.hostedBannerModeKey, 'priority')
        ..setMockString(AppRemoteConfig.adsterraBannersKey, testAdsterraCatalog)
        ..setMockString(AppRemoteConfig.clickaduBannersKey, testClickaduCatalog)
        ..setMockString(
            AppRemoteConfig.exoclickBannersKey, testExoclickCatalog);
      for (final network in [
        AdNetwork.adsterra,
        AdNetwork.clickadu,
        AdNetwork.exoclick
      ]) {
        remote.setMockString(AppRemoteConfig.bannerAdNetworkTestKey,
            ' ${network.name.toUpperCase()} ');
        AppRemoteConfig.apply(remote, provider);
        expect(provider.bannerNetwork, network);
        expect(provider.hostedBannerMode, HostedBannerMode.off);
        expect(
            provider.bannerAdsForPlacement('downloads')?.resolve('downloads'),
            isNotNull);
        expect(
            provider
                .bannerAdsForPlacement('title_detail', television: true)
                ?.resolve('title_detail', television: true),
            isNotNull);
        for (final other in [
          AdNetwork.adsterra,
          AdNetwork.clickadu,
          AdNetwork.exoclick
        ]) {
          expect(provider.bannerAdsFor(other).enabled, other == network);
          expect(provider.bannerAdsFor(other).tvEnabled, other == network);
        }
      }
      // Test activation never rewrites any Firebase production settings.
      expect(remote.getString(AppRemoteConfig.bannerAdNetworkKey), 'none');
      expect(remote.getBool(AppRemoteConfig.exoclickBannerEnabledKey), isFalse);
      expect(remote.getBool(AppRemoteConfig.exoclickTvEnabledKey), isFalse);
    });

    test('clearing banner test mode restores production slot rules and gates',
        () async {
      final remote = FakeFirebaseRemoteConfig();
      final provider = AppDependencyProvider();
      await AppRemoteConfig.configure(remote);
      remote
        ..setMockString(AppRemoteConfig.bannerAdNetworkKey, 'adsterra')
        ..setMockBool(AppRemoteConfig.adsterraBannerEnabledKey, true)
        ..setMockString(AppRemoteConfig.adsterraBannersKey, testAdsterraCatalog)
        ..setMockString(AppRemoteConfig.exoclickBannersKey, testExoclickCatalog)
        ..setMockString(
            AppRemoteConfig.bannerAdNetworkOverridesKey, '{"downloads":"none"}')
        ..setMockString(AppRemoteConfig.hostedBannerModeKey, 'priority')
        ..setMockString(AppRemoteConfig.bannerAdNetworkTestKey, 'exoclick');
      AppRemoteConfig.apply(remote, provider);
      expect(provider.bannerAdsForPlacement('downloads')?.network,
          AdNetwork.exoclick);
      for (final value in ['', 'invalid']) {
        remote.setMockString(AppRemoteConfig.bannerAdNetworkTestKey, value);
        AppRemoteConfig.apply(remote, provider);
        expect(provider.bannerNetwork, AdNetwork.adsterra);
        expect(provider.bannerAdsForPlacement('downloads'), isNull);
        expect(provider.bannerAdsForPlacement('movie_detail')?.network,
            AdNetwork.adsterra);
        expect(provider.hostedBannerMode, HostedBannerMode.priority);
        expect(provider.bannerAdsFor(AdNetwork.exoclick).enabled, isFalse);
        expect(provider.bannerAdsFor(AdNetwork.exoclick).tvEnabled, isFalse);
      }
      remote.setMockString(AppRemoteConfig.bannerAdNetworkTestKey, 'none');
      AppRemoteConfig.apply(remote, provider);
      expect(provider.bannerAdNetwork, 'none');
      expect(provider.bannerAdsForPlacement('movie_detail'), isNull);
      expect(provider.isHostedBannerActive, isFalse);
    });

    test('banner test mode still requires a valid catalog', () async {
      final remote = FakeFirebaseRemoteConfig();
      final provider = AppDependencyProvider();
      await AppRemoteConfig.configure(remote);
      remote.setMockString(AppRemoteConfig.bannerAdNetworkTestKey, 'exoclick');
      AppRemoteConfig.apply(remote, provider);
      expect(provider.activeBannerAds?.resolve('downloads'), isNull);
      remote.setMockString(AppRemoteConfig.exoclickBannersKey, '{');
      AppRemoteConfig.apply(remote, provider);
      expect(provider.bannerAdsForPlacement('downloads'), isNull);
    });
  }, skip: appFlavor != 'dev');

  test(
      'published ExoClick catalog replaces every current slot at fitting sizes',
      () {
    final raw = File('docs/exoclick_banners.json').readAsStringSync();
    final catalog = BannerAdsConfig.parse(raw,
        network: AdNetwork.exoclick, enabled: true, tvEnabled: true);
    expect(catalog.units.length, 8);
    final inherited = BannerAdsConfig.parse(
        File('docs/adsterra_banners.json').readAsStringSync(),
        network: AdNetwork.adsterra,
        enabled: true,
        tvEnabled: true);
    for (final name in inherited.placements.keys) {
      final tv = name.endsWith('_tv');
      final placement = tv ? name.substring(0, name.length - 3) : name;
      expect(
          catalog.resolve(placement, television: tv, maxWidth: 360), isNotNull,
          reason: 'Missing replacement for $name');
    }
    expect(catalog.resolve('movie_detail', maxWidth: 360)?.code, '6057770');
    expect(catalog.resolve('movie_detail', maxWidth: 600)?.code, '6057778');
    expect(catalog.resolve('home_all_hero', maxWidth: 1000)?.code, '6057786');
    expect(catalog.resolve('home_all_hero', maxWidth: 800)?.code, '6057784');
    expect(catalog.resolve('downloads', maxWidth: 360, maxHeight: 60)?.code,
        '6057772');
    expect(catalog.resolve('downloads', maxWidth: 360)?.code, '6057766');
    expect((catalog.units['mobile_rectangle']! as ExoclickBannerUnit).className,
        'eas6a97888e10');
    expect((catalog.units['web_rectangle']! as ExoclickBannerUnit).className,
        'eas6a97888e2');
  });

  test('ExoClick mobile and web formats select the first size that fits', () {
    final config = testExoclickConfig();
    expect(config.units.length, 7);
    expect(config.resolve('downloads', maxWidth: 360)?.size,
        const BannerSize(300, 100));
    expect(config.resolve('downloads', maxWidth: 360, maxHeight: 60)?.size,
        const BannerSize(300, 50));
    expect(config.resolve('downloads', maxWidth: 800)?.size,
        const BannerSize(728, 90));
    expect(config.resolve('home_all_hero', maxWidth: 1000)?.size,
        const BannerSize(900, 250));
    expect(config.resolve('movie_detail', maxHeight: 400)?.size,
        const BannerSize(300, 250));
    expect(config.resolve('movie_detail', maxHeight: 600)?.size,
        const BannerSize(300, 500));
    expect(config.resolve('downloads', maxWidth: 299), isNull);
    final unit = config.units['mobile']! as ExoclickBannerUnit;
    expect(unit.html, contains('class="eas6a97888e10" data-zoneid="3001"'));
    expect(unit.html, contains('(AdProvider = window.AdProvider || []).push'));
    expect(unit.html, contains('body{width:300px;height:100px;}'));
    expect(unit.html, isNot(contains('onload=')));
    expect(unit.html, contains('spot.querySelectorAll'));
  });

  test('ExoClick rejects invalid tags and permits per-unit tag overrides', () {
    const valid = {'zone_id': '3001', 'size': '300x250'};
    ExoclickBannerUnit? parse(Map<String, Object?> raw) =>
        ExoclickBannerUnit.parse(raw,
            scriptUrl: 'https://exo.example/ad-provider.js',
            className: 'eas6a97888e10');
    expect(parse(valid), isNotNull);
    for (final change in <Map<String, Object?>>[
      {'zone_id': 0},
      {'zone_id': -1},
      {'zone_id': '"3001'},
      {'zone_id': 1.2},
      {'zone_id': null},
      {'size': '320x50'},
      {'size': '300x999'},
      {'class_name': 'x" onclick="bad'},
      {'class_name': 'two classes'},
      {'script_url': 'http://exo.example/ad-provider.js'},
      {'script_url': 'https://user:pass@exo.example/ad-provider.js'},
      {'enabled': false},
      {'min_width': -1},
      {'min_width': 600.5},
    ]) {
      expect(parse({...valid, ...change}), isNull, reason: '$change');
    }
    expect(ExoclickBannerUnit.parse(valid), isNull);
    final unit = parse({
      ...valid,
      'class_name': 'adsbyexoclick',
      'script_url': 'https://other.example/ad-provider.js?x="&y=1'
    })!;
    expect(unit.html, contains('class="adsbyexoclick"'));
    expect(unit.html, contains('%22&amp;y=1'));
  });

  test('ExoClick sub IDs come from the placement, then unit, then catalog', () {
    final config = BannerAdsConfig.parse(
        jsonEncode({
          'script_url': 'https://exo.example/ad-provider.js',
          'class_name': 'eas6a97888e10',
          'sub': 100,
          'units': {
            'a': {'zone_id': '3001', 'size': '300x250'},
            'b': {'zone_id': '3002', 'size': '300x250', 'sub': '200'},
            'c': {'zone_id': '3003', 'size': '300x250', 'sub': 'bad'},
          },
          'placements': {
            'catalog': ['a'],
            'unit': ['b'],
            'slot': {
              'units': ['b'],
              'sub': 300
            },
            'bad_slot': {
              'units': ['a'],
              'sub': -1
            },
            'invalid_unit': ['c'],
          },
        }),
        network: AdNetwork.exoclick,
        enabled: true);
    String? tag(String placement) => config.resolve(placement)?.html;

    expect(tag('catalog'), contains('data-zoneid="3001" data-sub="100"></ins>'));
    expect(tag('unit'), contains('data-sub="200"'));
    expect(tag('slot'), contains('data-zoneid="3002" data-sub="300"'));
    expect(tag('bad_slot'), contains('data-sub="100"'));
    expect(tag('invalid_unit'), contains('data-sub="100"'));
    expect(config.units['b'], isNot(config.resolve('slot')));

    final plain = BannerAdsConfig.parse(
        jsonEncode({
          'script_url': 'https://exo.example/ad-provider.js',
          'class_name': 'eas6a97888e10',
          'units': {
            'a': {'zone_id': '3001', 'size': '300x250', 'sub': 0},
          },
          'defaults': {
            'tall': ['a']
          },
        }),
        network: AdNetwork.exoclick,
        enabled: true);
    expect(plain.resolve('any', tall: true)?.html, isNot(contains('data-sub')));
  });

  test('ExoClick passes the blocked ad types from the catalog or the unit', () {
    String tag(Map<String, Object?> catalog, [Map<String, Object?>? unit]) {
      final config = BannerAdsConfig.parse(
          jsonEncode({
            'script_url': 'https://exo.example/ad-provider.js',
            'class_name': 'eas6a97888e10',
            ...catalog,
            'units': {
              'a': {'zone_id': '3001', 'size': '300x250', ...?unit},
            },
          }),
          network: AdNetwork.exoclick,
          enabled: true);
      return config.units['a']?.html ?? 'rejected';
    }

    expect(tag({}), isNot(contains('data-block-ad-types')));
    expect(tag({'block_ad_types': 0}), isNot(contains('data-block-ad-types')));
    expect(tag({'block_ad_types': 6}),
        contains('data-zoneid="3001" data-block-ad-types="6"></ins>'));
    expect(tag({'block_ad_types': '6'}), contains('data-block-ad-types="6"'));
    expect(tag({'block_ad_types': 6}, {'block_ad_types': 2}),
        contains('data-block-ad-types="2"'));
    expect(tag({'block_ad_types': 6}, {'block_ad_types': 0}),
        isNot(contains('data-block-ad-types')));
    for (final bad in <Object>[-1, 1.5, '2"', 'video', true]) {
      expect(tag({}, {'block_ad_types': bad}), 'rejected', reason: '$bad');
    }
  });

  test('ExoClick remote gates and slot overrides update independently',
      () async {
    final remote = FakeFirebaseRemoteConfig();
    final provider = AppDependencyProvider();
    await AppRemoteConfig.configure(remote);
    expect(remote.defaults[AppRemoteConfig.exoclickBannerEnabledKey], false);
    expect(remote.defaults[AppRemoteConfig.exoclickTvEnabledKey], false);
    remote
      ..setMockString(AppRemoteConfig.adsterraBannersKey, testAdsterraCatalog)
      ..setMockBool(AppRemoteConfig.adsterraBannerEnabledKey, true)
      ..setMockString(AppRemoteConfig.exoclickBannersKey, testExoclickCatalog)
      ..setMockString(AppRemoteConfig.bannerAdNetworkOverridesKey,
          '{"downloads":" ExoClick ","bookmarks":"none"}');
    AppRemoteConfig.apply(remote, provider);
    expect(provider.bannerAdsForPlacement('downloads'), isNull);
    remote.setMockBool(AppRemoteConfig.exoclickBannerEnabledKey, true);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.bannerAdsForPlacement('downloads')?.network,
        AdNetwork.exoclick);
    expect(provider.bannerAdsForPlacement('movie_detail')?.network,
        AdNetwork.adsterra);
    expect(provider.bannerAdsForPlacement('bookmarks'), isNull);
    // A mobile override never changes the corresponding television slot.
    expect(
        provider.bannerAdsForPlacement('downloads', television: true), isNull);
    remote
      ..setMockString(AppRemoteConfig.bannerAdNetworkKey, 'exoclick')
      ..setMockString(AppRemoteConfig.bannerAdNetworkOverridesKey, '{}');
    AppRemoteConfig.apply(remote, provider);
    expect(provider.bannerAdsForPlacement('movie_detail')?.network,
        AdNetwork.exoclick);
    expect(provider.bannerAdsForPlacement('title_detail', television: true),
        isNull);
    remote.setMockBool(AppRemoteConfig.exoclickTvEnabledKey, true);
    AppRemoteConfig.apply(remote, provider);
    expect(
        provider
            .bannerAdsForPlacement('title_detail', television: true)
            ?.network,
        AdNetwork.exoclick);
    remote.setMockString(AppRemoteConfig.exoclickBannersKey, '{');
    AppRemoteConfig.apply(remote, provider);
    expect(provider.bannerAdsForPlacement('downloads')?.resolve('downloads'),
        isNull);
    provider
      ..setBannerAdsConfig(testExoclickConfig())
      ..setBannerAdNetworkOverrides({'downloads': 'exoclick'})
      ..setBannerAdNetwork('none');
    expect(provider.bannerAdsForPlacement('downloads'), isNull);
    expect(provider.isHostedBannerActive, isFalse);
  });

  test('malformed slot overrides clear safely and unknown networks stay off',
      () {
    for (final raw in ['', '{', '[]', '{"downloads":3}']) {
      expect(AppRemoteConfig.parseBannerNetworkOverrides(raw), isEmpty);
    }
    final provider = AppDependencyProvider()
      ..setBannerAdsConfig(testAdsterraConfig())
      ..setBannerAdNetworkOverrides({'downloads': 'unknown'});
    expect(provider.bannerAdsForPlacement('downloads'), isNull);
    provider.setBannerAdNetworkOverrides({});
    expect(provider.bannerAdsForPlacement('downloads')?.network,
        AdNetwork.adsterra);
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
