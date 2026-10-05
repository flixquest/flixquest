import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/adsterra_playback_ads_config.dart';
import '../provider/app_dependency_provider.dart';
import '../widgets/adsterra_playback_ad_screen.dart';
import 'device_presentation_service.dart';

/// One coordinator for every phone playback entry point. Skipped/failed ads
/// continue immediately; an overlapping request never starts another loader.
class AdsterraPlaybackAdsService {
  AdsterraPlaybackAdsService({
    Future<SharedPreferences> Function()? preferences,
    this.externalLauncher,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;
  static final instance = AdsterraPlaybackAdsService();

  final Future<SharedPreferences> Function() _preferences;
  final Future<bool> Function(Uri)? externalLauncher;
  final Map<String, int> _rotation = {};
  bool _busy = false;

  Future<bool> beforeLoader(BuildContext context,
          {bool download = false, bool television = false}) =>
      show(context, PlaybackAdStage.beforeLoader,
          download: download, television: television);

  Future<bool> streamFound(BuildContext context,
          {bool download = false, bool television = false}) =>
      show(context, PlaybackAdStage.streamFound,
          download: download, television: television);

  Future<bool> show(BuildContext context, PlaybackAdStage stage,
      {bool download = false, bool television = false}) async {
    if (!context.mounted) {
      _logSkip(stage, 'playback screen disposed');
      return false;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _logSkip(stage, 'app lifecycle=${lifecycle.name}');
      return true;
    }
    if (download ||
        television ||
        DevicePresentationService.instance.isTelevision ||
        kIsWeb ||
        !const {TargetPlatform.android, TargetPlatform.iOS}
            .contains(defaultTargetPlatform)) {
      _logSkip(stage,
          'download=$download television=${television || DevicePresentationService.instance.isTelevision} platform=${defaultTargetPlatform.name} web=$kIsWeb');
      return true;
    }
    if (_busy) {
      _logSkip(stage, 'another playback ad is active');
      return false;
    }
    final provider = context.read<AppDependencyProvider?>();
    final config = provider?.adsterraPlaybackAds;
    var placement = config?.forStage(stage);
    if (provider == null || placement == null) {
      _logSkip(stage,
          'remote enabled=${provider?.adsterraPlaybackAds.enabled ?? false}; stage disabled or invalid/missing config');
      return true;
    }
    _busy = true;
    final host = ModalRoute.of(context);
    try {
      String? variantId;
      final experiment = stage == PlaybackAdStage.streamFound
          ? config?.streamFoundExperiment
          : null;
      if (experiment != null) {
        final selected = await _nextVariant(experiment);
        placement = selected.placement;
        variantId = '${experiment.id}/${selected.id}';
      }
      // Preference writes may yield to a disable, a navigation, or backgrounding.
      if (!context.mounted) return false;
      if (provider.adsterraPlaybackAds != config ||
          (host != null && !host.isCurrent)) {
        return false;
      }
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return true;
      final selectedPlacement = placement;
      final navigator = Navigator.of(context);
      final route = MaterialPageRoute<void>(
        settings: RouteSettings(name: '/adsterra/${stage.name}'),
        builder: (_) => AdsterraPlaybackAdScreen(
          placement: selectedPlacement,
          stage: stage,
          externalLauncher: externalLauncher,
        ),
      );
      // Compare the catalog, not its first arm: unrelated provider updates must
      // not close a selected B/C variant.
      void onConfigChanged() {
        if (provider.adsterraPlaybackAds != config && route.isActive) {
          navigator.removeRoute(route);
        }
      }

      debugPrint(
          '[AdsterraPlayback] ${stage.name}: presenting ${selectedPlacement.isSmartlink ? 'smartlink' : 'script'} browser=${selectedPlacement.browser.name} variant=${variantId ?? 'legacy'}');
      provider.addListener(onConfigChanged);
      try {
        await navigator.push(route);
      } finally {
        provider.removeListener(onConfigChanged);
      }
      // Remote disable can remove the ad while its external browser is still
      // foreground. Do not hand off to the player until FlixQuest resumes.
      if (selectedPlacement.browser == PlaybackAdBrowser.external &&
          !await _waitForForeground()) {
        return false;
      }
      return context.mounted && (host == null || host.isCurrent);
    } catch (error) {
      debugPrint('[AdsterraPlayback] ${stage.name}: unavailable ($error)');
      return context.mounted && (host == null || host.isCurrent);
    } finally {
      _busy = false;
    }
  }

  Future<PlaybackAdVariant> _nextVariant(
      PlaybackAdExperiment experiment) async {
    final key = 'adsterra_playback.rotation.${experiment.id}';
    var index = _rotation[key] ?? 0;
    try {
      final preferences = await _preferences();
      index = preferences.getInt(key) ?? index;
      index = index % experiment.variants.length;
      final next = (index + 1) % experiment.variants.length;
      _rotation[key] = next;
      if (!await preferences.setInt(key, next)) {
        debugPrint('[AdsterraPlayback] rotation persistence unavailable');
      }
    } catch (error) {
      index = index % experiment.variants.length;
      _rotation[key] = (index + 1) % experiment.variants.length;
      debugPrint('[AdsterraPlayback] rotation uses session storage ($error)');
    }
    return experiment.variants[index];
  }

  void _logSkip(PlaybackAdStage stage, String reason) {
    debugPrint('[AdsterraPlayback] ${stage.name}: skipped ($reason)');
  }
}

Future<bool> _waitForForeground() async {
  final state = WidgetsBinding.instance.lifecycleState;
  if (state == null || state == AppLifecycleState.resumed) return true;
  if (state == AppLifecycleState.detached) return false;
  final waiter = _PlaybackForegroundWaiter();
  WidgetsBinding.instance.addObserver(waiter);
  try {
    return await waiter.result.future;
  } finally {
    WidgetsBinding.instance.removeObserver(waiter);
  }
}

class _PlaybackForegroundWaiter extends WidgetsBindingObserver {
  final result = Completer<bool>();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!result.isCompleted &&
        (state == AppLifecycleState.resumed ||
            state == AppLifecycleState.detached)) {
      result.complete(state == AppLifecycleState.resumed);
    }
  }
}
