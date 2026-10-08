import 'dart:convert';

import 'ad_network.dart';

export 'ad_network.dart';

enum PlaybackAdStage { beforeLoader, streamFound }

/// Independent of banner settings; missing or malformed remote values disable
/// playback ads. Codes belong in Remote Config, never in compiled defaults.
class AdsterraPlaybackAdsConfig {
  const AdsterraPlaybackAdsConfig({
    this.enabled = false,
    this.interstitial,
    this.popunder,
    this.streamFoundExperiment,
  });

  final bool enabled;
  final PlaybackAdPlacement? interstitial;
  final PlaybackAdPlacement? popunder;
  final PlaybackAdExperiment? streamFoundExperiment;

  PlaybackAdPlacement? forStage(PlaybackAdStage stage) => !enabled
      ? null
      : stage == PlaybackAdStage.beforeLoader
          ? interstitial
          : streamFoundExperiment?.variants.first.placement ?? popunder;

  static AdsterraPlaybackAdsConfig parse(String raw, {required bool enabled}) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return const AdsterraPlaybackAdsConfig();
      }
      final experimentRequested = json['stream_found_experiment'] is Map &&
          json['stream_found_experiment']['enabled'] == true;
      return AdsterraPlaybackAdsConfig(
        enabled: enabled,
        interstitial: PlaybackAdPlacement.parse(json['interstitial']),
        // A malformed enabled experiment must not silently send control traffic.
        popunder: experimentRequested
            ? null
            : PlaybackAdPlacement.parse(json['popunder']),
        streamFoundExperiment:
            PlaybackAdExperiment.parse(json['stream_found_experiment']),
      );
    } catch (_) {
      return const AdsterraPlaybackAdsConfig();
    }
  }
}

class PlaybackAdExperiment {
  const PlaybackAdExperiment({required this.id, required this.variants});
  final String id;
  final List<PlaybackAdVariant> variants;

  static PlaybackAdExperiment? parse(Object? value) {
    if (value is! Map || value['enabled'] != true) return null;
    final id = value['id'];
    final variants = value['variants'];
    if (!_identifier(id) ||
        variants is! List ||
        variants.length < 2 ||
        variants.length > 8) {
      return null;
    }
    final parsed = <PlaybackAdVariant>[];
    final ids = <String>{};
    for (final variant in variants) {
      if (variant is! Map || !_identifier(variant['id'])) return null;
      final placement = PlaybackAdPlacement.parse(variant);
      if (placement == null || !ids.add(variant['id'] as String)) return null;
      parsed.add(
          PlaybackAdVariant(id: variant['id'] as String, placement: placement));
    }
    return PlaybackAdExperiment(
        id: id as String, variants: List.unmodifiable(parsed));
  }
}

class PlaybackAdVariant {
  const PlaybackAdVariant({required this.id, required this.placement});
  final String id;
  final PlaybackAdPlacement placement;
}

bool _identifier(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value);

class PlaybackAdPlacement {
  const PlaybackAdPlacement({
    this.scriptUrl,
    this.smartlinkUrl,
    this.pageUrl,
    this.loadTimeout = const Duration(seconds: 5),
    this.maxDuration = const Duration(seconds: 30),
    this.subId,
    this.network = AdNetwork.adsterra,
    this.zoneId,
  }) : assert((scriptUrl != null ? 1 : 0) +
                (smartlinkUrl != null ? 1 : 0) +
                (pageUrl != null ? 1 : 0) ==
            1);

  final Uri? scriptUrl;
  final Uri? smartlinkUrl;
  bool get isSmartlink => smartlinkUrl != null;

  /// A page FlixQuest hosts with the network's tags, such as
  /// `https://flix.quest/a/...`, so they run on the site their zone is
  /// registered to. It supplies the same signals as the page the app builds
  /// for [scriptUrl]; Monetag's stream-found tag is activated automatically.
  final Uri? pageUrl;

