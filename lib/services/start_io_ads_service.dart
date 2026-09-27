import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:startapp_sdk/startapp.dart';

import '../singleton/sharedpreferences_singleton.dart';

/// Which interstitial creatives Start.io may serve.
enum StartIoInterstitialMode {
  /// Start.io picks whatever it expects to pay most, display or video.
  automatic,

  /// Video only. Android TV lets a full-screen video run without an instant
  /// D-pad dismiss (non-video full-screen ads must offer one), and video is
  /// bought per impression rather than per click.
  video;

  static StartIoInterstitialMode parse(String raw) =>
      raw.trim().toLowerCase() == automatic.name ? automatic : video;
}

/// Remote-configurable Start.io behaviour, applied by [AppRemoteConfig].
@immutable
class StartIoAdsConfig {
  const StartIoAdsConfig({
    this.bannerEnabled = true,
    this.interstitialEnabled = true,
    this.rewardedEnabled = true,
    this.testMode = false,
    this.interstitialInterval = const Duration(minutes: 10),
    this.adFreePassDuration = const Duration(hours: 2),
    this.tvInterstitialMode = StartIoInterstitialMode.video,
  });

  final bool bannerEnabled;
  final bool interstitialEnabled;

  /// Rewarded video only runs when a viewer opts in for an ad-free pass.
  final bool rewardedEnabled;
  final bool testMode;

  /// The shortest gap between two playback interstitials.
  final Duration interstitialInterval;

  /// How long a completed rewarded video keeps interstitials away.
  final Duration adFreePassDuration;
  final StartIoInterstitialMode tvInterstitialMode;

  StartIoAdsConfig copyWith({
    bool? bannerEnabled,
    bool? interstitialEnabled,
    bool? rewardedEnabled,
    bool? testMode,
    Duration? interstitialInterval,
    Duration? adFreePassDuration,
    StartIoInterstitialMode? tvInterstitialMode,
  }) =>
      StartIoAdsConfig(
        bannerEnabled: bannerEnabled ?? this.bannerEnabled,
        interstitialEnabled: interstitialEnabled ?? this.interstitialEnabled,
        rewardedEnabled: rewardedEnabled ?? this.rewardedEnabled,
        testMode: testMode ?? this.testMode,
        interstitialInterval: interstitialInterval ?? this.interstitialInterval,
        adFreePassDuration: adFreePassDuration ?? this.adFreePassDuration,
        tvInterstitialMode: tvInterstitialMode ?? this.tvInterstitialMode,
      );

  @override
  bool operator ==(Object other) =>
      other is StartIoAdsConfig &&
      other.bannerEnabled == bannerEnabled &&
      other.interstitialEnabled == interstitialEnabled &&
      other.rewardedEnabled == rewardedEnabled &&
      other.testMode == testMode &&
      other.interstitialInterval == interstitialInterval &&
      other.adFreePassDuration == adFreePassDuration &&
      other.tvInterstitialMode == tvInterstitialMode;

  @override
  int get hashCode => Object.hash(
        bannerEnabled,
        interstitialEnabled,
        rewardedEnabled,
        testMode,
        interstitialInterval,
        adFreePassDuration,
        tvInterstitialMode,
      );
}

