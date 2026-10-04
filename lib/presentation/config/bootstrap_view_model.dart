import 'package:flutter/foundation.dart';
import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/data/models/bootstrap_config.dart';
import 'package:flixquest/data/repositories/config_repository.dart';
import 'package:flixquest/models/banner_ad.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/start_io_ads_service.dart';

/// Maps bootstrap into the provider shared by phone, tablet and television.
class BootstrapViewModel extends ChangeNotifier {
  BootstrapViewModel(this.repository, this.dependencies);
  final ConfigRepository repository;
  final AppDependencyProvider dependencies;
  BootstrapConfig _config = const BootstrapConfig();
  BootstrapConfig get config => _config;
  bool _disposed = false;
  DateTime? get lastValidatedAt => repository.lastValidatedAt;

  Future<void> hydrate() async => apply(await repository.loadCached());
  Future<void> refresh() async => apply(await repository.refresh());

  void apply(BootstrapConfig value, {bool preserveThemeSelection = false}) {
    if (_disposed) return;
    _config = value;
    dependencies.displayWatchNowButton = value.features.enableStream;
    dependencies.displayDownloadButton = value.features.enableDownload;
    dependencies.displayLiveTV = value.features.enableLiveTv;
    final logo = value.branding.appLogoUrl.trim();
    dependencies.flixQuestLogo =
        logo.isNotEmpty ? logo : value.branding.cinemaxLogo;
    dependencies.setBannerConfigs(
        {for (final banner in value.banners) banner.key: banner.toDomain()});
    dependencies.setBannerAdNetwork(value.ads.bannerAdNetwork);
    dependencies.setHostedBannerMode(
        HostedBannerMode.parse(value.ads.hostedBannerMode));
    dependencies.setUnityAdsConfig(
        gameIdAndroid: value.ads.unityGameIdAndroid,
        bannerPlacementId: value.ads.unityBannerPlacementId,
        testMode: value.ads.unityTestMode);
    dependencies.setStartIoAdsConfig(
      bannerEnabled: value.ads.startioBannerEnabled,
      interstitialEnabled: value.ads.startioInterstitialEnabled,
      interstitialInterval: Duration(
          seconds:
              value.ads.startioInterstitialIntervalSeconds.clamp(60, 86400)),
      tvInterstitialMode:
          StartIoInterstitialMode.parse(value.ads.startioTvInterstitialMode),
    );
    StartIoAdsService.instance.updateConfig(dependencies.startIoAds);
    dependencies.setFlixquestApiConfig(
        instances: value.network.flixquestApiInstances,
        url: value.network.flixquestApiUrlV2);
    dependencies.tmdbProxy = value.network.tmdbProxy;
    TMDB_API_KEY = value.network.tmdbApiKey;
    dependencies.setUpdateConfiguration(
        forced: value.updates.forcedUpdate,
        latestVersion: value.updates.latestVersion,
        latestBuild: value.updates.latestBuildNumber,
        minimumBuild: value.updates.minBuildNumber,
        downloadUrl: value.updates.appDownloadUrl,
        changeLog: value.updates.changeLog);
    dependencies.applyOccasionalThemeCatalog(
        value.occasionalTheme.toDomain(resolvedAt: lastValidatedAt),
        preserveSelection: preserveThemeSelection);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
