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

  /// Asks viewers to turn off their ad blocker when Play or Download starts.
  bool _adBlockGateEnabled = false;
  bool get adBlockGateEnabled => _adBlockGateEnabled;

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

  Map<String, String> _bannerAdNetworkOverrides = const {};

  void setBannerAdNetworkOverrides(Map<String, String> overrides) {
    if (mapEquals(_bannerAdNetworkOverrides, overrides)) return;
    _bannerAdNetworkOverrides = Map.unmodifiable(overrides);
    notifyListeners();
  }

  /// A slot can migrate independently. TV uses only its own `_tv` override.
  /// The global `none` value remains the emergency switch for every banner.
  BannerAdsConfig? bannerAdsForPlacement(String placement,
      {bool television = false}) {
    if (_bannerAdNetwork == 'none') return null;
    final name = television ? '${placement}_tv' : placement;
    final override = _bannerAdNetworkOverrides[name];
    final network =
        override == null ? bannerNetwork : AdNetwork.parse(override);
    if (network == null) return null;
    final config = bannerAdsFor(network);
    return config.enabled && (!television || config.tvEnabled) ? config : null;
  }

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

  /// Selected catalogs, including networks serving individual slot overrides.
  Iterable<BannerAdsConfig> get activeBannerCatalogs sync* {
    if (_bannerAdNetwork == 'none') return;
    final networks = {
      bannerNetwork,
      ..._bannerAdNetworkOverrides.values.map(AdNetwork.parse),
    };
    for (final network in networks) {
      if (network == null) continue;
      final catalog = bannerAdsFor(network);
      if (catalog.enabled) yield catalog;
    }
  }

  AdsterraPlaybackAdsConfig _adsterraPlaybackAds =
      const AdsterraPlaybackAdsConfig();
  AdsterraPlaybackAdsConfig get adsterraPlaybackAds => _adsterraPlaybackAds;

  void setAdsterraPlaybackAdsConfig(AdsterraPlaybackAdsConfig config) {
    _adsterraPlaybackAds = config;
    notifyListeners();
  }

  /// Clickadu's, Monetag's and ExoClick's popup catalogs, whichever is selected.
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

  /// Networks tried in turn, on phones and TV, when the selected network has
  /// no popup for the viewer. Each still needs its own switch and catalog.
  List<AdNetwork> _playbackPopunderFallbackNetworks = const [];
  List<AdNetwork> get playbackPopunderFallbackNetworks =>
      _playbackPopunderFallbackNetworks;

  void setPlaybackPopunderFallbackNetworks(List<AdNetwork> networks) {
    if (listEquals(_playbackPopunderFallbackNetworks, networks)) return;
    _playbackPopunderFallbackNetworks = List.unmodifiable(networks);
    notifyListeners();
  }

  /// Which network serves the popup on Android TV; null serves none. Follows
  /// [playbackPopunderNetwork] until TV gets its own.
  AdNetwork? _tvPlaybackPopunderNetwork;
  bool _tvFollowsPlaybackPopunderNetwork = true;
  AdNetwork? get tvPlaybackPopunderNetwork => _tvFollowsPlaybackPopunderNetwork
      ? _playbackPopunderNetwork
      : _tvPlaybackPopunderNetwork;

  void setTvPlaybackPopunderNetwork(AdNetwork? network,
      {bool followMobile = false}) {
    if (_tvFollowsPlaybackPopunderNetwork == followMobile &&
        _tvPlaybackPopunderNetwork == network) {
      return;
    }
    _tvFollowsPlaybackPopunderNetwork = followMobile;
    _tvPlaybackPopunderNetwork = network;
    notifyListeners();
  }

  /// Minimum minutes between visible stream-found popups; zero allows every
  /// playback. Shared by all popup networks on phones.
  int _playbackPopupFrequencyMinutes = 0;
  int get playbackPopupFrequencyMinutes => _playbackPopupFrequencyMinutes;

  void setPlaybackPopupFrequencyMinutes(int minutes) {
    final normalized = minutes < 0 ? 0 : minutes;
    if (_playbackPopupFrequencyMinutes == normalized) return;
    _playbackPopupFrequencyMinutes = normalized;
    notifyListeners();
  }

  /// Popup browser behavior, shared by every network and trigger.
  bool _playbackPopupAutoClose = false;
  bool get playbackPopupAutoClose => _playbackPopupAutoClose;
  bool _playbackPopupExternalBrowserOnTap = true;
  bool get playbackPopupExternalBrowserOnTap =>
      _playbackPopupExternalBrowserOnTap;

  void setPlaybackPopupBrowserBehavior({
    required bool autoClose,
    required bool externalBrowserOnTap,
  }) {
    if (_playbackPopupAutoClose == autoClose &&
        _playbackPopupExternalBrowserOnTap == externalBrowserOnTap) {
      return;
    }
    _playbackPopupAutoClose = autoClose;
    _playbackPopupExternalBrowserOnTap = externalBrowserOnTap;
    notifyListeners();
  }

  /// The interval on Android TV; null follows [playbackPopupFrequencyMinutes].
  int? _tvPlaybackPopupFrequencyMinutes;
  int get tvPlaybackPopupFrequencyMinutes =>
      _tvPlaybackPopupFrequencyMinutes ?? _playbackPopupFrequencyMinutes;

  void setTvPlaybackPopupFrequencyMinutes(int? minutes) {
    final normalized = minutes == null || minutes >= 0 ? minutes : 0;
    if (_tvPlaybackPopupFrequencyMinutes == normalized) return;
    _tvPlaybackPopupFrequencyMinutes = normalized;
    notifyListeners();
  }

  /// Each popup trigger's own switch and interval ([PlaybackAdStage.triggers]),
  /// served on phones by the selected network. A missing trigger is
  /// unpublished: switches then keep the stream-found popup, and the others
  /// stay off.
  Map<PlaybackAdStage, PopupTriggerConfig> _popupTriggers = const {};
  PopupTriggerConfig? popupTrigger(PlaybackAdStage stage) =>
      _popupTriggers[stage];

  void setPopupTrigger(
    PlaybackAdStage stage, {
    required bool enabled,
    required int frequencyMinutes,
    int minWatchSeconds = 0,
  }) {
    final config = (
      enabled: enabled,
      frequencyMinutes: frequencyMinutes < 0 ? 0 : frequencyMinutes,
      minWatch: Duration(seconds: minWatchSeconds < 0 ? 0 : minWatchSeconds),
    );
    if (_popupTriggers[stage] == config) return;
    _popupTriggers = Map.unmodifiable({..._popupTriggers, stage: config});
    notifyListeners();
  }

  /// Unpublishes [stage]; see [popupTrigger].
  void clearPopupTrigger(PlaybackAdStage stage) {
    if (!_popupTriggers.containsKey(stage)) return;
    _popupTriggers = Map.unmodifiable({..._popupTriggers}..remove(stage));
    notifyListeners();
  }

  /// Whether a player-exit popup earned in a session that ended without
  /// leaving the player (the app was closed from the player) opens on the next
  /// launch, and for how long such a popup stays owed.
  ({bool enabled, Duration maxAge}) _playerExitRelaunch =
      (enabled: false, maxAge: const Duration(hours: 24));
  ({bool enabled, Duration maxAge}) get playerExitRelaunch =>
      _playerExitRelaunch;

  void setPlayerExitRelaunch({required bool enabled, required int maxHours}) {
    final config = (
      enabled: enabled,
      maxAge: Duration(hours: maxHours < 0 ? 0 : maxHours),
    );
    if (_playerExitRelaunch == config) return;
    _playerExitRelaunch = config;
    notifyListeners();
  }

  /// Remote Config has been applied at least once this session, from the
  /// values stored on the device or a fetch.
  bool _remoteConfigApplied = false;
  bool get remoteConfigApplied => _remoteConfigApplied;

  void markRemoteConfigApplied() {
    if (_remoteConfigApplied) return;
    _remoteConfigApplied = true;
    notifyListeners();
  }

  /// Everything that decides a playback ad. A change closes an active one.
  ({
    AdNetwork? network,
    List<AdNetwork> fallbackNetworks,
    AdsterraPlaybackAdsConfig adsterra,
    Map<AdNetwork, PopunderAdsConfig> popunders,
    int popupFrequencyMinutes,
    AdNetwork? tvNetwork,
    int tvPopupFrequencyMinutes,
  }) get playbackAdsSelection => (
        network: _playbackPopunderNetwork,
        fallbackNetworks: _playbackPopunderFallbackNetworks,
        adsterra: _adsterraPlaybackAds,
        popunders: _popunderAds,
        popupFrequencyMinutes: _playbackPopupFrequencyMinutes,
        tvNetwork: tvPlaybackPopunderNetwork,
        tvPopupFrequencyMinutes: tvPlaybackPopupFrequencyMinutes,
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

  /// Split-APK links keyed by ABI; see [AppUpdateService.resolveDownloadUrl].
  Map<String, String> _abiDownloadUrls = const {};
  Map<String, String> get abiDownloadUrls => _abiDownloadUrls;

  String _changeLog = '';
  String get changeLog => _changeLog;

  String _tmdbProxy = '';
  String get tmdbProxy => _tmdbProxy;

  /// The Telegram channel Home invites people to join; null hides the invite.
  Uri? _telegramChannelUrl;
  Uri? get telegramChannelUrl => _telegramChannelUrl;

  /// Takes an `https://t.me/...` link (or a `tg:` one); anything else, empty
  /// included, turns the invite off.
  void setTelegramChannelUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    final valid = uri != null &&
        (((uri.scheme == 'https' || uri.scheme == 'http') &&
                uri.host.isNotEmpty) ||
            uri.scheme == 'tg');
    final url = valid ? uri : null;
    if (_telegramChannelUrl == url) return;
    _telegramChannelUrl = url;
    notifyListeners();
  }

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

  set adBlockGateEnabled(bool value) {
    if (_adBlockGateEnabled == value) return;
    _adBlockGateEnabled = value;
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
    _abiDownloadUrls = config['abiDownloadUrls'] as Map<String, String>;
    _changeLog = config['changeLog'] as String;
    notifyListeners();
  }

  void setUpdateConfiguration({
    required bool forced,
    required String latestVersion,
    required int latestBuild,
    required int minimumBuild,
    required String downloadUrl,
    Map<String, String> abiDownloadUrls = const {},
    required String changeLog,
  }) {
    final normalizedVersion = latestVersion.trim();
    final normalizedDownloadUrl = downloadUrl.trim();
    final normalizedAbiUrls = Map<String, String>.unmodifiable({
      for (final entry in abiDownloadUrls.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    });
    if (_isForcedUpdate == forced &&
        _latestAppVersion == normalizedVersion &&
        _latestBuildNumber == latestBuild &&
        _minimumBuildNumber == minimumBuild &&
        _appDownloadUrl == normalizedDownloadUrl &&
        mapEquals(_abiDownloadUrls, normalizedAbiUrls) &&
        _changeLog == changeLog) {
      return;
    }
    _isForcedUpdate = forced;
    _latestAppVersion = normalizedVersion;
    _latestBuildNumber = latestBuild;
    _minimumBuildNumber = minimumBuild;
    _appDownloadUrl = normalizedDownloadUrl;
    _abiDownloadUrls = normalizedAbiUrls;
    _changeLog = changeLog;
    _preferences.setUpdateConfiguration(
      forced: forced,
      latestVersion: normalizedVersion,
      latestBuild: latestBuild,
      minimumBuild: minimumBuild,
      downloadUrl: normalizedDownloadUrl,
      abiDownloadUrls: normalizedAbiUrls,
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

  Future<void> getOccasionalTheme({bool preserveSelection = false}) async {
    _occasionalThemeCatalog = OccasionalThemeCatalog.fromJsonString(
      await _preferences.getOccasionalTheme(),
    );
    _selectedOccasionalThemeId =
        (await _preferences.getOccasionalThemeSelection()).trim().toLowerCase();
    _occasionalThemeEnabled = await _preferences.getOccasionalThemeEnabled();
    _occasionalEffectsEnabled =
        await _preferences.getOccasionalEffectsEnabled();
    if (!preserveSelection) _normalizeOccasionalThemeSelection(persist: true);
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

  set occasionalThemeCatalog(OccasionalThemeCatalog value) =>
      applyOccasionalThemeCatalog(value);

  /// Provider switches may temporarily omit a theme the user chose. Resolve
  /// the current catalog normally while keeping that preference for its return.
  void applyOccasionalThemeCatalog(OccasionalThemeCatalog value,
      {bool preserveSelection = false}) {
    _occasionalThemeCatalog = value;
    _preferences.setOccasionalTheme(value.toJsonString());
    if (!preserveSelection) _normalizeOccasionalThemeSelection(persist: true);
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
