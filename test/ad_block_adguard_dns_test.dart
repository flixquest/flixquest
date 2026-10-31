import 'dart:io';

import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/models/banner_ads_config.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/ad_block_detector.dart';
import 'package:flixquest/services/ad_redirect_resolver.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_adsterra_webview.dart';

/// Runs the real detector against live Adsterra and ExoClick hosts, resolving
/// them through AdGuard DNS as a device with AdGuard Private DNS would, then
/// through this machine's DNS as a control. Needs `dig` and the network; only
/// redirects to FlixQuest are read, no ad is requested.
///
///   FQ_ADGUARD_DNS=94.140.14.14 flutter test test/ad_block_adguard_dns_test.dart
void main() {
  dotenv.testLoad(fileInput: 'FLIXQUEST_API_URL=https://api.test');
  final server = Platform.environment['FQ_ADGUARD_DNS'];
  final skip =
      server == null ? 'Set FQ_ADGUARD_DNS to an AdGuard DNS IP' : false;

  Future<List<InternetAddress>> dig(String host) async {
    final addresses = <InternetAddress>[];
    for (final type in ['A', 'AAAA']) {
      final result = await Process.run(
          'dig', ['+short', '+time=3', '+tries=2', '@$server', host, type]);
      for (final line in (result.stdout as String).split('\n')) {
        final address = InternetAddress.tryParse(line.trim());
        if (address != null) addresses.add(address);
      }
    }
    if (addresses.isEmpty) throw SocketException('Failed host lookup: $host');
    return addresses;
  }

  PopunderAdsConfig exoclickPopup(String url) => PopunderAdsConfig.parse('''{
        "popunder":{"enabled":true,"mode":"smartlink","url":"$url"},
        "tv_popunder":{"enabled":true,"mode":"smartlink","url":"$url"}
      }''', network: AdNetwork.exoclick, enabled: true);

  AdsterraPlaybackAdsConfig adsterraPopup(String url, {String? socialBar}) =>
      AdsterraPlaybackAdsConfig.parse('''{
        ${socialBar == null ? '' : '"interstitial":{"enabled":true,"script_url":"$socialBar"},'}
        "popunder":{"enabled":true,"mode":"smartlink","url":"$url"},
        "tv_popunder":{"enabled":true,"mode":"smartlink","url":"$url"}
      }''', enabled: true);

  AppDependencyProvider popupOnly(AdNetwork network) => AppDependencyProvider()
    ..setBannerAdNetwork('none')
    ..setPlaybackPopunderNetwork(network)
    ..setTvPlaybackPopunderNetwork(network);

  // Whether AdGuard DNS stops each live setup, on phones and TV.
  final scenarios = <String, (AppDependencyProvider, bool, bool)>{
    'Adsterra Smartlink via flix.quest/api/adsterra-popup': (
      popupOnly(AdNetwork.adsterra)
        ..setAdsterraPlaybackAdsConfig(
            adsterraPopup('https://flix.quest/api/adsterra-popup')),
      false,
      false,
    ),
    'Adsterra Smartlink on directyp.org': (
      popupOnly(AdNetwork.adsterra)
        ..setAdsterraPlaybackAdsConfig(adsterraPopup(
            'https://directyp.org/4/d85eb7a00a73c8de8a3252dbd9b19411')),
      true,
      true,
    ),
    'Adsterra Social Bar (phone only) + asiafilm.org Smartlink': (
      popupOnly(AdNetwork.adsterra)
        ..setAdsterraPlaybackAdsConfig(adsterraPopup(
            'https://flix.quest/api/adsterra-popup',
            socialBar:
                'https://bancadeltempoidea.org/14/990c274fd7800e5ffa346cf66322bc19')),
      true,
      false,
    ),
    'ExoClick popup via flix.quest/api/exoclick-popup': (
      popupOnly(AdNetwork.exoclick)
        ..setPopunderAdsConfig(
            exoclickPopup('https://flix.quest/api/exoclick-popup')),
      true,
      true,
    ),
    'ExoClick popup, Adsterra endpoint as fallback': (
      popupOnly(AdNetwork.exoclick)
        ..setPlaybackPopunderFallbackNetworks([AdNetwork.adsterra])
        ..setPopunderAdsConfig(
            exoclickPopup('https://flix.quest/api/exoclick-popup'))
        ..setAdsterraPlaybackAdsConfig(
            adsterraPopup('https://flix.quest/api/adsterra-popup')),
      false,
      false,
    ),
    'ExoClick popup, directyp.org Adsterra as fallback': (
      popupOnly(AdNetwork.exoclick)
        ..setPlaybackPopunderFallbackNetworks([AdNetwork.adsterra])
        ..setPopunderAdsConfig(
            exoclickPopup('https://flix.quest/api/exoclick-popup'))
        ..setAdsterraPlaybackAdsConfig(adsterraPopup(
            'https://directyp.org/4/d85eb7a00a73c8de8a3252dbd9b19411')),
      true,
      true,
    ),
    // A block page is a real address; the popup itself reports this one.
    'ExoClick popup on s.pemsrv.com (block page, left to the popup)': (
      popupOnly(AdNetwork.exoclick)
        ..setPopunderAdsConfig(exoclickPopup(
            'https://s.pemsrv.com/v1/link.php?cat=&idzone=6050984&type=8')),
      false,
      false,
    ),
    'ExoClick banners on a.magsrv.com (phone only)': (
      AppDependencyProvider()
        ..setPlaybackPopunderNetwork(null)
        ..setTvPlaybackPopunderNetwork(null)
        ..setBannerAdsConfig(BannerAdsConfig.parse(
            testExoclickCatalog.replaceAll('https://exo.example/ad-provider.js',
                'https://a.magsrv.com/ad-provider.js'),
            network: AdNetwork.exoclick,
            enabled: true))
        ..setBannerAdNetwork('exoclick'),
      true,
      false,
    ),
  };

  final redirects = AdRedirectResolver();
  Future<(Set<String>, bool)> scan(AppDependencyProvider provider,
      {required bool television, required HostLookup lookup}) async {
    final ads = await redirects
        .resolve(AdBlockDetector.adSources(provider, television: television));
    return (
      ads.all,
      await AdBlockDetector(lookup: lookup)
          .isBlocking(ads.required, alternatives: ads.alternatives),
    );
  }

  for (final MapEntry(key: name, value: (provider, phone, tv))
      in scenarios.entries) {
    test('AdGuard DNS: $name', () async {
      for (final (television, expected) in [(false, phone), (true, tv)]) {
        final (hosts, blocked) =
            await scan(provider, television: television, lookup: dig);
        // ignore: avoid_print
        print(
            '${television ? 'TV   ' : 'phone'} ${blocked ? 'BLOCKED' : 'allowed'}'
            '  $name  $hosts');
        expect(blocked, expected,
            reason: '${television ? 'TV' : 'phone'} hosts $hosts');
      }
    }, skip: skip);
  }

  test('without AdGuard DNS no live setup is reported', () async {
    for (final (provider, _, _) in scenarios.values) {
      for (final television in [false, true]) {
        final (hosts, blocked) = await scan(provider,
            television: television, lookup: InternetAddress.lookup);
        expect(blocked, isFalse, reason: '$hosts');
      }
    }
  }, skip: skip);
}
