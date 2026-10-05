import 'dart:convert';

import 'package:flixquest/models/adsterra_ads_config.dart';
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
      expect(AdsterraAdsConfig.parse(raw, enabled: true).resolve('downloads'),
          isNull);
    }
    expect(testAdsterraConfig(enabled: false).resolve('downloads'), isNull);
  });

  test('variant defaults preserve thin and rectangle sizes', () {
    final config = testAdsterraConfig();
    expect(config.resolve('downloads')?.size, AdsterraBannerSize.mobile);
    expect(config.resolve('stream_loading', tall: true)?.size,
        AdsterraBannerSize.rectangle);
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
    final config = AdsterraAdsConfig.parse(jsonEncode(json), enabled: true);
    expect(config.resolve('downloads', maxWidth: 800)?.key, 'wide_key');
    expect(config.resolve('downloads', maxWidth: 360)?.key, 'mobile_key');
    expect(config.resolve('downloads', maxWidth: 290), isNull);
    expect(config.resolve('bookmarks'), isNull);
    expect(config.resolve('movie_detail')?.key, 'rectangle_key');
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
    final config = AdsterraAdsConfig.parse(jsonEncode(json),
        enabled: true, tvEnabled: true);
    expect(config.resolve('title_detail', television: true), isNull);
    expect(config.resolve('live_tv_strip', television: true)?.key, 'wide_key');
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
    expect(provider.isAdsterraBannerActive, isFalse);

    remote.setMockBool(AppRemoteConfig.adsterraBannerEnabledKey, true);
    remote.setMockString(
        AppRemoteConfig.adsterraBannersKey, testAdsterraCatalog);
    AppRemoteConfig.apply(remote, provider);
    expect(provider.isAdsterraBannerActive, isTrue);
    expect(provider.adsterraAds.resolve('downloads')?.key, 'mobile_key');

    remote.setMockString(AppRemoteConfig.adsterraBannersKey, '{');
    AppRemoteConfig.apply(remote, provider);
    expect(provider.isAdsterraBannerActive, isFalse);
    expect(provider.adsterraAds.units, isEmpty);
  });

  test('legacy network names need the new switch; none hides every banner', () {
    final provider = AppDependencyProvider();
    for (final value in ['native', 'unity', 'startio', 'adsterra']) {
      provider.setBannerAdNetwork(value);
      expect(provider.isAdsterraBannerActive, isFalse);
    }
    provider.setAdsterraAdsConfig(testAdsterraConfig());
    expect(provider.isAdsterraBannerActive, isTrue);
    provider.setBannerAdNetwork('none');
    expect(provider.isAdsterraBannerActive, isFalse);
    expect(provider.isHostedBannerActive, isFalse);
  });
}
