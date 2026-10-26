import 'common.dart';
import 'names.dart';
import 'scraper_api.dart';
import 'vixsrc.dart';

typedef ProviderLoaderResult = ProviderLoadResult;
typedef ProviderResultCallback = void Function(
  int index,
  VideoProvider provider,
  ProviderLoadResult result,
);

class ProviderSelection {
  const ProviderSelection({
    required this.index,
    required this.provider,
    required this.result,
  });

  final int index;
  final VideoProvider provider;
  final ProviderLoadResult result;
}

/// Single loading boundary for direct and API-backed stream providers.
abstract final class ProviderLoader {
  /// Tries providers one at a time in configured order, starting the next only
  /// after the current provider fails or returns no playable links.
  ///
  /// With [accept], a working provider it rejects is passed over for a later
  /// one it takes; if none is taken, the first working provider is returned.
  static Future<ProviderSelection?> loadFirstSuccessful({
    required List<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider) load,
    ProviderResultCallback? onResult,
    bool Function(ProviderLoadResult result)? accept,
  }) async {
    ProviderSelection? fallback;
    for (var index = 0; index < providers.length; index++) {
      final provider = providers[index];
      ProviderLoadResult result;
      try {
        result = await load(provider);
      } catch (error) {
        result = ProviderLoadResult(errorMessage: error.toString());
      }

      onResult?.call(index, provider, result);
      if (result.success && result.videoLinks?.isNotEmpty == true) {
        final selection = ProviderSelection(
          index: index,
          provider: provider,
          result: result,
        );
        if (accept == null || accept(result)) return selection;
        fallback ??= selection;
      }
    }
    return fallback;
  }

  static Future<ProviderLoaderResult> loadMovieFromProvider({
    required VideoProvider provider,
    required int movieId,
    required String scraperApiUrl,
    bool full = false,
  }) {
    switch (provider.type) {
      case VideoProviderType.directVixSrc:
        return VixSrc.loadMovie(movieId);
      case VideoProviderType.scraperApi:
        final providerId = provider.apiId;
        if (providerId == null || providerId.isEmpty) {
          return Future.value(
            const ProviderLoadResult(errorMessage: 'Provider ID is missing'),
          );
        }
        return ScraperApi(scraperApiUrl).loadMovie(
          providerId: providerId,
          movieId: movieId,
          full: full,
        );
    }
  }

  static Future<ProviderLoaderResult> loadTVFromProvider({
    required VideoProvider provider,
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
    required String scraperApiUrl,
    bool full = false,
  }) {
    switch (provider.type) {
      case VideoProviderType.directVixSrc:
        return VixSrc.loadEpisode(
          tvId: tvId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        );
      case VideoProviderType.scraperApi:
        final providerId = provider.apiId;
        if (providerId == null || providerId.isEmpty) {
          return Future.value(
            const ProviderLoadResult(errorMessage: 'Provider ID is missing'),
          );
        }
        return ScraperApi(scraperApiUrl).loadTVEpisode(
          providerId: providerId,
          tvId: tvId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          full: full,
        );
    }
  }
}
