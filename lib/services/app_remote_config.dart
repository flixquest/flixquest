import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../constants/api_constants.dart';
import '../models/banner_ad.dart';
import '../provider/app_dependency_provider.dart';
import 'start_io_ads_service.dart';

class AppRemoteConfig {
  const AppRemoteConfig._();

  static const occasionalThemeKey = 'occasional_theme';
  static const appLogoKey = 'app_logo_url';
  static const legacyAppLogoKey = 'cinemax_logo';
  static const flixquestApiInstancesKey = 'flixquest_api_instances';
  static const flixquestApiUrlKey = 'flixquest_api_url_v2';
  static const tmdbApiKey = 'tmdb_api_key';
  static const enableWatchNowKey = 'enable_stream';
  static const enableDownloadKey = 'enable_download';
  static const enableLiveTvKey = 'enable_live_tv';
  static const bannersKey = 'banners';
  static const bannerAdNetworkKey = 'banner_ad_network';
  static const unityGameIdAndroidKey = 'unity_game_id_android';
  static const unityBannerPlacementIdKey = 'unity_banner_placement_id';
  static const unityTestModeKey = 'unity_test_mode';
  static const startIoBannerEnabledKey = 'startio_banner_enabled';
  static const startIoInterstitialEnabledKey = 'startio_interstitial_enabled';
  static const startIoInterstitialIntervalKey =
      'startio_interstitial_interval_seconds';
  static const startIoTvInterstitialModeKey = 'startio_tv_interstitial_mode';

  /// Live TV used to ride on the OTT flag before it got a dedicated key.
  static const legacyEnableLiveTvKey = 'enable_ott';

