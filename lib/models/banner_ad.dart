class BannerAd {
  const BannerAd({
    required this.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.targetUrl,
    required this.altText,
    this.shape = 'rectangle',
    this.aspectRatio = 2.2,
    this.placements = const [],
    this.width,
    this.height,
  });

  final String key;
  final String id;
  final String name;
  final String imageUrl;
  final String targetUrl;
  final String altText;
  final String shape;
  final double aspectRatio;
  final List<String> placements;
  final double? width;
  final double? height;

  /// Whether the backend targets this ad at [placement].
  ///
  /// Phones and tablets match an explicit placement, or every placement when
  /// the ad lists none. Android TV only matches its own `<placement>_tv` name
  /// (the tag Start.io uses there), so a phone announcement never lands on a
  /// television by accident.
  bool appliesTo(String placement, {bool television = false}) {
    if (television) return placements.contains('${placement}_tv');
    return placements.isEmpty || placements.contains(placement);
  }

  factory BannerAd.fromJson(Map<String, dynamic> json) {
    return BannerAd(
      key: json['key']?.toString() ?? json['id']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      targetUrl: json['targetUrl']?.toString() ?? '',
      altText: json['altText']?.toString() ?? '',
      shape: json['shape']?.toString() ?? 'rectangle',
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 2.2,
      placements: (json['placements'] is List)
          ? (json['placements'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const [],
    );
  }
}

/// How the hosted (`/ads`) banner shares a slot with the Start.io banner.
enum HostedBannerMode {
  /// Hosted banners never show.
  off,

  /// The hosted banner sits above the Start.io banner in the same slot.
  stack,

  /// A live hosted banner takes the slot from Start.io; slots with no hosted
  /// ad keep their Start.io banner.
  priority;

  static HostedBannerMode parse(String raw) {
    final value = raw.trim().toLowerCase();
    return HostedBannerMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => HostedBannerMode.stack,
    );
  }
}

class BannerDisplayConfig {
  const BannerDisplayConfig({
    required this.key,
    this.enabled = true,
    this.placements = const [],
    this.shape,
    this.width,
    this.height,
    this.aspectRatio,
  });

  final String key;
  final bool enabled;
  final List<String> placements;
  final String? shape;
  final double? width;
  final double? height;
  final double? aspectRatio;

  factory BannerDisplayConfig.fromJson(String key, Map<String, dynamic> json) {
    final rawPlacements = json['placements'];
    return BannerDisplayConfig(
      key: key,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      placements: rawPlacements is List
          ? rawPlacements.whereType<String>().toList(growable: false)
          : const [],
      shape: json['shape']?.toString(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
    );
  }

  bool appliesTo(String placement) =>
      placements.isEmpty || placements.contains(placement);
}
