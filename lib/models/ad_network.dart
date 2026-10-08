/// An ad network FlixQuest can serve ads from.
///
/// Remote Config picks the network per ad format, each with its own selector:
/// `banner_ad_network`, `playback_popunder_network` and `vast_preroll_network`
/// (which may list several networks in priority order). Every network keeps
/// its codes in its own `<network>_<format>` catalog or section, so swapping
/// providers is a change of the selector alone.
enum AdNetwork {
  adsterra,
  clickadu,

  /// Popup only (stream-found stage); it has no banner or VAST formats here.
  monetag,

  /// Video pre-roll (VAST) only.
  exoclick;

  /// `none` and unknown values select no network.
  static AdNetwork? parse(String value) {
    final name = value.trim().toLowerCase();
    for (final network in values) {
      if (network.name == name) return network;
    }
    return null;
  }

  /// A comma-separated priority list such as `exoclick,clickadu`. Unknown
  /// names and repeats are dropped, so `none` or an empty value is empty.
  static List<AdNetwork> parseList(String value) {
    final networks = <AdNetwork>[];
    for (final name in value.split(',')) {
      final network = parse(name);
      if (network != null && !networks.contains(network)) {
        networks.add(network);
      }
    }
    return List.unmodifiable(networks);
  }
}
