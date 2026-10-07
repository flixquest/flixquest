/// An ad network FlixQuest can serve ads from.
///
/// Remote Config picks one network per ad format, each with its own selector:
/// `banner_ad_network`, `playback_popunder_network` and `vast_preroll_network`.
/// Every network keeps its codes in its own `<network>_<format>` catalog, so
/// swapping providers is a change of the selector alone.
enum AdNetwork {
  adsterra,
  clickadu;

  /// `none` and unknown values select no network.
  static AdNetwork? parse(String value) {
    final name = value.trim().toLowerCase();
    for (final network in values) {
      if (network.name == name) return network;
    }
    return null;
  }
}
