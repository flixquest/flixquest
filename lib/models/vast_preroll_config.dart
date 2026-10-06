import 'dart:convert';

/// A VAST video ad played inside the player before the content. Missing or
/// malformed remote values disable it; the tag belongs in Remote Config.
class VastPrerollConfig {
  const VastPrerollConfig({
    this.enabled = false,
    this.tagUrl,
    this.requestTimeout = const Duration(seconds: 5),
    this.startTimeout = const Duration(seconds: 8),
    this.maxWrappers = 5,
    this.tvEnabled = false,
  });

  final bool enabled;

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

  static VastPrerollConfig parse(String raw, {required bool enabled}) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const VastPrerollConfig();
      final tag = _https(json['tag_url']);
      if (tag == null) return const VastPrerollConfig();
      return VastPrerollConfig(
        enabled: enabled,
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
      other.tagUrl == tagUrl &&
      other.requestTimeout == requestTimeout &&
      other.startTimeout == startTimeout &&
      other.maxWrappers == maxWrappers &&
      other.tvEnabled == tvEnabled;

  @override
  int get hashCode => Object.hash(
      enabled, tagUrl, requestTimeout, startTimeout, maxWrappers, tvEnabled);
}