  static Future<void> configure(FirebaseRemoteConfig remoteConfig) async {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(minutes: 1),
      ),
    );
    await remoteConfig.setDefaults(const <String, Object>{
      occasionalThemeKey: '{"enabled":false}',
      appLogoKey: '',
      legacyAppLogoKey: 'default',
      'forced_update': false,
      'latest_version': '',
      'latest_build_number': 0,
      'min_build_number': 0,
      'app_download_url': '',
      'change_log': '',
      flixquestApiInstancesKey: '',
      flixquestApiUrlKey: '',
      tmdbApiKey: '',
      // Feature toggles ship enabled so a failed or offline fetch never hides
      // playback, downloads or Live TV.
      enableWatchNowKey: true,
      enableDownloadKey: true,
      enableLiveTvKey: true,
      legacyEnableLiveTvKey: true,
      bannersKey: '{"banners":[]}',
      bannerAdNetworkKey: 'native',
      unityGameIdAndroidKey: '5445375',
      unityBannerPlacementIdKey: 'Banner_Android',
      unityTestModeKey: false,
      startIoBannerEnabledKey: false,
      startIoInterstitialEnabledKey: false,
      startIoInterstitialIntervalKey: 600,
      startIoTvInterstitialModeKey: 'video',
    });
  }

  static List<String> parseApiInstances(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> && decoded['instances'] is List) {
        return (decoded['instances'] as List)
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      } else if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Malformed JSON falls back gracefully.
    }
    return const [];
  }

  static void apply(
    FirebaseRemoteConfig remoteConfig,
    AppDependencyProvider provider,
  ) {
    final preferredLogoValue = remoteConfig.getValue(appLogoKey);
    final legacyLogoValue = remoteConfig.getValue(legacyAppLogoKey);
    final preferredLogo = preferredLogoValue.asString().trim();
    final legacyLogo = legacyLogoValue.asString().trim();
    if (preferredLogoValue.source == ValueSource.valueRemote &&
        preferredLogo.isNotEmpty) {
      provider.flixQuestLogo = preferredLogo;
    } else if (legacyLogoValue.source == ValueSource.valueRemote) {
      provider.flixQuestLogo = legacyLogo;
    } else if (preferredLogoValue.source == ValueSource.valueRemote) {
      provider.flixQuestLogo = 'default';
    }

    final occasionalThemeValue = remoteConfig.getValue(occasionalThemeKey);
    if (occasionalThemeValue.source == ValueSource.valueRemote) {
      provider.applyRemoteOccasionalTheme(occasionalThemeValue.asString());
    }
    provider.displayWatchNowButton = remoteConfig.getBool(enableWatchNowKey);
    provider.displayDownloadButton = remoteConfig.getBool(enableDownloadKey);
    provider.displayLiveTV = _resolveLiveTv(remoteConfig);
    provider.setBannerConfigs(
        parseBannerConfigs(remoteConfig.getString(bannersKey)));

    final bannerNetwork = remoteConfig.getString(bannerAdNetworkKey).trim();
    provider.setBannerAdNetwork(
      bannerNetwork.isNotEmpty ? bannerNetwork : 'native',
    );

    final unityGameId = remoteConfig.getString(unityGameIdAndroidKey).trim();
    final unityPlacement =
        remoteConfig.getString(unityBannerPlacementIdKey).trim();
    final unityTestMode = remoteConfig.getBool(unityTestModeKey);
    provider.setUnityAdsConfig(
      gameIdAndroid: unityGameId.isNotEmpty ? unityGameId : null,
      bannerPlacementId: unityPlacement.isNotEmpty ? unityPlacement : null,
      testMode: unityTestMode,
    );
    final bannerEnabled = remoteConfig.getValue(startIoBannerEnabledKey);
    final interstitialEnabled =
        remoteConfig.getValue(startIoInterstitialEnabledKey);
    provider.setStartIoAdsConfig(
      bannerEnabled: bannerEnabled.source == ValueSource.valueRemote &&
          bannerEnabled.asBool(),
      interstitialEnabled:
          interstitialEnabled.source == ValueSource.valueRemote &&
              interstitialEnabled.asBool(),
      // Floors keep a mistyped value from turning pacing off entirely.
      interstitialInterval: Duration(
        seconds: remoteConfig.getInt(startIoInterstitialIntervalKey).clamp(
              60,
              86400,
            ),
      ),
      tvInterstitialMode: StartIoInterstitialMode.parse(
        remoteConfig.getString(startIoTvInterstitialModeKey),
      ),
    );
    StartIoAdsService.instance.updateConfig(provider.startIoAds);

    final instancesRaw = remoteConfig.getString(flixquestApiInstancesKey);
    final parsedInstances = parseApiInstances(instancesRaw);
    final legacyUrl = remoteConfig.getString(flixquestApiUrlKey).trim();
    provider.setFlixquestApiConfig(
      instances: parsedInstances,
      url: legacyUrl.isNotEmpty ? legacyUrl : null,
    );

    provider.setUpdateConfiguration(
      forced: remoteConfig.getBool('forced_update'),
      latestVersion: remoteConfig.getString('latest_version'),
      latestBuild: remoteConfig.getInt('latest_build_number'),
      minimumBuild: remoteConfig.getInt('min_build_number'),
      downloadUrl: remoteConfig.getString('app_download_url'),
      changeLog: remoteConfig.getString('change_log'),
    );
    provider.tmdbProxy = remoteConfig.getString('tmdb_proxy');
    final remoteTmdbKey = remoteConfig.getString(tmdbApiKey).trim();
    if (remoteTmdbKey.isNotEmpty) {
      TMDB_API_KEY = remoteTmdbKey;
    }
  }

  static Map<String, BannerDisplayConfig> parseBannerConfigs(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) return const {};
    try {
      final decoded = jsonDecode(trimmed);
      final rawBanners =
          decoded is Map<String, dynamic> ? decoded['banners'] : decoded;
      final configs = <String, BannerDisplayConfig>{};
      if (rawBanners is List) {
        for (final item in rawBanners.whereType<Map>()) {
          for (final entry in item.entries) {
            if (entry.value is Map) {
              configs[entry.key.toString()] = BannerDisplayConfig.fromJson(
                entry.key.toString(),
                Map<String, dynamic>.from(entry.value as Map),
              );
            }
          }
        }
      } else if (rawBanners is Map) {
        for (final entry in rawBanners.entries) {
          if (entry.value is Map) {
            configs[entry.key.toString()] = BannerDisplayConfig.fromJson(
              entry.key.toString(),
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      }
      return configs;
    } catch (_) {
      return const {};
    }
  }

  /// Resolves the Live TV toggle, preferring [enableLiveTvKey] and falling back
  /// to [legacyEnableLiveTvKey] for consoles that have not migrated yet. Only
  /// values actually published remotely win; otherwise the feature stays on.
  static bool _resolveLiveTv(FirebaseRemoteConfig remoteConfig) {
    final value = remoteConfig.getValue(enableLiveTvKey);
    if (value.source == ValueSource.valueRemote) return value.asBool();
    final legacy = remoteConfig.getValue(legacyEnableLiveTvKey);
    if (legacy.source == ValueSource.valueRemote) return legacy.asBool();
    return true;
  }
}
