import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/adsterra_playback_ads_config.dart';
import '../provider/app_dependency_provider.dart';
import '../widgets/adsterra_playback_ad_screen.dart';
import 'device_presentation_service.dart';
import 'playback_ad_input_service.dart';

export '../widgets/adsterra_playback_ad_screen.dart' show PlaybackAdPreload;

/// One coordinator for every playback entry point, phone and TV. Skipped or
/// failed ads continue immediately; an overlapping request never starts
/// another loader. TV shows only a stream-found `tv_popunder`.
class AdsterraPlaybackAdsService {
  AdsterraPlaybackAdsService({
    Future<SharedPreferences> Function()? preferences,
    this.storeLauncher,
    this.continueTap,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;
  static final instance = AdsterraPlaybackAdsService();

  final Future<SharedPreferences> Function() _preferences;
  final StoreLauncher? storeLauncher;
  final PlaybackContinueTap? continueTap;
  final Map<String, int> _rotation = {};
  bool _busy = false;

  /// Lets route builders omit the waiting frame when no interstitial can run.
  bool needsBeforeLoader(BuildContext context, {bool television = false}) =>
      _eligible(context, television: television) &&
      context
              .read<AppDependencyProvider?>()
              ?.adsterraPlaybackAds
              .forStage(PlaybackAdStage.beforeLoader) !=
          null;

  bool _eligible(BuildContext context,
      {bool download = false, bool television = false}) {
    final state = WidgetsBinding.instance.lifecycleState;
    return context.mounted &&
        (state == null || state == AppLifecycleState.resumed) &&
        !download &&
        !television &&
        !DevicePresentationService.instance.isTelevision &&
        !kIsWeb &&
        const {TargetPlatform.android, TargetPlatform.iOS}
            .contains(defaultTargetPlatform);
  }

  Future<bool> beforeLoader(BuildContext context,
          {bool download = false, bool television = false}) =>
      show(context, PlaybackAdStage.beforeLoader,
          download: download, television: television);

  Future<bool> streamFound(BuildContext context,
          {bool download = false,
          bool television = false,
          PlaybackAdPreload? preload}) =>
      show(context, PlaybackAdStage.streamFound,
          download: download, television: television, preload: preload);

  /// Prepare an empty WebView while sources load, for any network or format.
  /// Ad requests and activation wait for the visible ad screen. Experiments
  /// keep selecting their arm at presentation, so cancelled lookups do not
  /// advance rotation.
  PlaybackAdPreload? preloadStreamFound(BuildContext context,
      {bool download = false, bool television = false}) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!context.mounted ||
        download ||
        _busy ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
        kIsWeb ||
        !const {TargetPlatform.android, TargetPlatform.iOS}
            .contains(defaultTargetPlatform)) {
      return null;
    }
    final provider = context.read<AppDependencyProvider?>();
    final selection = provider?.playbackAdsSelection;
    final tv = television || DevicePresentationService.instance.isTelevision;
    if (provider == null || selection == null) return null;
    final placement = switch (selection.network) {
      AdNetwork.adsterra => selection.adsterra
          .forStage(PlaybackAdStage.streamFound, television: tv),
      AdNetwork.clickadu ||
      AdNetwork.monetag ||
      AdNetwork.exoclick =>
        selection.popunders[selection.network]?.activeFor(television: tv),
      null => null,
    };
    if (placement == null) return null;
    late final PlaybackAdPreload preload;
    void onConfigChanged() {
      if (provider.playbackAdsSelection != selection) preload.dispose();
    }

    provider.addListener(onConfigChanged);
    preload = PlaybackAdPreload(
      placement: placement,
      onReleased: () => provider.removeListener(onConfigChanged),
    );
    return preload;
  }

