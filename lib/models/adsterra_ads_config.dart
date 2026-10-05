import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Dimensions must match the banner code generated in Adsterra's dashboard.
enum AdsterraBannerSize {
  mobile('320x50', 320, 50),
  rectangle('300x250', 300, 250),
  banner('468x60', 468, 60),
  leaderboard('728x90', 728, 90),
  vertical('160x300', 160, 300),
  skyscraper('160x600', 160, 600);

  const AdsterraBannerSize(this.value, this.width, this.height);
  final String value;
  final int width;
  final int height;

  static AdsterraBannerSize? parse(Object? raw) {
    for (final size in values) {
      if (size.value == raw) return size;
    }
    return null;
  }
}

@immutable
class AdsterraBannerUnit {
  const AdsterraBannerUnit({
    required this.key,
    required this.scriptUrl,
    required this.size,
  });

  final String key;
  final Uri scriptUrl;
  final AdsterraBannerSize size;

  static AdsterraBannerUnit? parse(Object? raw) {
    if (raw is! Map || raw['enabled'] == false) return null;
    final key = raw['key'];
    final script = raw['script_url'];
    final size = AdsterraBannerSize.parse(raw['size']);
    if (key is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(key) ||
        script is! String ||
        size == null) {
      return null;
    }
    final uri = Uri.tryParse(script);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    return AdsterraBannerUnit(key: key, scriptUrl: uri, size: size);
  }

  /// An isolated document containing only this placement's generated script.
  /// Never impersonate the ad server's origin with a fabricated base URL.
  String get html {
    // The network removes window.atOptions after reading it. A top-level
    // `var` creates a non-configurable property, which throws on strict delete.
    final options = jsonEncode({
      'key': key,
      'format': 'iframe',
      'width': size.width,
      'height': size.height,
      'params': <String, Object>{},
    });
    final script = const HtmlEscape(HtmlEscapeMode.attribute)
        .convert(scriptUrl.toString());
    return '''<!DOCTYPE html>
<html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;padding:0;overflow:hidden;background:transparent;}
body{width:${size.width}px;height:${size.height}px;}</style>
</head><body>
<script>
window.addEventListener('error', function () {
  AdsterraStatus.postMessage('failed');
});
window.atOptions=$options;
</script>
<script src="$script" onload="AdsterraStatus.postMessage('loaded')"
onerror="AdsterraStatus.postMessage('failed')"></script>
</body></html>''';
  }

  @override
  bool operator ==(Object other) =>
      other is AdsterraBannerUnit &&
      key == other.key &&
      scriptUrl == other.scriptUrl &&
      size == other.size;

  @override
  int get hashCode => Object.hash(key, scriptUrl, size);
}

@immutable
class AdsterraPlacement {
  const AdsterraPlacement({this.enabled = true, this.units = const []});
  final bool enabled;
  final List<String> units;

  @override
  bool operator ==(Object other) =>
      other is AdsterraPlacement &&
      enabled == other.enabled &&
      listEquals(units, other.units);

  @override
  int get hashCode => Object.hash(enabled, Object.hashAll(units));
}

/// One remotely published catalog owns all codes, sizes and placement rules.
/// Empty or invalid configuration never sends requests to an ad network.
@immutable
class AdsterraAdsConfig {
  const AdsterraAdsConfig({
    this.enabled = false,
    this.tvEnabled = false,
    this.units = const {},
    this.defaults = const {},
    this.placements = const {},
  });

  final bool enabled;
  final bool tvEnabled;
  final Map<String, AdsterraBannerUnit> units;
  final Map<String, AdsterraPlacement> defaults;
  final Map<String, AdsterraPlacement> placements;

  factory AdsterraAdsConfig.parse(
    String raw, {
    bool enabled = false,
    bool tvEnabled = false,
  }) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const AdsterraAdsConfig();
      final units = <String, AdsterraBannerUnit>{};
      final rawUnits = json['units'];
      if (rawUnits is Map) {
        for (final entry in rawUnits.entries) {
          final unit = AdsterraBannerUnit.parse(entry.value);
          if (entry.key is String && unit != null) units[entry.key] = unit;
        }
      }
      Map<String, AdsterraPlacement> rules(Object? raw) {
        final result = <String, AdsterraPlacement>{};
        if (raw is! Map) return result;
        for (final entry in raw.entries) {
          if (entry.key is! String) continue;
          final value = entry.value;
          final candidate = value is Map ? value['units'] : value;
          final ids = candidate is String
              ? <String>[candidate]
              : candidate is List
                  ? candidate.whereType<String>().toList()
                  : <String>[];
          result[entry.key] = AdsterraPlacement(
            enabled:
                value != false && (value is! Map || value['enabled'] != false),
            units: List.unmodifiable(ids),
          );
        }
        return Map.unmodifiable(result);
      }

      return AdsterraAdsConfig(
        enabled: enabled,
        tvEnabled: tvEnabled,
        units: Map.unmodifiable(units),
        defaults: rules(json['defaults']),
        placements: rules(json['placements']),
      );
    } catch (_) {
      return const AdsterraAdsConfig();
    }
  }

  AdsterraBannerUnit? resolve(
    String placement, {
    bool tall = false,
    bool television = false,
    double maxWidth = double.infinity,
    double maxHeight = double.infinity,
  }) {
    if (!enabled || (television && !tvEnabled)) return null;
    final name = television ? '${placement}_tv' : placement;
    final variant = '${television ? 'tv_' : ''}${tall ? 'tall' : 'standard'}';
    final rule = placements[name] ?? defaults[variant];
    if (rule == null || !rule.enabled) return null;
    for (final id in rule.units) {
      final unit = units[id];
      if (unit != null &&
          unit.size.width <= maxWidth &&
          unit.size.height <= maxHeight) {
        return unit;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is AdsterraAdsConfig &&
      enabled == other.enabled &&
      tvEnabled == other.tvEnabled &&
      mapEquals(units, other.units) &&
      mapEquals(defaults, other.defaults) &&
      mapEquals(placements, other.placements);

  @override
  int get hashCode => Object.hash(
      enabled,
      tvEnabled,
      Object.hashAllUnordered(
          units.entries.map((e) => Object.hash(e.key, e.value))),
      Object.hashAllUnordered(
          defaults.entries.map((e) => Object.hash(e.key, e.value))),
      Object.hashAllUnordered(
          placements.entries.map((e) => Object.hash(e.key, e.value))));
}
