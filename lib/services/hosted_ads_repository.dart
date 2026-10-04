import '../models/banner_ad.dart';
import '../legacy/scraper_ads_fetcher.dart';
import '../data/repositories/ads_repository.dart';

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
      (apiUrl) => ScraperAdsFetcher().load(apiUrl);

  AdsRepository? _laravel;
  bool get telemetryEnabled => _laravel != null;

  void configure(AdsRepository repository, {required bool enabled}) {
    _laravel = enabled ? repository : null;
    _fetch = (apiUrl) => ScraperAdsFetcher().load(apiUrl);
    clear();
  }

  Future<void> reportImpression(String id) async => await _laravel?.reportImpression(id);
  Future<void> reportClick(String id) async => await _laravel?.reportClick(id);

  Future<List<BannerAd>> load(String apiUrl) {
    if (_laravel != null) return _laravel!.load();
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
    _laravel = null;
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