  Future<bool> show(BuildContext context, PlaybackAdStage stage,
      {bool download = false,
      bool television = false,
      PlaybackAdPreload? preload}) async {
    if (!context.mounted) {
      _logSkip(stage, 'playback screen disposed');
      return false;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _logSkip(stage, 'app lifecycle=${lifecycle.name}');
      return true;
    }
    final tv = television || DevicePresentationService.instance.isTelevision;
    if (download ||
        (tv && stage == PlaybackAdStage.beforeLoader) ||
        kIsWeb ||
        !const {TargetPlatform.android, TargetPlatform.iOS}
            .contains(defaultTargetPlatform)) {
      _logSkip(stage,
          'download=$download television=$tv platform=${defaultTargetPlatform.name} web=$kIsWeb');
      return true;
    }
    if (_busy) {
      _logSkip(stage, 'another playback ad is active');
      return false;
    }
    final provider = context.read<AppDependencyProvider?>();
    final selection = provider?.playbackAdsSelection;
    final network = stage == PlaybackAdStage.beforeLoader
        ? AdNetwork.adsterra
        : selection?.network;
    final config = selection?.adsterra;
    var placement = switch (network) {
      AdNetwork.adsterra => config?.forStage(stage, television: tv),
      AdNetwork.clickadu ||
      AdNetwork.monetag ||
      AdNetwork.exoclick =>
        selection?.popunders[network]?.activeFor(television: tv),
      null => null,
    };
    if (provider == null || placement == null) {
      _logSkip(stage,
          'network=${network?.name ?? 'none'} television=$tv adsterraEnabled=${config?.enabled ?? false} popupEnabled=${selection?.popunders[network]?.enabled ?? false}; stage disabled or invalid/missing ${tv ? 'tv_popunder' : 'config'}');
      return true;
    }
    _busy = true;
    final host = ModalRoute.of(context);
    try {
      String? variantId;
      final experiment = stage == PlaybackAdStage.streamFound &&
              network == AdNetwork.adsterra &&
              !tv
          ? config?.streamFoundExperiment
          : null;
      if (experiment != null) {
        final selected = await _nextVariant(experiment);
        placement = selected.placement;
        variantId = '${experiment.id}/${selected.id}';
      }
      // Preference writes may yield to a disable, a navigation, or backgrounding.
      if (!context.mounted) return false;
      if (provider.playbackAdsSelection != selection ||
          (host != null && !host.isCurrent)) {
        return false;
      }
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return true;
      final selectedPlacement = placement;
      // An empty view also works for another arm of this same experiment;
      // preparation never selects or requests that arm's ad.
      final matches = preload?.placement == selectedPlacement ||
          experiment?.variants
                  .any((variant) => variant.placement == preload?.placement) ==
              true;
      final prepared =
          matches && preload?.unavailable == false ? preload : null;
      // Expired or changed preparation must not suppress an eligible ad.
      if (prepared == null) preload?.dispose();
      prepared?.claim();
      final navigator = Navigator.of(context);
      final route = MaterialPageRoute<void>(
        settings: RouteSettings(
            name: '/${selectedPlacement.network.name}/${stage.name}'),
        builder: (_) => AdsterraPlaybackAdScreen(
          placement: selectedPlacement,
          stage: stage,
          storeLauncher: storeLauncher,
          television: tv,
          preload: prepared,
          continueTap: continueTap,
        ),
      );
      // Compare the catalogs and network, not the chosen arm: unrelated
      // provider updates must not close a selected B/C variant.
      void onConfigChanged() {
        if (provider.playbackAdsSelection != selection && route.isActive) {
          navigator.removeRoute(route);
        }
      }

      debugPrint(
          '[AdsterraPlayback] ${stage.name}: presenting ${selectedPlacement.network.name} ${selectedPlacement.mode} variant=${variantId ?? 'legacy'} television=$tv preloaded=${prepared != null}');
      provider.addListener(onConfigChanged);
      try {
        await navigator.push(route);
      } finally {
        provider.removeListener(onConfigChanged);
      }
      // The ad closes when FlixQuest is backgrounded (for example by a Play
      // Store hand-off). Do not hand off to the player until it resumes.
      if (!await _waitForForeground()) return false;
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
