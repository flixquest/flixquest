import '../models/banner_ad.dart';
import '../video_providers/scraper_api.dart';

/// Shares one `/ads` response between every banner slot on screen, so a Home
/// feed with several slots makes one request, not one per slot.
class HostedAdsRepository {
  HostedAdsRepository._();

  static final HostedAdsRepository instance = HostedAdsRepository._();

  /// A live announcement reaches viewers within minutes of being published.
  static const Duration _ttl = Duration(minutes: 5);

  /// A failed or empty response is retried sooner.
  static const Duration _emptyTtl = Duration(minutes: 1);

  final Map<String, _Entry> _entries = <String, _Entry>{};

  Future<List<BannerAd>> Function(String apiUrl) _fetch =
      (apiUrl) => ScraperApi(apiUrl).getAds();

  Future<List<BannerAd>> load(String apiUrl) {
    final cached = _entries[apiUrl];
    if (cached != null && !cached.isStale) return cached.ads;
    final entry = _Entry(_fetchOrEmpty(apiUrl));
    _entries[apiUrl] = entry;
    entry.ads.then((ads) => entry.ttl = ads.isEmpty ? _emptyTtl : _ttl);
    return entry.ads;
  }

  Future<List<BannerAd>> _fetchOrEmpty(String apiUrl) async {
    try {
      return await _fetch(apiUrl);
    } catch (_) {
      return const <BannerAd>[];
    }
  }

  void clear() => _entries.clear();

  void useFetcherForTesting(
    Future<List<BannerAd>> Function(String apiUrl) fetch,
  ) {
    _fetch = fetch;
    clear();
  }
}

class _Entry {
  _Entry(this.ads);

  final Future<List<BannerAd>> ads;
  final DateTime createdAt = DateTime.now();

  /// Until the request settles the entry is shared as is.
  Duration? ttl;

  bool get isStale =>
      ttl != null && DateTime.now().difference(createdAt) >= ttl!;
}
