import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../models/occasional_theme.dart';
import '../models/banner_ad.dart';
import '../preferences/app_dependency_preferences.dart';
import '../models/banner_ads_config.dart';
import '../models/adsterra_playback_ads_config.dart';
import '../models/vast_preroll_config.dart';

class AppDependencyProvider extends ChangeNotifier {
  final AppDependencies _preferences = AppDependencies();
  final math.Random _random = math.Random();

  List<String> _flixquestApiInstances = const <String>[];
  List<String> get flixquestAPIInstances =>
      List<String>.unmodifiable(_flixquestApiInstances);

  String _flixquestAPIUrl = flixquestApiUrl;
  String get configuredFlixquestAPIURL => _flixquestAPIUrl.trim().isNotEmpty
      ? _flixquestAPIUrl.trim()
      : flixquestApiUrl;
  String get flixquestAPIURLV2 => configuredFlixquestAPIURL;

  String get flixquestAPIURL {
    if (_flixquestApiInstances.isNotEmpty) {
      if (_flixquestApiInstances.length == 1) {
        return _flixquestApiInstances.first;
      }
      return _flixquestApiInstances[
          _random.nextInt(_flixquestApiInstances.length)];
    }
    return _flixquestAPIUrl.trim().isNotEmpty
        ? _flixquestAPIUrl.trim()
        : flixquestApiUrl;
  }

  String _flixQuestLogo = 'default';
  String get flixQuestLogo => _flixQuestLogo;

  bool _displayWatchNowButton = true;
  bool get displayWatchNowButton => _displayWatchNowButton;

  bool _displayDownloadButton = true;
  bool get displayDownloadButton => _displayDownloadButton;

  bool _displayLiveTV = true;
  bool get displayLiveTV => _displayLiveTV;

  Map<String, BannerDisplayConfig> _bannerConfigs = const {};

  BannerDisplayConfig bannerConfigFor(String key) =>
      _bannerConfigs[key] ?? BannerDisplayConfig(key: key);

  bool isBannerEnabled(String key, String placement) {
    final config = bannerConfigFor(key);
    return config.enabled && config.appliesTo(placement);
  }

  void setBannerConfigs(Map<String, BannerDisplayConfig> configs) {
    _bannerConfigs = Map.unmodifiable(configs);
    notifyListeners();
  }

  String _bannerAdNetwork = 'adsterra';
  String get bannerAdNetwork => _bannerAdNetwork;

  /// The network `banner_ad_network` selects; null for `none` and unknown
  /// values. Names published before Adsterra (`native`, `unity`, `startio`)
  /// still select Adsterra.
  AdNetwork? get bannerNetwork =>
      const {'native', 'unity', 'startio'}.contains(_bannerAdNetwork)
          ? AdNetwork.adsterra
          : AdNetwork.parse(_bannerAdNetwork);

  /// Every network's banner catalog, whichever one is selected.
  Map<AdNetwork, BannerAdsConfig> _bannerAds = const {};

  BannerAdsConfig bannerAdsFor(AdNetwork network) =>
      _bannerAds[network] ?? BannerAdsConfig(network: network);

  /// The selected network's catalog, once its own switch is on.
  BannerAdsConfig? get activeBannerAds {
    final network = bannerNetwork;
    if (network == null) return null;
    final config = bannerAdsFor(network);
    return config.enabled ? config : null;
  }

  AdsterraPlaybackAdsConfig _adsterraPlaybackAds =
      const AdsterraPlaybackAdsConfig();
  AdsterraPlaybackAdsConfig get adsterraPlaybackAds => _adsterraPlaybackAds;

