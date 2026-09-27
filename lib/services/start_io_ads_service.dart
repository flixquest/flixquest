import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:startapp_sdk/startapp.dart';

/// Coordinates Start.io full-screen ads without ever blocking playback on an
/// SDK, network, or presentation failure.
class StartIoAdsService {
  StartIoAdsService._();

  static final StartIoAdsService instance = StartIoAdsService._();

  /// The plugin's Android bridge gives up on a banner after a fixed 3s window
  /// and reports a `PlatformException(timeout)` even when the ad eventually
  /// loads. Slow networks therefore need a bounded number of fresh attempts.
  static const int _bannerLoadAttempts = 3;

  final StartAppSdk _sdk = StartAppSdk();
  bool? _configuredTestMode;
  bool _showingInterstitial = false;
  bool _showingRewarded = false;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> configure({required bool testMode}) async {
    if (!_isSupported || _configuredTestMode == testMode) return;
    try {
      await _sdk.setTestAdsEnabled(testMode);
      _configuredTestMode = testMode;
    } catch (error) {
      debugPrint('StartIoAdsService: unable to set test mode: $error');
    }
  }

  /// Loads a banner, retrying only the plugin's spurious timeout up to
  /// [_bannerLoadAttempts] times. Returns `null` when every attempt fails.
  Future<StartAppBannerAd?> loadBanner({
    required String placement,
    required bool testMode,
    StartAppBannerType type = StartAppBannerType.BANNER,
  }) async {
    if (!_isSupported) return null;
    await configure(testMode: testMode);
    for (var attempt = 1; attempt <= _bannerLoadAttempts; attempt++) {
      try {
        return await _sdk.loadBannerAd(
          type,
          prefs: StartAppAdPreferences(adTag: placement),
        );
      } catch (error) {
        debugPrint(
          'StartIoAdsService: banner attempt $attempt/$_bannerLoadAttempts '
          'at $placement failed: $error',
        );
        final isTimeout = error is PlatformException && error.code == 'timeout';
        if (!isTimeout || attempt == _bannerLoadAttempts) return null;
      }
    }
    return null;
  }

  Future<void> showInterstitial({
    required bool enabled,
    required bool testMode,
    String adTag = 'watch_now',
  }) async {
    if (!enabled || !_isSupported || _showingInterstitial) return;
    _showingInterstitial = true;
    StartAppInterstitialAd? ad;
    final dismissed = Completer<void>();

    void finish() {
      if (!dismissed.isCompleted) dismissed.complete();
    }

    try {
      await configure(testMode: testMode);
      ad = await _sdk.loadInterstitialAd(
        prefs: StartAppAdPreferences(adTag: adTag),
        onAdHidden: finish,
        onAdNotDisplayed: finish,
      );
      final shown = await ad.show();
      if (!shown) finish();
      await dismissed.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {},
      );
    } catch (error) {
      debugPrint('StartIoAdsService: interstitial unavailable: $error');
    } finally {
      ad?.dispose();
      _showingInterstitial = false;
    }
  }

  Future<void> showRewarded({
    required bool enabled,
    required bool testMode,
    String adTag = 'stream_ready',
  }) async {
    if (!enabled || !_isSupported || _showingRewarded) return;
    _showingRewarded = true;
    StartAppRewardedVideoAd? ad;
    final dismissed = Completer<void>();

    void finish() {
      if (!dismissed.isCompleted) dismissed.complete();
    }

    try {
      await configure(testMode: testMode);
      ad = await _sdk.loadRewardedVideoAd(
        prefs: StartAppAdPreferences(adTag: adTag),
        onAdHidden: finish,
        onAdNotDisplayed: finish,
      );
      final shown = await ad.show();
      if (!shown) finish();
      await dismissed.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {},
      );
    } catch (error) {
      debugPrint('StartIoAdsService: rewarded ad unavailable: $error');
    } finally {
      ad?.dispose();
      _showingRewarded = false;
    }
  }
}