/// Decides when a playback interstitial may show: never during an ad-free
/// pass, and never twice within the configured interval. Rapid replays,
/// retries and live channel surfing therefore see one ad, not one per tap.
class InterstitialPacing {
  InterstitialPacing({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _lastShownAt;
  DateTime? _adFreeUntil;

  bool get adFreeActive {
    final until = _adFreeUntil;
    return until != null && _now().isBefore(until);
  }

  /// The pass's expiry while one is active.
  DateTime? get adFreeUntil => adFreeActive ? _adFreeUntil : null;

  bool canShow(Duration interval) {
    if (adFreeActive) return false;
    final last = _lastShownAt;
    return last == null || _now().difference(last) >= interval;
  }

  void recordShown() => _lastShownAt = _now();

  DateTime grantAdFree(Duration duration) =>
      _adFreeUntil = _now().add(duration);

  void restoreAdFree(DateTime? until) => _adFreeUntil = until;
}

/// Completes once its full-screen ad is gone, whichever callback says so.
class _AdSession {
  final Completer<void> _closed = Completer<void>();

  Future<void> get closed => _closed.future;

  void close() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

class _PreparedInterstitial {
  _PreparedInterstitial(this.ad, this.session, this.loadedAt, this.setup);

  final StartAppInterstitialAd ad;
  final _AdSession session;
  final DateTime loadedAt;

  /// The configuration it was loaded for; a change discards it.
  final String setup;
}

class _PreparedRewarded {
  _PreparedRewarded(this.session);

  final _AdSession session;
  late final StartAppRewardedVideoAd ad;
  late final DateTime loadedAt;
  bool completed = false;
}

/// Coordinates Start.io ads without ever blocking playback on an SDK,
/// network, or presentation failure.
///
/// The playback interstitial is preloaded so it appears the moment a viewer
/// presses play, and it runs alongside stream resolution rather than ahead
/// of it: callers start [showPlaybackInterstitial], resolve the stream, then
/// await [whenFullScreenAdClosed] before opening the player.
class StartIoAdsService {
  StartIoAdsService._();

  static final StartIoAdsService instance = StartIoAdsService._();

  /// The plugin's Android bridge gives up on any load after a fixed 3s window
  /// and reports a `PlatformException(timeout)` even when the ad eventually
  /// loads. Slow networks therefore need a bounded number of fresh attempts.
  static const int _loadAttempts = 3;

  /// How long a play press waits for an interstitial that is still loading.
  static const Duration _onDemandWait = Duration(seconds: 4);

  /// Preloaded creatives are refreshed before Start.io can expire them.
  static const Duration _preloadMaxAge = Duration(minutes: 45);

  /// How long to wait before asking again after a rewarded video no-fill.
  static const Duration _rewardedRetry = Duration(minutes: 10);

  static const String _adFreeUntilKey = 'startio_ad_free_until';

  /// Targeting hints for a movie and series streaming audience.
  static const String catalogKeywords =
      'movies,tv shows,series,streaming,entertainment';
  static const String liveKeywords = 'live tv,sports,football,news,streaming';

  final StartAppSdk _sdk = StartAppSdk();
  final InterstitialPacing _pacing = InterstitialPacing();

  /// The active ad-free pass's expiry, or null. Drives the pass button.
  final ValueNotifier<DateTime?> adFreeUntil = ValueNotifier<DateTime?>(null);

  /// Whether a rewarded video is loaded, so the pass button is only offered
  /// when pressing it will actually play something.
  final ValueNotifier<bool> adFreePassReady = ValueNotifier<bool>(false);

  StartIoAdsConfig _config = const StartIoAdsConfig();
  bool _television = false;
  bool? _configuredTestMode;
  _PreparedInterstitial? _preroll;
  Future<void>? _prerollLoading;
  _PreparedRewarded? _rewarded;
  Future<void>? _rewardedLoading;
  Completer<void>? _fullScreen;
  Timer? _passExpiry;
  Timer? _rewardedRetryTimer;

  StartIoAdsConfig get config => _config;

  /// Whether this device runs the Android TV experience.
  bool get isTelevision => _television;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether an ad-free pass may be sold at all: both formats are on and no
  /// pass is running.
  bool get _passAllowed =>
      _isSupported &&
      _config.rewardedEnabled &&
      _config.interstitialEnabled &&
      !_pacing.adFreeActive;

  /// Whether the viewer can be offered a rewarded ad-free pass right now.
  bool get canOfferAdFreePass => _passAllowed && adFreePassReady.value;

  void setTelevision(bool value) {
    if (_television == value) return;
    _television = value;
    _discardPreroll();
    _discardRewarded();
  }

  /// Suffixes TV placements so the Start.io portal reports them separately.
  String tagFor(String base) => _television ? '${base}_tv' : base;

  StartIoInterstitialMode get _interstitialMode => _television
      ? _config.tvInterstitialMode
      : StartIoInterstitialMode.automatic;

  /// Identifies the device class and mode a preloaded ad was loaded for.
  String get _prerollSetup => '$_television/${_interstitialMode.name}';

  /// The report tag for [mode]. TV tags carry the creative mode, so video and
  /// automatic fills can be compared in the portal.
  String _prerollTag(StartIoInterstitialMode mode) =>
      _television ? 'preroll_tv_${mode.name}' : 'preroll';

  /// Video first where configured, then any creative: video demand on TV can
  /// come back empty, and an unfilled slot earns nothing.
  List<StartIoInterstitialMode> get _prerollModes =>
      _interstitialMode == StartIoInterstitialMode.video
          ? const <StartIoInterstitialMode>[
              StartIoInterstitialMode.video,
              StartIoInterstitialMode.automatic,
            ]
          : const <StartIoInterstitialMode>[StartIoInterstitialMode.automatic];

  /// Applies Remote Config and makes sure an interstitial is ready. Also runs
  /// when nothing changed, since the first fetch usually matches defaults.
  void updateConfig(StartIoAdsConfig config) {
    final previous = _config;
    _config = config;
    if (previous.testMode != config.testMode ||
        previous.tvInterstitialMode != config.tvInterstitialMode ||
        !config.interstitialEnabled) {
      _discardPreroll();
    }
    if (config.interstitialEnabled) unawaited(preloadPlaybackInterstitial());
    if (previous.testMode != config.testMode || !_passAllowed) {
      _discardRewarded();
    }
    unawaited(preloadAdFreePass());
  }

  Future<void> configure({required bool testMode}) async {
    if (!_isSupported || _configuredTestMode == testMode) return;
    try {
      await _sdk.setTestAdsEnabled(testMode);
      _configuredTestMode = testMode;
    } catch (error) {
      debugPrint('StartIoAdsService: unable to set test mode: $error');
    }
  }

  /// Restores an ad-free pass that outlived the previous app session.
  Future<void> restoreAdFreePass() async {
    try {
      final prefs = await SharedPreferencesSingleton.getInstance();
      final millis = prefs.getInt(_adFreeUntilKey);
      if (millis == null) return;
      _setAdFreeUntil(DateTime.fromMillisecondsSinceEpoch(millis));
    } catch (error) {
      debugPrint('StartIoAdsService: unable to restore ad-free pass: $error');
    }
  }

  void _setAdFreeUntil(DateTime? until) {
    _passExpiry?.cancel();
    _pacing.restoreAdFree(until);
    final active = _pacing.adFreeUntil;
    adFreeUntil.value = active;
    if (active != null) {
      _passExpiry = Timer(active.difference(DateTime.now()), () {
        _setAdFreeUntil(null);
        unawaited(preloadAdFreePass());
      });
    }
  }

  /// Completes once no full-screen ad is loading or on screen, so playback
  /// never starts behind one.
  Future<void> whenFullScreenAdClosed() =>
      _fullScreen?.future ?? Future<void>.value();

  Future<T?> _load<T>(
    String label,
    Future<T> Function() load,
  ) async {
    for (var attempt = 1; attempt <= _loadAttempts; attempt++) {
      try {
        return await load();
      } catch (error) {
        debugPrint(
          'StartIoAdsService: $label attempt $attempt/$_loadAttempts '
          'failed: $error',
        );
        final isTimeout = error is PlatformException && error.code == 'timeout';
        if (!isTimeout || attempt == _loadAttempts) return null;
      }
    }
    return null;
  }

  /// Loads a banner, retrying only the plugin's spurious timeout. Returns
  /// `null` when every attempt fails.
  Future<StartAppBannerAd?> loadBanner({
    required String placement,
    required bool testMode,
    StartAppBannerType type = StartAppBannerType.BANNER,
    String keywords = catalogKeywords,
  }) async {
    if (!_isSupported) return null;
    await configure(testMode: testMode);
    return _load(
      'banner at $placement',
      () => _sdk.loadBannerAd(
        type,
        prefs: StartAppAdPreferences(adTag: placement, keywords: keywords),
      ),
    );
  }

  /// Keeps one playback interstitial ready. Safe to call repeatedly.
  Future<void> preloadPlaybackInterstitial() {
    if (!_isSupported || !_config.interstitialEnabled) {
      return Future<void>.value();
    }
    final ready = _preroll;
    if (ready != null &&
        ready.setup == _prerollSetup &&
        DateTime.now().difference(ready.loadedAt) < _preloadMaxAge) {
      return Future<void>.value();
    }
    _discardPreroll();
    return _prerollLoading ??=
        _loadPreroll().whenComplete(() => _prerollLoading = null);
  }

  Future<void> _loadPreroll() async {
    await configure(testMode: _config.testMode);
    final setup = _prerollSetup;
    for (final mode in _prerollModes) {
      final session = _AdSession();
      final ad = await _load(
        'interstitial (${mode.name})',
        () => _sdk.loadInterstitialAd(
          mode: mode == StartIoInterstitialMode.video
              ? StartAppInterstitialAdMode.video
              : StartAppInterstitialAdMode.automatic,
          prefs: StartAppAdPreferences(
            adTag: _prerollTag(mode),
            keywords: catalogKeywords,
          ),
          onAdHidden: session.close,
          onAdNotDisplayed: session.close,
        ),
      );
      if (ad == null) continue;
      if (setup != _prerollSetup || !_config.interstitialEnabled) {
        ad.dispose();
        return;
      }
      _preroll = _PreparedInterstitial(ad, session, DateTime.now(), setup);
      return;
    }
  }

  void _discardPreroll() {
    _preroll?.ad.dispose();
    _preroll = null;
  }

  Future<void> _runFullScreen(Future<void> Function() body) async {
    final done = Completer<void>();
    _fullScreen = done;
    try {
      await body();
    } catch (error) {
      debugPrint('StartIoAdsService: full-screen ad failed: $error');
    } finally {
      _fullScreen = null;
      done.complete();
    }
  }

  /// Shows the playback interstitial when pacing allows. Resolves once the
  /// ad is gone, or at once when none is due. Never throws.
  Future<void> showPlaybackInterstitial() {
    if (!_isSupported ||
        !_config.interstitialEnabled ||
        _fullScreen != null ||
        !_pacing.canShow(_config.interstitialInterval)) {
      return Future<void>.value();
    }
    return _runFullScreen(() async {
      await preloadPlaybackInterstitial()
          .timeout(_onDemandWait, onTimeout: () {});
      final prepared = _preroll;
      if (prepared == null) return;
      _preroll = null;
      try {
        final shown = await prepared.ad.show();
        if (shown) {
          _pacing.recordShown();
        } else {
          prepared.session.close();
        }
        await prepared.session.closed.timeout(
          const Duration(seconds: 60),
          onTimeout: () {},
        );
      } finally {
        prepared.ad.dispose();
        unawaited(preloadPlaybackInterstitial());
      }
    });
  }

  /// Keeps one rewarded video ready while a pass can be sold. After a
  /// no-fill it tries again later rather than hammering the exchange.
  Future<void> preloadAdFreePass() {
    if (!_passAllowed) return Future<void>.value();
    final ready = _rewarded;
    if (ready != null &&
        DateTime.now().difference(ready.loadedAt) < _preloadMaxAge) {
      return Future<void>.value();
    }
    _discardRewarded();
    return _rewardedLoading ??=
        _loadRewarded().whenComplete(() => _rewardedLoading = null);
  }

  Future<void> _loadRewarded() async {
    _rewardedRetryTimer?.cancel();
    await configure(testMode: _config.testMode);
    final prepared = _PreparedRewarded(_AdSession());
    final ad = await _load(
      'rewarded',
      () => _sdk.loadRewardedVideoAd(
        prefs: StartAppAdPreferences(
          adTag: tagFor('ad_free_pass'),
          keywords: catalogKeywords,
        ),
        onAdHidden: prepared.session.close,
        onAdNotDisplayed: prepared.session.close,
        onVideoCompleted: () => prepared.completed = true,
      ),
    );
    if (ad == null) {
      _rewardedRetryTimer = Timer(_rewardedRetry, () {
        unawaited(preloadAdFreePass());
      });
      return;
    }
    if (!_passAllowed) {
      ad.dispose();
      return;
    }
    prepared
      ..ad = ad
      ..loadedAt = DateTime.now();
    _rewarded = prepared;
    adFreePassReady.value = true;
  }

  void _discardRewarded() {
    _rewarded?.ad.dispose();
    _rewarded = null;
    adFreePassReady.value = false;
  }

  /// Plays the preloaded opt-in rewarded video. A completed view grants an
  /// ad-free pass for [StartIoAdsConfig.adFreePassDuration]; returns whether
  /// it did.
  Future<bool> watchForAdFreePass() async {
    final prepared = _rewarded;
    if (!canOfferAdFreePass || prepared == null || _fullScreen != null) {
      return false;
    }
    _rewarded = null;
    adFreePassReady.value = false;
    await _runFullScreen(() async {
      try {
        if (!await prepared.ad.show()) prepared.session.close();
        await prepared.session.closed.timeout(
          const Duration(seconds: 90),
          onTimeout: () {},
        );
      } finally {
        prepared.ad.dispose();
      }
      if (!prepared.completed) return;
      final until = _pacing.grantAdFree(_config.adFreePassDuration);
      _setAdFreeUntil(until);
      try {
        final prefs = await SharedPreferencesSingleton.getInstance();
        await prefs.setInt(_adFreeUntilKey, until.millisecondsSinceEpoch);
      } catch (error) {
        debugPrint('StartIoAdsService: unable to save ad-free pass: $error');
      }
    });
    // Ready for the next offer, or for when this pass runs out.
    unawaited(preloadAdFreePass());
    return prepared.completed;
  }
}
