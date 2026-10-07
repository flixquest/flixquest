import 'dart:convert';

enum PlaybackAdStage { beforeLoader, streamFound }

/// The ad network behind a playback placement. Remote Config selects which
/// one serves the stream-found popup (`playback_popunder_network`).
enum PlaybackAdNetwork {
  adsterra,
  clickadu;

  /// `none` and unknown values select no network.
  static PlaybackAdNetwork? parse(String value) =>
      switch (value.trim().toLowerCase()) {
        'adsterra' => adsterra,
        'clickadu' => clickadu,
        _ => null,
      };
}

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
    this.loadTimeout = const Duration(seconds: 5),
    this.maxDuration = const Duration(seconds: 30),
    this.subId,
    this.network = PlaybackAdNetwork.adsterra,
    this.zoneId,
  }) : assert((scriptUrl == null) != (smartlinkUrl == null));

  final Uri? scriptUrl;
  final Uri? smartlinkUrl;
  bool get isSmartlink => smartlinkUrl != null;
  final Duration loadTimeout;
  final Duration maxDuration;
  final String? subId;
  final PlaybackAdNetwork network;

  /// Clickadu's zone, passed to its onclick tag as `data-clocid`.
  final String? zoneId;

  Uri? get trackedSmartlinkUrl => smartlinkUrl == null || subId == null
      ? smartlinkUrl
      : smartlinkUrl!.replace(queryParameters: {
          ...smartlinkUrl!.queryParameters,
          'psid': subId!,
        });

  static PlaybackAdPlacement? parse(Object? value,
      {PlaybackAdNetwork network = PlaybackAdNetwork.adsterra}) {
    if (value is! Map || value['enabled'] != true) return null;
    final mode = value['mode'] ?? 'script';
    if (mode != 'script' && mode != 'smartlink') return null;
    final script = mode == 'script' ? _https(value['script_url']) : null;
    final smartlink = mode == 'smartlink' ? _https(value['url']) : null;
    if (script == null && smartlink == null) return null;
    final subId = value['sub_id'];
    if (subId != null &&
        (!_identifier(subId) ||
            smartlink == null ||
            // `psid` is Adsterra's parameter; Clickadu's differs.
            network != PlaybackAdNetwork.adsterra)) {
      return null;
    }
    // Clickadu's onclick tag reads its zone from the script element.
    final zone = value['zone_id'];
    final zoneId = zone is int && zone > 0
        ? '$zone'
        : zone is String && RegExp(r'^[0-9]{1,12}$').hasMatch(zone)
            ? zone
            : null;
    if (network == PlaybackAdNetwork.clickadu &&
        script != null &&
        zoneId == null) {
      return null;
    }
    // Legacy `auto_activate` is ignored: the Popunder tag only opens on a real
    // touch, so a programmatic click never produced a popup. Legacy `browser`
    // is ignored too: ad pages always open in FlixQuest's own ad page.
    return PlaybackAdPlacement(
      scriptUrl: script,
      smartlinkUrl: smartlink,
      subId: subId as String?,
      network: network,
      zoneId: network == PlaybackAdNetwork.clickadu ? zoneId : null,
      loadTimeout: Duration(
          milliseconds: _bounded(value['load_timeout_ms'], 5000, 500, 10000)),
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

/// Clickadu's popup for the stream-found stage: its onclick tag (`script`) or
/// a Direct Link (`smartlink`). Missing or malformed values disable it.
class ClickaduPlaybackAdsConfig {
  const ClickaduPlaybackAdsConfig({this.enabled = false, this.popunder});

  final bool enabled;
  final PlaybackAdPlacement? popunder;

  PlaybackAdPlacement? get activePopunder => enabled ? popunder : null;

  static ClickaduPlaybackAdsConfig parse(String raw, {required bool enabled}) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return const ClickaduPlaybackAdsConfig();
      }
      return ClickaduPlaybackAdsConfig(
        enabled: enabled,
        popunder: PlaybackAdPlacement.parse(json['popunder'],
            network: PlaybackAdNetwork.clickadu),
      );
    } catch (_) {
      return const ClickaduPlaybackAdsConfig();
    }
  }
}