  String get mode => isSmartlink
      ? 'smartlink'
      : pageUrl != null
          ? 'page'
          : 'script';
  final Duration loadTimeout;
  final Duration maxDuration;
  final String? subId;
  final AdNetwork network;

  /// The zone the onclick tag reads from its script element: Clickadu's
  /// `data-clocid` or Monetag's `data-zone`.
  final String? zoneId;

  Uri? get trackedSmartlinkUrl => smartlinkUrl == null || subId == null
      ? smartlinkUrl
      : smartlinkUrl!.replace(queryParameters: {
          ...smartlinkUrl!.queryParameters,
          'psid': subId!,
        });

  static PlaybackAdPlacement? parse(Object? value,
      {AdNetwork network = AdNetwork.adsterra}) {
    if (value is! Map || value['enabled'] != true) return null;
    final mode = value['mode'] ?? 'script';
    if (mode != 'script' && mode != 'smartlink' && mode != 'page') return null;
    final script = mode == 'script' ? _https(value['script_url']) : null;
    final smartlink = mode == 'smartlink' ? _https(value['url']) : null;
    final page = mode == 'page' ? _https(value['url']) : null;
    if (script == null && smartlink == null && page == null) return null;
    final subId = value['sub_id'];
    if (subId != null &&
        (!_identifier(subId) ||
            smartlink == null ||
            // `psid` is Adsterra's parameter; Clickadu's differs.
            network != AdNetwork.adsterra)) {
      return null;
    }
    // Clickadu's and Monetag's onclick tags read their zone from the script
    // element. Monetag's `/401/<zone>` tag carries it in the URL instead.
    final zone = value['zone_id'];
    final zoneId = zone is int && zone > 0
        ? '$zone'
        : zone is String && RegExp(r'^[0-9]{1,12}$').hasMatch(zone)
            ? zone
            : null;
    if (network == AdNetwork.clickadu && script != null && zoneId == null) {
      return null;
    }
    if (network == AdNetwork.monetag && zone != null && zoneId == null) {
      return null;
    }
    // Legacy `auto_activate` is ignored: the Popunder tag only opens on a real
    // touch, so a programmatic click never produced a popup. Legacy `browser`
    // is ignored too: ad pages always open in FlixQuest's own ad page.
    return PlaybackAdPlacement(
      scriptUrl: script,
      smartlinkUrl: smartlink,
      pageUrl: page,
      subId: subId as String?,
      network: network,
      zoneId: network == AdNetwork.adsterra ? null : zoneId,
      loadTimeout: Duration(
          milliseconds: _bounded(value['load_timeout_ms'], 5000, 500,
              network == AdNetwork.monetag ? 30000 : 10000)),
      maxDuration: Duration(
          seconds: _bounded(value['max_duration_seconds'], 30, 5, 120)),
    );
  }

  static Uri? _https(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            !value.contains(RegExp(r'[<>\s]'))
        ? uri
        : null;
  }

  static int _bounded(Object? value, int fallback, int min, int max) =>
      value is num && value.isFinite ? value.toInt().clamp(min, max) : fallback;
}

/// Clickadu's or Monetag's popup for the stream-found stage: the network's
/// onclick tag (`script`) or a Direct Link (`smartlink`). Missing or malformed
/// values disable it.
class PopunderAdsConfig {
  const PopunderAdsConfig(this.network, {this.enabled = false, this.popunder});

  final AdNetwork network;
  final bool enabled;
  final PlaybackAdPlacement? popunder;

  PlaybackAdPlacement? get activePopunder => enabled ? popunder : null;

  static PopunderAdsConfig parse(String raw,
      {required AdNetwork network, required bool enabled}) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return PopunderAdsConfig(network);
      return PopunderAdsConfig(
        network,
        enabled: enabled,
        popunder: PlaybackAdPlacement.parse(json['popunder'], network: network),
      );
    } catch (_) {
      return PopunderAdsConfig(network);
    }
  }
}
