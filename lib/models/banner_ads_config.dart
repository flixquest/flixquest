import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ad_network.dart';

export 'ad_network.dart';

/// A banner's dimensions in CSS pixels, which are also Flutter logical pixels.
/// They must match the code generated in the network's dashboard.
@immutable
class BannerSize {
  const BannerSize(this.width, this.height);

  final int width;
  final int height;

  String get value => '${width}x$height';

  /// `WxH`, each side between 20 and 1000.
  static BannerSize? parse(Object? raw) {
    if (raw is! String) return null;
    final match = RegExp(r'^([0-9]{2,4})x([0-9]{2,4})$').firstMatch(raw.trim());
    if (match == null) return null;
    final width = int.parse(match[1]!);
    final height = int.parse(match[2]!);
    if (width < 20 || width > 1000 || height < 20 || height > 1000) return null;
    return BannerSize(width, height);
  }

  @override
  bool operator ==(Object other) =>
      other is BannerSize && width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => value;
}

/// One network's banner code at one size.
///
/// Each unit renders as an isolated HTML document holding only that code. The
/// document reports `loaded` once the creative is in, or `failed`, through the
/// [statusChannel] JavaScript channel.
@immutable
abstract class BannerAdUnit {
  const BannerAdUnit();

  static const statusChannel = 'BannerStatus';

  AdNetwork get network;

  /// What identifies the unit in the network's dashboard.
  String get code;

  BannerSize get size;

  String get html;

  /// The document shell every network's code is placed in.
  @protected
  String document(String body) => '''<!DOCTYPE html>
<html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;padding:0;overflow:hidden;background:transparent;}
body{width:${size.width}px;height:${size.height}px;}</style>
</head><body>
<script>
window.addEventListener('error', function () {
  $statusChannel.postMessage('failed');
});
</script>
$body
</body></html>''';
}

/// Adsterra's `atOptions` + `invoke.js` banner.
class AdsterraBannerUnit extends BannerAdUnit {
  const AdsterraBannerUnit({
    required this.key,
    required this.scriptUrl,
    required this.size,
  });

  /// Adsterra's banner formats; each needs its own generated code.
  static const sizes = {
    '320x50',
    '300x250',
    '468x60',
    '728x90',
    '160x300',
    '160x600',
  };

  final String key;
  final Uri scriptUrl;
  @override
  final BannerSize size;

  @override
  AdNetwork get network => AdNetwork.adsterra;

  @override
  String get code => key;

  static AdsterraBannerUnit? parse(Object? raw) {
    if (raw is! Map || raw['enabled'] == false) return null;
    final key = raw['key'];
    final script = _scriptUrl(raw['script_url']);
    final size = BannerSize.parse(raw['size']);
    if (key is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(key) ||
        script == null ||
        !sizes.contains(size?.value)) {
      return null;
    }
    return AdsterraBannerUnit(key: key, scriptUrl: script, size: size!);
  }

  /// Never impersonate the ad server's origin with a fabricated base URL.
  @override
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
    final status = BannerAdUnit.statusChannel;
    return document('''<script>
window.atOptions=$options;
</script>
<script src="$script" onload="$status.postMessage('loaded')"
onerror="$status.postMessage('failed')"></script>''');
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

/// Clickadu's banner: its Main Tag (`bn.js`) and one Ad Spot
/// (`data-cl-spot`). Each banner is its own document, so each carries its own
/// Main Tag, as Clickadu's guide requires for a page with one spot.
class ClickaduBannerUnit extends BannerAdUnit {
  const ClickaduBannerUnit({
    required this.spotId,
    required this.scriptUrl,
    required this.size,
  });

  final String spotId;
  final Uri scriptUrl;
  @override
  final BannerSize size;

  @override
  AdNetwork get network => AdNetwork.clickadu;

  @override
  String get code => spotId;

  /// [scriptUrl] is the catalog's Main Tag, used when the unit names none.
  static ClickaduBannerUnit? parse(Object? raw, {Object? scriptUrl}) {
    if (raw is! Map || raw['enabled'] == false) return null;
    final spot = raw['spot_id'];
    final spotId = spot is int && spot > 0
        ? '$spot'
        : spot is String && RegExp(r'^[0-9]{1,12}$').hasMatch(spot)
            ? spot
            : null;
    final script = _scriptUrl(raw['script_url'] ?? scriptUrl);
    final size = BannerSize.parse(raw['size']);
    if (spotId == null || script == null || size == null) return null;
    return ClickaduBannerUnit(spotId: spotId, scriptUrl: script, size: size);
  }

