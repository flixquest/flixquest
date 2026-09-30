import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:startapp_sdk/startapp.dart';

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
    this.bannerEnabled = false,
    this.interstitialEnabled = false,
    this.testMode = false,
    this.interstitialInterval = const Duration(minutes: 10),
    this.tvInterstitialMode = StartIoInterstitialMode.video,
  });

  final bool bannerEnabled;
  final bool interstitialEnabled;
  final bool testMode;

  /// The shortest gap between two playback interstitials.
  final Duration interstitialInterval;

  final StartIoInterstitialMode tvInterstitialMode;

  StartIoAdsConfig copyWith({
    bool? bannerEnabled,
    bool? interstitialEnabled,
    bool? testMode,
    Duration? interstitialInterval,
    StartIoInterstitialMode? tvInterstitialMode,
  }) =>
      StartIoAdsConfig(
        bannerEnabled: bannerEnabled ?? this.bannerEnabled,
        interstitialEnabled: interstitialEnabled ?? this.interstitialEnabled,
        testMode: testMode ?? this.testMode,
        interstitialInterval: interstitialInterval ?? this.interstitialInterval,
        tvInterstitialMode: tvInterstitialMode ?? this.tvInterstitialMode,
      );

  @override
  bool operator ==(Object other) =>
      other is StartIoAdsConfig &&
      other.bannerEnabled == bannerEnabled &&
      other.interstitialEnabled == interstitialEnabled &&
      other.testMode == testMode &&
      other.interstitialInterval == interstitialInterval &&
      other.tvInterstitialMode == tvInterstitialMode;

  @override
  int get hashCode => Object.hash(
        bannerEnabled,
        interstitialEnabled,
        testMode,
        interstitialInterval,
        tvInterstitialMode,
      );
}

/// Decides when a playback interstitial may show: never twice within the
/// configured interval. Rapid replays, retries and live channel surfing
/// therefore see one ad, not one per tap.
class InterstitialPacing {
  InterstitialPacing({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _lastShownAt;

  bool canShow(Duration interval) {
    final last = _lastShownAt;
    return last == null || _now().difference(last) >= interval;
  }

  void recordShown() => _lastShownAt = _now();
}

/// Completes once its full-screen ad is gone, whichever callback says so.
class _AdSession {
  final Completer<void> _closed = Completer<void>();

  Future<void> get closed => _closed.future;

  bool get isOpen => !_closed.isCompleted;

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

  /// Targeting hints for a movie and series streaming audience.
  static const String catalogKeywords =
      'movies,tv shows,series,streaming,entertainment';
  static const String liveKeywords = 'live tv,sports,football,news,streaming';

  final StartAppSdk _sdk = StartAppSdk();
  final InterstitialPacing _pacing = InterstitialPacing();

  StartIoAdsConfig _config = const StartIoAdsConfig();
  bool _television = false;
  bool? _configuredTestMode;
  _PreparedInterstitial? _preroll;
  Future<void>? _prerollLoading;
  Completer<void>? _fullScreen;

  StartIoAdsConfig get config => _config;

  /// Whether this device runs the Android TV experience.
  bool get isTelevision => _television;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Android TV never shows the playback interstitial, wherever playback
  /// starts.
  bool get _interstitialAllowed =>
      _isSupported && !_television && _config.interstitialEnabled;

  void setTelevision(bool value) {
    if (_television == value) return;
    _television = value;
    _discardPreroll();
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
    if (!_isSupported || !_config.bannerEnabled) return null;
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
    if (!_interstitialAllowed) return Future<void>.value();
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
          // Only once the ad has rendered: a toast raised while the ad
          // screen is still opening is dropped by the system.
          onAdDisplayed: () {
            if (_television) unawaited(_remindRemoteBack(session));
          },
          onAdHidden: session.close,
          onAdNotDisplayed: session.close,
        ),
      );
      if (ad == null) continue;
      if (setup != _prerollSetup || !_interstitialAllowed) {
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

  static const MethodChannel _deviceChannel = MethodChannel(
    'dev.beamlak.flixquest/device_presentation',
  );

  /// Tells a TV viewer how to leave the ad, since Start.io's close button is
  /// made for touch. A long toast lasts a few seconds and video ads run
  /// longer, so it is repeated once while the ad is still up.
  Future<void> _remindRemoteBack(_AdSession session) async {
    await _showRemoteHint();
    await Future<void>.delayed(const Duration(seconds: 10));
    if (session.isOpen) await _showRemoteHint();
  }

  Future<void> _showRemoteHint() async {
    try {
      await _deviceChannel.invokeMethod<bool>(
          'showHint', tr('tv_ad_back_hint'));
    } catch (error) {
      debugPrint('StartIoAdsService: unable to show remote hint: $error');
    }
  }

  /// Shows the playback interstitial when pacing allows. Resolves once the
  /// ad is gone, or at once when none is due. Never throws.
  Future<void> showPlaybackInterstitial() {
    if (!_interstitialAllowed ||
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
}