  void setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig config) {
    _adsterraPlaybackAds = config;
    notifyListeners();
  }

  /// Clickadu's and Monetag's popup catalogs, whichever one is selected.
  Map<AdNetwork, PopunderAdsConfig> _popunderAds = const {};

  PopunderAdsConfig popunderAdsFor(AdNetwork network) =>
      _popunderAds[network] ?? PopunderAdsConfig(network);

  void setPopunderAdsConfig(PopunderAdsConfig config) {
    _popunderAds = Map.unmodifiable({..._popunderAds, config.network: config});
    notifyListeners();
  }

  /// Which network serves the stream-found popup; null serves none. The
  /// Social Bar before the loader stays with Adsterra.
  AdNetwork? _playbackPopunderNetwork = AdNetwork.adsterra;
  AdNetwork? get playbackPopunderNetwork => _playbackPopunderNetwork;

  void setPlaybackPopunderNetwork(AdNetwork? network) {
    if (_playbackPopunderNetwork == network) return;
    _playbackPopunderNetwork = network;
    notifyListeners();
  }

  /// Everything that decides a playback ad. A change closes an active one.
  ({
    AdNetwork? network,
    AdsterraPlaybackAdsConfig adsterra,
    Map<AdNetwork, PopunderAdsConfig> popunders,
  }) get playbackAdsSelection => (
        network: _playbackPopunderNetwork,
        adsterra: _adsterraPlaybackAds,
        popunders: _popunderAds,
      );

  VastPrerollConfig _vastPreroll = const VastPrerollConfig();
  VastPrerollConfig get vastPreroll => _vastPreroll;

  void setVastPrerollConfig(VastPrerollConfig config) {
    if (config == _vastPreroll) return;
    _vastPreroll = config;
    notifyListeners();
  }

  // Only the selected network's own switch and catalog can activate network
  // requests.
  bool get isNetworkBannerActive => activeBannerAds != null;

  void setBannerAdsConfig(BannerAdsConfig config) {
    if (bannerAdsFor(config.network) == config) return;
    _bannerAds = Map.unmodifiable({..._bannerAds, config.network: config});
    notifyListeners();
  }

  HostedBannerMode _hostedBannerMode = HostedBannerMode.stack;
  HostedBannerMode get hostedBannerMode => _hostedBannerMode;
  bool get isHostedBannerActive =>
      _hostedBannerMode != HostedBannerMode.off && _bannerAdNetwork != 'none';

  void setHostedBannerMode(HostedBannerMode mode) {
    if (_hostedBannerMode == mode) return;
    _hostedBannerMode = mode;
    notifyListeners();
  }

  void setBannerAdNetwork(String network) {
    final sanitized = network.trim().toLowerCase();
    if (_bannerAdNetwork == sanitized) return;
    _bannerAdNetwork = sanitized;
    notifyListeners();
  }

  bool _isForcedUpdate = false;
  bool get isForcedUpdate => _isForcedUpdate;

  String _latestAppVersion = '';
  String get latestAppVersion => _latestAppVersion;

  int _latestBuildNumber = 0;
  int get latestBuildNumber => _latestBuildNumber;

  int _minimumBuildNumber = 0;
  int get minimumBuildNumber => _minimumBuildNumber;

  String _appDownloadUrl = '';
  String get appDownloadUrl => _appDownloadUrl;

  String _changeLog = '';
  String get changeLog => _changeLog;

  String _tmdbProxy = '';
  String get tmdbProxy => _tmdbProxy;

  OccasionalThemeCatalog _occasionalThemeCatalog =
      const OccasionalThemeCatalog.disabled();
  String _selectedOccasionalThemeId = 'automatic';
  bool _occasionalThemeEnabled = true;
  bool _occasionalEffectsEnabled = true;
  bool _ambientModeEnabled = false;
  int _nextAmbientScopeId = 0;
  final Map<int, Color?> _ambientScopes = <int, Color?>{};
  int _nextEffectSuppressionId = 0;
  final Set<int> _effectSuppressionScopes = <int>{};
  Timer? _occasionalThemeBoundaryTimer;

  OccasionalThemeCatalog get occasionalThemeCatalog => _occasionalThemeCatalog;
  String get selectedOccasionalThemeId => _selectedOccasionalThemeId;
  bool get occasionalThemeEnabled => _occasionalThemeEnabled;
  bool get occasionalEffectsEnabled => _occasionalEffectsEnabled;
  bool get ambientModeEnabled => _ambientModeEnabled;
  Color? get activeAmbientColor {
    if (!_ambientModeEnabled || activeOccasionalTheme != null) return null;
    for (final color in _ambientScopes.values.toList().reversed) {
      if (color != null) return color;
    }
    return null;
  }

  List<OccasionalTheme> get availableOccasionalThemes =>
      _occasionalThemeCatalog.activeThemes
          .where((theme) => theme.userSelectable)
          .toList(growable: false);
  OccasionalTheme? get activeOccasionalTheme => !_occasionalThemeEnabled
      ? null
      : _occasionalThemeCatalog.resolve(
          selectedThemeId: _selectedOccasionalThemeId,
        );
  bool get shouldShowOccasionalEffects {
    final theme = activeOccasionalTheme;
    return theme != null &&
        _occasionalThemeCatalog.effectsEnabled &&
        _occasionalEffectsEnabled &&
        _effectSuppressionScopes.isEmpty &&
        theme.effect.enabled &&
        theme.effect.type != OccasionalEffectType.none;
  }

  String get effectiveLogoUrl {
    final occasionalLogo = activeOccasionalTheme?.logoUrl.trim() ?? '';
    if (occasionalLogo.isNotEmpty) return occasionalLogo;
    return _flixQuestLogo == 'default' ? '' : _flixQuestLogo.trim();
  }

  Future<void> getFQUrl() async {
    final instances = await _preferences.getFQInstances();
    final url = await _preferences.getFQURL();
    _flixquestApiInstances = instances
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    _flixquestAPIUrl = url.trim().isNotEmpty ? url.trim() : flixquestApiUrl;
    notifyListeners();
  }

  set flixquestAPIURL(String value) {
    final normalized = value.trim().isEmpty ? flixquestApiUrl : value.trim();
    if (_flixquestAPIUrl == normalized) return;
    _flixquestAPIUrl = normalized;
    _preferences.setFlixquestAPIUrl(normalized);
    notifyListeners();
  }

  set flixquestAPIInstances(List<String> values) {
    final normalized = values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (listEquals(_flixquestApiInstances, normalized)) return;
    _flixquestApiInstances = normalized;
    _preferences.setFlixquestAPIInstances(normalized);
    notifyListeners();
  }

  void setFlixquestApiConfig({
    List<String>? instances,
    String? url,
  }) {
    var changed = false;
    if (instances != null) {
      final normalizedInstances = instances
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      if (!listEquals(_flixquestApiInstances, normalizedInstances)) {
        _flixquestApiInstances = normalizedInstances;
        _preferences.setFlixquestAPIInstances(normalizedInstances);
        changed = true;
      }
    }
    if (url != null) {
      final normalizedUrl = url.trim().isEmpty ? flixquestApiUrl : url.trim();
      if (_flixquestAPIUrl != normalizedUrl) {
        _flixquestAPIUrl = normalizedUrl;
        _preferences.setFlixquestAPIUrl(normalizedUrl);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> getFlixQuestLogo() async {
    flixQuestLogo = await _preferences.getFlixQuestLogo();
  }

  set flixQuestLogo(String value) {
    final normalized = value.trim().isEmpty ? 'default' : value.trim();
    if (_flixQuestLogo == normalized) return;
    _flixQuestLogo = normalized;
    _preferences.setFlixQuestUrl(normalized);
    notifyListeners();
  }

  set displayWatchNowButton(bool value) {
    _displayWatchNowButton = value;
    notifyListeners();
  }

  set displayDownloadButton(bool value) {
    _displayDownloadButton = value;
    notifyListeners();
  }

  set displayLiveTV(bool value) {
    _displayLiveTV = value;
    notifyListeners();
  }

  set isForcedUpdate(bool value) {
    _isForcedUpdate = value;
    notifyListeners();
  }

  Future<void> getUpdateConfiguration() async {
    final config = _preferences.getUpdateConfiguration();
    _isForcedUpdate = config['forced'] as bool;
    _latestAppVersion = config['latestVersion'] as String;
    _latestBuildNumber = config['latestBuild'] as int;
    _minimumBuildNumber = config['minimumBuild'] as int;
    _appDownloadUrl = config['downloadUrl'] as String;
    _changeLog = config['changeLog'] as String;
    notifyListeners();
  }

  void setUpdateConfiguration({
    required bool forced,
    required String latestVersion,
    required int latestBuild,
    required int minimumBuild,
    required String downloadUrl,
    required String changeLog,
  }) {
    final normalizedVersion = latestVersion.trim();
    final normalizedDownloadUrl = downloadUrl.trim();
    if (_isForcedUpdate == forced &&
        _latestAppVersion == normalizedVersion &&
        _latestBuildNumber == latestBuild &&
        _minimumBuildNumber == minimumBuild &&
        _appDownloadUrl == normalizedDownloadUrl &&
        _changeLog == changeLog) {
      return;
    }
    _isForcedUpdate = forced;
    _latestAppVersion = normalizedVersion;
    _latestBuildNumber = latestBuild;
    _minimumBuildNumber = minimumBuild;
    _appDownloadUrl = normalizedDownloadUrl;
    _changeLog = changeLog;
    _preferences.setUpdateConfiguration(
      forced: forced,
      latestVersion: normalizedVersion,
      latestBuild: latestBuild,
      minimumBuild: minimumBuild,
      downloadUrl: normalizedDownloadUrl,
      changeLog: changeLog,
    );
    notifyListeners();
  }

  Future<void> getTmdbProxy() async {
    tmdbProxy = await _preferences.getTmdbProxy();
  }

  set tmdbProxy(String value) {
    _tmdbProxy = value;
    _preferences.setTmdbProxy(value);
    notifyListeners();
  }

  Future<void> getOccasionalTheme() async {
    _occasionalThemeCatalog = OccasionalThemeCatalog.fromJsonString(
      await _preferences.getOccasionalTheme(),
    );
    _selectedOccasionalThemeId =
        (await _preferences.getOccasionalThemeSelection()).trim().toLowerCase();
    _occasionalThemeEnabled = await _preferences.getOccasionalThemeEnabled();
    _occasionalEffectsEnabled =
        await _preferences.getOccasionalEffectsEnabled();
    _normalizeOccasionalThemeSelection(persist: true);
    _scheduleOccasionalThemeBoundary();
    notifyListeners();
  }

  Future<void> getAmbientMode() async {
    _ambientModeEnabled = await _preferences.getAmbientModeEnabled();
    notifyListeners();
  }

  set ambientModeEnabled(bool value) {
    if (_ambientModeEnabled == value) return;
    _ambientModeEnabled = value;
    _preferences.setAmbientModeEnabled(value);
    notifyListeners();
  }

  int pushAmbientScope() {
    final id = ++_nextAmbientScopeId;
    _ambientScopes[id] = null;
    return id;
  }

  void updateAmbientScope(int id, Color color) {
    if (!_ambientScopes.containsKey(id) || _ambientScopes[id] == color) return;
    _ambientScopes[id] = color;
    notifyListeners();
  }

  void popAmbientScope(int id) {
    if (!_ambientScopes.containsKey(id)) return;
    final wasActive = activeAmbientColor;
    _ambientScopes.remove(id);
    if (wasActive == activeAmbientColor) return;
    notifyListeners();
  }

  int suppressOccasionalEffects() {
    final id = ++_nextEffectSuppressionId;
    final wasSuppressed = _effectSuppressionScopes.isNotEmpty;
    _effectSuppressionScopes.add(id);
    if (!wasSuppressed) notifyListeners();
    return id;
  }

  void releaseOccasionalEffectsSuppression(int id) {
    if (!_effectSuppressionScopes.remove(id)) return;
    if (_effectSuppressionScopes.isEmpty) notifyListeners();
  }

  set occasionalThemeCatalog(OccasionalThemeCatalog value) {
    _occasionalThemeCatalog = value;
    _preferences.setOccasionalTheme(value.toJsonString());
    _normalizeOccasionalThemeSelection(persist: true);
    _scheduleOccasionalThemeBoundary();
    notifyListeners();
  }

  /// Applies a remotely supplied catalog only when it is structurally valid.
  /// Invalid updates leave the persisted/active catalog untouched so built-in
  /// occasion presets continue to provide the fallback experience.
  bool applyRemoteOccasionalTheme(String json) {
    final catalog = OccasionalThemeCatalog.tryFromJsonString(json);
    if (catalog == null) return false;
    occasionalThemeCatalog = catalog;
    return true;
  }

  void selectOccasionalTheme(String id) {
    final normalized = id.trim().toLowerCase();
    if (normalized != 'automatic' &&
        !availableOccasionalThemes.any((theme) => theme.id == normalized)) {
      return;
    }
    if (_selectedOccasionalThemeId == normalized) return;
    _selectedOccasionalThemeId = normalized;
    _preferences.setOccasionalThemeSelection(normalized);
    notifyListeners();
  }

  set occasionalThemeEnabled(bool value) {
    if (_occasionalThemeEnabled == value) return;
    _occasionalThemeEnabled = value;
    _preferences.setOccasionalThemeEnabled(value);
    notifyListeners();
  }

  set occasionalEffectsEnabled(bool value) {
    if (_occasionalEffectsEnabled == value) return;
    _occasionalEffectsEnabled = value;
    _preferences.setOccasionalEffectsEnabled(value);
    notifyListeners();
  }

  void _normalizeOccasionalThemeSelection({required bool persist}) {
    final valid = _selectedOccasionalThemeId == 'automatic' ||
        (_occasionalThemeCatalog.allowUserSelection &&
            availableOccasionalThemes
                .any((theme) => theme.id == _selectedOccasionalThemeId));
    if (valid) return;
    _selectedOccasionalThemeId = 'automatic';
    if (persist) {
      _preferences.setOccasionalThemeSelection('automatic');
    }
  }

  void _scheduleOccasionalThemeBoundary() {
    _occasionalThemeBoundaryTimer?.cancel();
    final now = DateTime.now().toUtc();
    DateTime? boundary;
    for (final theme in _occasionalThemeCatalog.themes) {
      if (!theme.enabled) continue;
      DateTime? candidate;
      if (theme.startsAt != null && now.isBefore(theme.startsAt!.toUtc())) {
        candidate = theme.startsAt!.toUtc();
      } else if (theme.isActiveAt(now) && theme.endsAt != null) {
        candidate = theme.endsAt!.toUtc().add(
              const Duration(milliseconds: 1),
            );
      }
      if (candidate != null &&
          (boundary == null || candidate.isBefore(boundary))) {
        boundary = candidate;
      }
    }
    if (boundary == null) return;
    _occasionalThemeBoundaryTimer = Timer(boundary.difference(now), () {
      _normalizeOccasionalThemeSelection(persist: true);
      _scheduleOccasionalThemeBoundary();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _occasionalThemeBoundaryTimer?.cancel();
    super.dispose();
  }
}