  /// `bn.js` fills the spot some time after it loads, or never when it has
  /// no ad. Only a creative of visible size counts as loaded, so an unfilled
  /// spot runs into the banner's timeout and collapses.
  @override
  String get html {
    final script = const HtmlEscape(HtmlEscapeMode.attribute)
        .convert(scriptUrl.toString());
    final status = BannerAdUnit.statusChannel;
    return document('''<div data-cl-spot="$spotId"></div>
<script>
(function(){
  var spot=document.querySelector('[data-cl-spot]');
  var poll=setInterval(function(){
    var filled=spot.getBoundingClientRect().height>=20||
      Array.prototype.some.call(document.body.querySelectorAll('iframe,img,video,a,div'),function(el){
        if(el===spot)return false;
        var r=el.getBoundingClientRect();
        return r.width>=20&&r.height>=20;
      });
    if(filled){clearInterval(poll);$status.postMessage('loaded');}
  },500);
})();
</script>
<script async data-cfasync="false" data-clbaid="" src="$script"
onerror="$status.postMessage('failed')"></script>''');
  }

  @override
  bool operator ==(Object other) =>
      other is ClickaduBannerUnit &&
      spotId == other.spotId &&
      scriptUrl == other.scriptUrl &&
      size == other.size;

  @override
  int get hashCode => Object.hash(spotId, scriptUrl, size);
}

Uri? _scriptUrl(Object? raw) {
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return null;
  }
  return uri;
}

@immutable
class BannerPlacement {
  const BannerPlacement({this.enabled = true, this.units = const []});
  final bool enabled;
  final List<String> units;

  @override
  bool operator ==(Object other) =>
      other is BannerPlacement &&
      enabled == other.enabled &&
      listEquals(units, other.units);

  @override
  int get hashCode => Object.hash(enabled, Object.hashAll(units));
}

/// One network's remotely published catalog: all codes, sizes and placement
/// rules. Every network shares this schema; only the unit fields differ.
/// Empty or invalid configuration never sends requests to an ad network.
@immutable
class BannerAdsConfig {
  const BannerAdsConfig({
    required this.network,
    this.enabled = false,
    this.tvEnabled = false,
    this.units = const {},
    this.defaults = const {},
    this.placements = const {},
  });

  final AdNetwork network;
  final bool enabled;
  final bool tvEnabled;
  final Map<String, BannerAdUnit> units;
  final Map<String, BannerPlacement> defaults;
  final Map<String, BannerPlacement> placements;

  factory BannerAdsConfig.parse(
    String raw, {
    required AdNetwork network,
    bool enabled = false,
    bool tvEnabled = false,
  }) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return BannerAdsConfig(network: network);
      final units = <String, BannerAdUnit>{};
      final rawUnits = json['units'];
      if (rawUnits is Map) {
        for (final entry in rawUnits.entries) {
          final unit = switch (network) {
            AdNetwork.adsterra => AdsterraBannerUnit.parse(entry.value),
            AdNetwork.clickadu => ClickaduBannerUnit.parse(entry.value,
                scriptUrl: json['script_url']),
          };
          if (entry.key is String && unit != null) units[entry.key] = unit;
        }
      }
      Map<String, BannerPlacement> rules(Object? raw) {
        final result = <String, BannerPlacement>{};
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
          result[entry.key] = BannerPlacement(
            enabled:
                value != false && (value is! Map || value['enabled'] != false),
            units: List.unmodifiable(ids),
          );
        }
        return Map.unmodifiable(result);
      }

      return BannerAdsConfig(
        network: network,
        enabled: enabled,
        tvEnabled: tvEnabled,
        units: Map.unmodifiable(units),
        defaults: rules(json['defaults']),
        placements: rules(json['placements']),
      );
    } catch (_) {
      return BannerAdsConfig(network: network);
    }
  }

  BannerAdUnit? resolve(
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
      other is BannerAdsConfig &&
      network == other.network &&
      enabled == other.enabled &&
      tvEnabled == other.tvEnabled &&
      mapEquals(units, other.units) &&
      mapEquals(defaults, other.defaults) &&
      mapEquals(placements, other.placements);

  @override
  int get hashCode => Object.hash(
      network,
      enabled,
      tvEnabled,
      Object.hashAllUnordered(
          units.entries.map((e) => Object.hash(e.key, e.value))),
      Object.hashAllUnordered(
          defaults.entries.map((e) => Object.hash(e.key, e.value))),
      Object.hashAllUnordered(
          placements.entries.map((e) => Object.hash(e.key, e.value))));
}
