import 'dart:convert';

import 'ad_network.dart';

/// A VAST video ad played inside the player before the content. Missing or
/// malformed remote values disable it; the tag belongs in Remote Config.
class VastPrerollConfig {
  const VastPrerollConfig({
    this.enabled = false,
    this.network,
    this.tagUrl,
    this.requestTimeout = const Duration(seconds: 5),
    this.startTimeout = const Duration(seconds: 8),
    this.maxWrappers = 5,
    this.tvEnabled = false,
  });

  final bool enabled;

  /// The network `vast_preroll_network` selected.
  final AdNetwork? network;

  /// The VAST tag the ad server issued, for example a Clickadu video zone.
  final Uri? tagUrl;

  /// Budget for the tag and every wrapper it redirects to. Playback starts
  /// without an ad when it runs out.
  final Duration requestTimeout;

  /// How long the ad's video may take to start before the content plays.
  final Duration startTimeout;

  /// Wrapper redirects followed before giving up (VAST error 302).
  final int maxWrappers;

  /// Android TV and other remote-driven surfaces.
  final bool tvEnabled;

  bool get isActive => enabled && tagUrl != null;

  bool appliesTo({required bool television}) =>
      isActive && (!television || tvEnabled);

  /// Each network keeps its tag and limits under its own name, for example
  /// `{"clickadu": {"tag_url": ...}}`, and [network] picks one. A flat
  /// catalog without sections serves whichever network is selected. A null
  /// [network] (`none`) plays no pre-roll.
  static VastPrerollConfig parse(String raw,
      {required bool enabled, required AdNetwork? network}) {
    try {
      if (network == null) return const VastPrerollConfig();
      final catalog = jsonDecode(raw);
      if (catalog is! Map<String, dynamic>) return const VastPrerollConfig();
      final section = catalog[network.name];
      final json = section is Map ? section : catalog;
      final tag = _https(json['tag_url']);
      if (tag == null) return const VastPrerollConfig();
      return VastPrerollConfig(
        enabled: enabled,
        network: network,
        tagUrl: tag,
        requestTimeout: Duration(
            milliseconds:
                _bounded(json['request_timeout_ms'], 5000, 1000, 15000)),
        startTimeout: Duration(
            milliseconds:
                _bounded(json['start_timeout_ms'], 8000, 2000, 20000)),
        maxWrappers: _bounded(json['max_wrappers'], 5, 0, 10),
        tvEnabled: json['tv_enabled'] == true,
      );
    } catch (_) {
      return const VastPrerollConfig();
    }
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
      other is VastPrerollConfig &&
      other.enabled == enabled &&
      other.network == network &&
      other.tagUrl == tagUrl &&
      other.requestTimeout == requestTimeout &&
      other.startTimeout == startTimeout &&
      other.maxWrappers == maxWrappers &&
      other.tvEnabled == tvEnabled;

  @override
  int get hashCode => Object.hash(enabled, network, tagUrl, requestTimeout,
      startTimeout, maxWrappers, tvEnabled);
}
