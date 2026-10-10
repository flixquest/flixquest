import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ad_network.dart';

/// One network's VAST tag and the limits it is requested and played with.
@immutable
class VastPrerollSource {
  const VastPrerollSource({
    required this.network,
    required this.tagUrl,
    this.requestTimeout = const Duration(seconds: 5),
    this.startTimeout = const Duration(seconds: 8),
    this.maxWrappers = 5,
    this.tvEnabled = false,
  });

  final AdNetwork network;

  /// The VAST tag the ad server issued, for example a Clickadu or ExoClick
  /// video zone.
  final Uri tagUrl;

  /// Budget for the tag and every wrapper it redirects to. The next network,
  /// or the content, follows when it runs out.
  final Duration requestTimeout;

  /// How long the ad's video may take to start before the content plays.
  final Duration startTimeout;

  /// Wrapper redirects followed before giving up (VAST error 302).
  final int maxWrappers;

  /// Android TV and other remote-driven surfaces.
  final bool tvEnabled;

  /// A network's section; null without an HTTPS `tag_url`.
  static VastPrerollSource? parse(Map json, AdNetwork network) {
    final tag = _https(json['tag_url']);
    if (tag == null) return null;
    return VastPrerollSource(
      network: network,
      tagUrl: tag,
      requestTimeout: Duration(
          milliseconds:
              _bounded(json['request_timeout_ms'], 5000, 1000, 15000)),
      startTimeout: Duration(
          milliseconds: _bounded(json['start_timeout_ms'], 8000, 2000, 20000)),
      maxWrappers: _bounded(json['max_wrappers'], 5, 0, 10),
      tvEnabled: json['tv_enabled'] == true,
    );
  }

  static Uri? _https(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  static int _bounded(Object? value, int fallback, int min, int max) =>
      value is num && value.isFinite ? value.toInt().clamp(min, max) : fallback;

  @override
  bool operator ==(Object other) =>
      other is VastPrerollSource &&
      other.network == network &&
      other.tagUrl == tagUrl &&
      other.requestTimeout == requestTimeout &&
      other.startTimeout == startTimeout &&
      other.maxWrappers == maxWrappers &&
      other.tvEnabled == tvEnabled;

  @override
  int get hashCode => Object.hash(
      network, tagUrl, requestTimeout, startTimeout, maxWrappers, tvEnabled);
}

/// A VAST video ad played inside the player before the content. Missing or
/// malformed remote values disable it; the tags belong in Remote Config.
@immutable
class VastPrerollConfig {
  const VastPrerollConfig({this.enabled = false, this.sources = const []});

  final bool enabled;

  /// The networks `vast_preroll_network` lists that have a tag, in the order
  /// they are asked. The first one that returns a playable ad plays it.
  final List<VastPrerollSource> sources;

  bool get isActive => enabled && sources.isNotEmpty;

  /// The networks asked on this surface, in priority order.
  List<VastPrerollSource> sourcesFor({required bool television}) => enabled
      ? [
          for (final source in sources)
            if (!television || source.tvEnabled) source
        ]
      : const [];

  bool appliesTo({required bool television}) =>
      sourcesFor(television: television).isNotEmpty;

  /// Each network keeps its tag and limits under its own name, for example
  /// `{"clickadu": {"tag_url": ...}, "exoclick": {"tag_url": ...}}`, and
  /// [networks] (from `vast_preroll_network`) picks them in priority order.
  /// A listed network without a section is passed over. A flat catalog
  /// without sections serves the first listed network. An empty list
  /// (`none`) plays no pre-roll.
  static VastPrerollConfig parse(String raw,
      {required bool enabled, required List<AdNetwork> networks}) {
    try {
      if (networks.isEmpty) return const VastPrerollConfig();
      final catalog = jsonDecode(raw);
      if (catalog is! Map<String, dynamic>) return const VastPrerollConfig();
      final flat = !networks.any((network) => catalog[network.name] is Map) &&
          catalog['tag_url'] != null;
      final sources = <VastPrerollSource>[];
      for (final network in flat ? networks.take(1) : networks) {
        final section = flat ? catalog : catalog[network.name];
        final source =
            section is Map ? VastPrerollSource.parse(section, network) : null;
        if (source != null) sources.add(source);
      }
      return VastPrerollConfig(
          enabled: enabled, sources: List.unmodifiable(sources));
    } catch (_) {
      return const VastPrerollConfig();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is VastPrerollConfig &&
      other.enabled == enabled &&
      listEquals(other.sources, sources);

  @override
  int get hashCode => Object.hash(enabled, Object.hashAll(sources));
}
