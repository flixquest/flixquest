import 'package:flixquest/models/adsterra_playback_ads_config.dart';
import 'package:flixquest/data/ads/content_ads.dart';
import 'package:flixquest/services/adsterra_playback_ads_service.dart';
import 'package:flixquest/widgets/ad_block_gate.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flixquest/functions/function.dart';
import 'package:flixquest/functions/network.dart';
import 'package:flixquest/functions/video_utils.dart';
import 'package:flixquest/functions/player_route_handoff.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flixquest/models/movie_stream_metadata.dart';
import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/models/provider_video_source.dart';
import 'package:flixquest/models/provider_load_state.dart';
import 'package:flixquest/services/globle_method.dart';
import 'package:flixquest/services/offline_download_service.dart';
import 'package:flixquest/widgets/playback_loading_screen.dart';
import 'package:flixquest/services/stream_size_estimator.dart';
import 'package:flixquest/video_providers/provider_loader.dart';
import 'package:flixquest/video_providers/scraper_api.dart';
import '../../controllers/recently_watched_database_controller.dart';
import '../../provider/recently_watched_provider.dart';
import '../../video_providers/common.dart';
import '../../video_providers/names.dart';
import '/api/endpoints.dart';
import '/constants/api_constants.dart';
import '/provider/offline_download_provider.dart';
import '/provider/app_dependency_provider.dart';
import '/provider/settings_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player.dart';
import '../../widgets/common_widgets.dart';
import 'package:flixquest/constants/app_constants.dart' show MediaType;

import 'package:flutter/material.dart';
import '../../screens/common/player.dart';
import '../../screens/common/download_selection_sheets.dart';
import '../../screens/common/manual_source_picker.dart';
import '../../tv/player/tv_player_screen.dart';

/// Finds a stream for a movie. A Kids or Family movie's loader, and the
/// player it opens, are in its [ContentAdScope]: no ad is asked for.
class MovieVideoLoader extends StatelessWidget {
  const MovieVideoLoader(
      {required this.metadata,
      required this.download,
      this.useTvPlayer = false,
      this.onTvPlayerExit,
      this.adStage = PlaybackAdStage.streamFound,
      super.key});

  final MovieStreamMetadata metadata;
  final bool download;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;
  final PlaybackAdStage adStage;

  @override
  Widget build(BuildContext context) {
    final loader = _MovieVideoLoader(
        metadata: metadata,
        download: download,
        useTvPlayer: useTvPlayer,
        onTvPlayerExit: onTvPlayerExit,
        adStage: adStage);
    final id = metadata.movieId;
    if (id == null) return loader;
    return ContentAdGate(
      content: AdContent(series: false, id: id, genreIds: metadata.genreIds),
      holdChild: true,
      child: loader,
    );
  }
}

class _MovieVideoLoader extends StatefulWidget {
  const _MovieVideoLoader(
      {required this.download,
      required this.metadata,
      this.useTvPlayer = false,
      this.onTvPlayerExit,
      this.adStage = PlaybackAdStage.streamFound});

  final bool download;
  final MovieStreamMetadata metadata;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;

  /// The popup once a source is found: [PlaybackAdStage.episodeSwitch] or
  /// [PlaybackAdStage.movieSwitch] when the player itself started this load.
  final PlaybackAdStage adStage;

  @override
  State<_MovieVideoLoader> createState() => _MovieVideoLoaderState();
}

class _MovieVideoLoaderState extends State<_MovieVideoLoader> {
  RecentlyWatchedMoviesController recentlyWatchedMoviesController =
      RecentlyWatchedMoviesController();

  List<RegularVideoLinks>? movieVideoLinks;
  List<RegularSubtitleLinks>? movieVideoSubs;

  late SettingsProvider settings =
      Provider.of<SettingsProvider>(context, listen: false);
  List<VideoProvider> videoProviders = [];
  List<ProviderLoadState> providerStates = [];
  final Map<String, Stopwatch> _providerStopwatches = {};
  int currentProviderIndex = 0;
  String _scraperApiUrl = '';
  final Map<String, int?> _streamSizeCacheByToken = {};
  PlaybackAdPreload? _adPreload;

  Map<String, String> videos = {};
  List<BetterPlayerSubtitlesSource> subs = [];

  // Collect all working providers
  List<ProviderVideoSource> availableProviders = [];

  late int foundIndex;

  /// The metadata this loader was built for, captured once. Route builders run
  /// again whenever route dependencies change, and callers construct a fresh
  /// [MovieStreamMetadata] inside them; swapping to that empty copy mid-flight
  /// would drop the fetched recommendations the player needs.
  late final MovieStreamMetadata _metadata;

  @override
  void initState() {
    super.initState();
    _metadata = widget.metadata;
    debugPrint(
      '[MovieRecommendationsDebug][LOADER_INIT] '
      'movieId=${_metadata.movieId} '
      'title=${_metadata.movieName} '
      'existingRecommendations=${_metadata.recommendations?.length ?? 0} '
      'download=${widget.download} useTvPlayer=${widget.useTvPlayer}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPlayback());
  }

  Future<void> _startPlayback() async {
    if (!mounted) return;
    if (!await AdBlockGate.instance.allowPlayback(context,
        download: widget.download, television: widget.useTvPlayer)) {
      if (mounted) Navigator.pop(context, false);
      return;
    }
    if (!mounted) return;
    _adPreload = AdsterraPlaybackAdsService.instance.preloadStreamFound(context,
        download: widget.download,
        television: widget.useTvPlayer,
        stage: widget.adStage);
    try {
      await loadVideo();
    } finally {
      _adPreload?.dispose();
    }
  }

  @override
  void dispose() {
    _adPreload?.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    _scraperApiUrl = Provider.of<AppDependencyProvider>(context, listen: false)
        .flixquestAPIURL;
    final providers = <VideoProvider>[];
    try {
      providers.addAll(await ScraperApi(_scraperApiUrl).getProviders());
    } catch (error) {
      debugPrint('Unable to load scraper providers: $error');
    }

    // Keep the app's existing VixSrc implementation as an independent source,
    // even if the scraper API also exposes a provider named "vixsrc". The
    // user's configured order from "Change Providers Order" is respected as-is.
    providers.add(VideoProvider.directVixSrc);
    final orderedProviders = settings.orderStreamProviders(providers);
    if (!mounted) return;
    setState(() {
      videoProviders = orderedProviders;
      providerStates = orderedProviders
          .map(
            (provider) => ProviderLoadState(
              codeName: provider.codeName,
              fullName: provider.displayName,
              content: provider.content,
              status: ProviderStatus.pending,
            ),
          )
          .toList();
    });
  }

  Future<void> loadVideo() async {
    if (!mounted) return;
    try {
      await _loadProviders();
      VideoProvider? selectedDownloadProvider;
      int? downloadHeight;
      if (widget.download) {
        if (!mounted) return;
        downloadHeight =
            await DownloadSelectionSheets.preferredQuality(context, settings);
        if (!mounted) return;
        if (downloadHeight == null) {
          settings.analytics.trackDownload(
            action: 'quality_selection',
            mediaType: 'movie',
            outcome: 'cancelled',
          );
          Navigator.pop(context, false);
          return;
        }
        if (downloadHeight == SettingsProvider.downloadQualityAsk) {
          downloadHeight = null;
        }
      }
      if (widget.download && downloadHeight == null) {
        selectedDownloadProvider = await DownloadSelectionSheets.showProvider(
          context,
          providers: videoProviders,
        );
        if (!mounted) return;
        if (selectedDownloadProvider == null) {
          settings.analytics.trackDownload(
            action: 'provider_selection',
            mediaType: 'movie',
            outcome: 'cancelled',
          );
          Navigator.pop(context, false);
          return;
        }
        setState(() {
          currentProviderIndex = videoProviders.indexWhere(
            (provider) =>
                provider.codeName == selectedDownloadProvider!.codeName,
          );
        });
      }
      // The player's recommendations are not needed until it opens, so fetch
      // them alongside source loading instead of in front of it. Downloads
      // never open the player.
      final recommendationsFetch =
          widget.download ? null : _fetchMovieRecommendations();

      var isBookmarked =
          await recentlyWatchedMoviesController.contain(_metadata.movieId!);
      int elapsed = 0;
      if (isBookmarked) {
        var rMovies =
            Provider.of<RecentProvider>(context, listen: false).movies;
        int index =
            rMovies.indexWhere((element) => element.id == _metadata.movieId);
        // A cloud merge can add the row to the database before this snapshot of
        // the provider list catches up, so resume from the start if it is not
        // here yet rather than indexing past the end.
        if (index != -1) {
          setState(() {
            elapsed = rMovies[index].elapsed!;
          });
        }
        _metadata.elapsed = elapsed;
      } else {
        _metadata.elapsed = 0;
      }

      final isUnreleased =
          _metadata.releaseDate != null && !isReleased(_metadata.releaseDate!);
      if (isUnreleased) {
        GlobalMethods.showScaffoldMessage(
            tr('movie_may_not_be_available'), context);
      }

      final manualPickRequired = !widget.download && !settings.autoLoadSources;

      ProviderSelection? selection;
      if (manualPickRequired) {
        // "Auto load sources" is off: let the user pick a provider and only
        // fetch that one. Re-prompt after a failed attempt so they can simply
        // choose another source.
        while (true) {
          if (!mounted) return;
          final picked = await showPlaybackProviderPicker(
            context: context,
            providers: videoProviders,
            useTvPlayer: widget.useTvPlayer,
          );
          if (!mounted) return;
          if (picked == null) {
            // Dismissed the picker: leave without playing anything.
            Navigator.pop(context);
            return;
          }
          selection = await _fetchSelection(providers: [picked]);
          if (selection != null || !mounted) break;
        }
      } else {
        // Try sources one at a time until one returns playable links.
        // A download with a preferred quality goes to the first provider in
        // order that has it.
        final height = downloadHeight;
        selection = await _fetchSelection(
          providers: selectedDownloadProvider == null
              ? videoProviders
              : [selectedDownloadProvider],
          accept: height == null
              ? null
              : (result) =>
                  VideoUtils.downloadSource(
                    VideoUtils.convertVideoLinksToMap(result.videoLinks!),
                    height,
                  )?.exact ==
                  true,
        );
      }

      if (selection != null) {
        if (!await AdsterraPlaybackAdsService.instance.streamFound(context,
                download: widget.download,
                television: widget.useTvPlayer,
                preload: _adPreload,
                stage: widget.adStage) ||
            !mounted) {
          return;
        }
      }
      final firstWorkingProviderCode = selection?.provider.codeName;
      if (selection != null) {
        _showSelectedProvider(selection.provider);
        final result = selection.result;
        videos = VideoUtils.convertVideoLinksToMap(result.videoLinks!);
        movieVideoLinks = result.videoLinks;
        movieVideoSubs = result.subtitleLinks;
        _addSubtitles(result.subtitleLinks);
      }

      // Check if we found a working provider
      if (firstWorkingProviderCode == null && mounted) {
        _showErrorSheet(tr('movie_vid_404'));
        return;
      }

      // Prepare final video map (reversed for quality ordering)
      Map<String, String> reversedVids =
          VideoUtils.reverseVideoQualityMap(videos);
      final videoFormats = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoFormatsToMap(movieVideoLinks ?? const []),
      );
      final videoHeaders = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoHeadersToMap(movieVideoLinks ?? const []),
      );
      final videoSizeTokens = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoSizeTokensToMap(movieVideoLinks ?? const []),
      );

      if (firstWorkingProviderCode != null && mounted) {
        if (widget.download) {
          await _enqueueDownload(
            sources: reversedVids,
            videoFormats: videoFormats,
            videoHeaders: videoHeaders,
            videoSizeTokens: videoSizeTokens,
            providerName: selection?.provider.displayName,
            downloadProvider: selection?.provider,
            preferredHeight: downloadHeight,
          );
          return;
        }
        if (!isUnreleased) {
          Provider.of<SettingsProvider>(context, listen: false)
              .analytics
              .trackMovieWatched(
                movieName: _metadata.movieName,
                movieId: _metadata.movieId,
                isAdult: _metadata.isAdult ?? 'unknown',
              );
        }

        await recommendationsFetch;
        if (!mounted) return;

        // Navigate to player with provider list for lazy loading
        debugPrint(
          '[MovieRecommendationsDebug][PLAYER_HANDOFF] '
          'movieId=${_metadata.movieId} '
          'title=${_metadata.movieName} '
          'recommendations=${_metadata.recommendations?.length ?? 0} '
          'recommendationIds=${_metadata.recommendations?.map((movie) => movie.movieId).join(',') ?? 'none'}',
        );
        handoffLoaderToPlayer<void>(
          context,
          (context) {
            debugPrint(
              '[MovieRecommendationsDebug][PLAYER_CREATED] '
              'movieId=${_metadata.movieId} '
              'recommendations=${_metadata.recommendations?.length ?? 0} '
              'recommendationsNull=${_metadata.recommendations == null} '
              'useTvPlayer=${widget.useTvPlayer}',
            );
            final player = PlayerOne(
              mediaType: MediaType.movie,
              sources: reversedVids,
              subs: subs,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).colorScheme.surface
              ],
              settings: settings,
              movieMetadata: _metadata,
              availableProviders:
                  videoProviders, // Pass provider list for lazy loading
              currentProviderCode: firstWorkingProviderCode, // Current provider
              scraperApiUrl: _scraperApiUrl,
              videoFormats: videoFormats,
              videoHeaders: videoHeaders,
              videoSizeTokens: videoSizeTokens,
              initialVideoLinks: movieVideoLinks ?? const [],
              subtitleStyle:
                  Provider.of<SettingsProvider>(context).subtitleTextStyle,
              useTvControls: widget.useTvPlayer,
              onTvPlayerExit: widget.onTvPlayerExit,
            );
            return widget.useTvPlayer ? TvPlayerScreen(child: player) : player;
          },
        );
      } else {
        if (mounted) {
          _showErrorSheet(tr('movie_vid_404'));
        }
      }
    } on Exception catch (e) {
      debugPrint('[MovieVideoLoader] Exception loading video: $e');
      if (mounted) {
        _showErrorSheet(tr('movie_vid_404'));
      }
    }
  }

  /// Focus the carousel on the first provider still being fetched so the
  /// highlight does not linger on a provider that just failed or succeeded.
  int _firstLoadingProviderIndex() {
    for (var index = 0; index < providerStates.length; index++) {
      if (providerStates[index].status == ProviderStatus.loading) {
        return index;
      }
    }
    return currentProviderIndex;
  }

  /// Shows [provider] as the one selected for playback.
  void _showSelectedProvider(VideoProvider provider) {
    if (!mounted) return;
    setState(() {
      currentProviderIndex = videoProviders.indexWhere(
        (candidate) => candidate.codeName == provider.codeName,
      );
    });
  }

  /// Tries [providers] in configured order until one returns playable links.
  Future<ProviderSelection?> _fetchSelection({
    required List<VideoProvider> providers,
    bool Function(ProviderLoaderResult result)? accept,
  }) {
    return ProviderLoader.loadFirstSuccessful(
      providers: providers,
      accept: accept,
      load: (provider) {
        _providerStopwatches[provider.codeName] = Stopwatch()..start();
        // Only the current provider shows as loading; the rest wait their turn.
        if (mounted) {
          setState(() {
            final providerIndex = providerStates.indexWhere(
              (state) => state.codeName == provider.codeName,
            );
            if (providerIndex != -1) {
              providerStates[providerIndex] = providerStates[providerIndex]
                  .copyWith(status: ProviderStatus.loading);
            }
            currentProviderIndex = _firstLoadingProviderIndex();
          });
        }
        debugPrint(
          '[MovieVideoLoader] Request provider=${provider.displayName} '
          '(${provider.codeName}), tmdbId=${_metadata.movieId}',
        );
        return ProviderLoader.loadMovieFromProvider(
          provider: provider,
          movieId: _metadata.movieId!,
          scraperApiUrl: _scraperApiUrl,
        );
      },
      onResult: (index, provider, result) {
        final durationMs = _providerStopwatches
                .remove(provider.codeName)
                ?.elapsedMilliseconds ??
            0;
        final providerSucceeded =
            result.success && result.videoLinks?.isNotEmpty == true;
        settings.analytics.trackProviderAttempt(
          mediaType: 'movie',
          contentId: _metadata.movieId,
          contentTitle: _metadata.movieName,
          provider: provider.displayName,
          purpose: widget.download ? 'download' : 'playback',
          success: providerSucceeded,
          durationMs: durationMs,
          sourceCount: result.videoLinks?.length ?? 0,
          subtitleCount: result.subtitleLinks?.length ?? 0,
          error: result.errorMessage,
        );
        final providerIndex = videoProviders.indexWhere(
          (candidate) => candidate.codeName == provider.codeName,
        );
        debugPrint(
          '[MovieVideoLoader] Response provider=${provider.displayName} '
          'success=${result.success}, links=${result.videoLinks?.length ?? 0}, '
          'subtitles=${result.subtitleLinks?.length ?? 0}, error=${result.errorMessage}',
        );
        if (mounted) {
          setState(() {
            providerStates[providerIndex] =
                providerStates[providerIndex].copyWith(
              status: providerSucceeded
                  ? ProviderStatus.success
                  : ProviderStatus.failed,
              errorMessage: result.errorMessage,
            );
            currentProviderIndex = _firstLoadingProviderIndex();
          });
        }
      },
    );
  }

  /// Leaves the loader screen and reports the failure in a bottom sheet that
  /// can push a fresh loader when the user retries.
  void _showErrorSheet(String message) {
    final navigator = Navigator.of(context);
    final metadata = _metadata;
    final download = widget.download;
    final useTvPlayer = widget.useTvPlayer;
    final onTvPlayerExit = widget.onTvPlayerExit;
    final adStage = widget.adStage;
    navigator.pop();
    ReportErrorWidget.show(
      navigator.context,
      error: message,
      onRetry: () => navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MovieVideoLoader(
            metadata: metadata,
            download: download,
            useTvPlayer: useTvPlayer,
            onTvPlayerExit: onTvPlayerExit,
            adStage: adStage,
          ),
        ),
      ),
    );
  }

  Future<void> _enqueueDownload({
    required Map<String, String> sources,
    required Map<String, BetterPlayerVideoFormat?> videoFormats,
    required Map<String, Map<String, String>> videoHeaders,
    required Map<String, String> videoSizeTokens,
    String? providerName,
    VideoProvider? downloadProvider,
    int? preferredHeight,
  }) async {
    final quality = preferredHeight == null
        ? await _askResolution(sources, videoSizeTokens, providerName)
        : _preferredResolution(sources, preferredHeight);
    if (!mounted) return;
    if (quality == null) {
      settings.analytics.trackDownload(
        action: 'resolution_selection',
        mediaType: 'movie',
        outcome: 'cancelled',
        provider: providerName,
      );
      Navigator.pop(context, false);
      return;
    }
    final url = sources[quality]!;
    final declaredFormat = videoFormats[quality];
    final format = declaredFormat == BetterPlayerVideoFormat.dash
        ? 'dash'
        : declaredFormat == BetterPlayerVideoFormat.hls
            ? 'hls'
            : url.toLowerCase().contains('.mpd')
                ? 'dash'
                : 'hls';
    // An adaptive stream has no height of its own; the preference caps it.
    final maxVideoHeight = _qualityHeight(quality) ??
        (preferredHeight != null && preferredHeight > 0
            ? preferredHeight
            : null);
    final posterPath = _metadata.posterPath;
    final subtitleTrack = _preferredSubtitle(movieVideoSubs);
    try {
      final downloadHeaders = videoHeaders[quality] ??
          VideoUtils.inferVideoHeaders(url) ??
          const <String, String>{};
      final audioSelection = await DownloadSelectionSheets.chooseAudio(
        context,
        tracks: OfflineDownloadService.instance.getAudioTracks(
          url: url,
          format: format,
          headers: downloadHeaders,
          maxVideoHeight: maxVideoHeight,
        ),
      );
      if (!mounted) return;
      if (audioSelection == null) {
        Navigator.pop(context, false);
        return;
      }
      await context.read<OfflineDownloadProvider>().enqueue(
            OfflineDownloadRequest(
              id: 'movie_${_metadata.movieId}',
              url: url,
              format: format,
              title: _metadata.movieName ?? 'Movie',
              subtitle: providerName == null ? null : 'From $providerName',
              mediaType: 'movie',
              quality: quality,
              posterUrl: posterPath == null
                  ? null
                  : '${TMDB_BASE_IMAGE_URL}w500$posterPath',
              maxVideoHeight: maxVideoHeight,
              headers: downloadHeaders,
              audioTrack: audioSelection.track,
              source: OfflineDownloadSource.forSelection(
                provider: downloadProvider,
                apiBaseUrl: _scraperApiUrl,
                links: movieVideoLinks ?? const [],
                url: url,
              ),
              contentId: _metadata.movieId,
              subtitleTrackUrl: subtitleTrack?.url,
              subtitleTrackName: subtitleTrack?.language,
              subtitleTrackHeaders: subtitleTrack?.headers ?? const {},
            ),
          );
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'movie',
        outcome: 'success',
        provider: providerName,
        quality: quality,
      );
      if (mounted) {
        AdsterraPlaybackAdsService.instance.afterDownloadQueued(context);
        Navigator.pop(context, true);
      }
    } catch (error) {
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'movie',
        outcome: isAlreadyDownloaded(error) ? 'already_downloaded' : 'error',
        provider: providerName,
        quality: quality,
        error: error.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            offlineEnqueueErrorMessage(error,
                title: _metadata.movieName ?? 'This movie'),
          ),
        ),
      );
      Navigator.pop(context, false);
    }
  }

  /// The resolution closest to [height], saying so when it isn't [height].
  String _preferredResolution(Map<String, String> sources, int height) {
    final pick = VideoUtils.downloadSource(sources, height)!;
    if (!pick.exact) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('download_quality_unavailable', namedArgs: {
              'quality': '${height}p',
              'chosen': pick.entry.key,
            }),
          ),
        ),
      );
    }
    return pick.entry.key;
  }

  Future<String?> _askResolution(
    Map<String, String> sources,
    Map<String, String> videoSizeTokens,
    String? providerName,
  ) async {
    final estimatedSizes = ValueNotifier<Map<String, int?>>({
      for (final entry in videoSizeTokens.entries)
        if (_streamSizeCacheByToken.containsKey(entry.value))
          entry.key: _streamSizeCacheByToken[entry.value],
    });
    var sizePickerOpen = true;
    unawaited(StreamSizeEstimator.load(
      scraperApiUrl: _scraperApiUrl,
      tokens: videoSizeTokens,
      cacheByToken: _streamSizeCacheByToken,
      onEstimate: (token, bytes) {
        if (!sizePickerOpen) return;
        final next = Map<String, int?>.of(estimatedSizes.value);
        for (final entry in videoSizeTokens.entries) {
          if (entry.value == token) next[entry.key] = bytes;
        }
        estimatedSizes.value = next;
      },
    ));
    if (!mounted) return null;
    final quality = await DownloadSelectionSheets.showResolution(
      context,
      resolutions: sources.keys.toList(),
      providerName: providerName,
      estimatedSizesListenable: estimatedSizes,
    );
    sizePickerOpen = false;
    estimatedSizes.dispose();
    return quality;
  }

  int? _qualityHeight(String quality) => VideoUtils.videoQualityHeight(quality);

  RegularSubtitleLinks? _preferredSubtitle(
    List<RegularSubtitleLinks>? subtitles,
  ) {
    if (subtitles == null || subtitles.isEmpty) return null;
    final preferred = settings.defaultSubtitleLanguage.toLowerCase();
    for (final subtitle in subtitles) {
      final language = subtitle.language?.toLowerCase() ?? '';
      if (subtitle.url?.isNotEmpty == true &&
          preferred.isNotEmpty &&
          (language == preferred ||
              language.startsWith(preferred) ||
              (preferred == 'en' && language.startsWith('english')))) {
        return subtitle;
      }
    }
    return subtitles.cast<RegularSubtitleLinks?>().firstWhere(
          (subtitle) => subtitle?.url?.isNotEmpty == true,
          orElse: () => null,
        );
  }

  void _addSubtitles(List<RegularSubtitleLinks>? subtitleLinks) {
    if (subtitleLinks == null || subtitleLinks.isEmpty) return;
    final preferredLang = settings.defaultSubtitleLanguage.toLowerCase();

    for (final subLink in subtitleLinks) {
      final subLanguage = subLink.language ?? 'Unknown';
      final normalizedLanguage = subLanguage.toLowerCase();
      final isPreferred = preferredLang.isNotEmpty &&
          (normalizedLanguage.startsWith(preferredLang) ||
              normalizedLanguage == preferredLang ||
              (preferredLang == 'en' &&
                  normalizedLanguage.startsWith('english')));
      subs.add(
        BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.network,
          urls: [subLink.url ?? ''],
          name: subLanguage,
          selectedByDefault: isPreferred,
          headers: subLink.headers,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final releaseYear = _metadata.releaseYear?.toString() ??
        _metadata.releaseDate?.split('-').first;
    final contextLine = <String>[
      if (widget.download) tr('download'),
      if (releaseYear?.isNotEmpty == true && releaseYear != '0') releaseYear!,
    ].join('  ·  ');
    return PlaybackLoadingScreen(
      title: _metadata.movieName?.trim().isNotEmpty == true
          ? _metadata.movieName!.trim()
          : tr('movie'),
      subtitle: contextLine,
      backdropPath: _metadata.backdropPath,
      posterPath: _metadata.posterPath,
      providers: providerStates,
      currentProviderIndex: currentProviderIndex,
    );
  }

  Future<void> _fetchMovieRecommendations() async {
    final movieId = _metadata.movieId;
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final language = settings.appLanguage;
    debugPrint(
      '[MovieRecommendationsDebug][FETCH_START] '
      'movieId=$movieId language=$language '
      'proxyEnabled=$isProxyEnabled proxyConfigured=${proxyUrl.isNotEmpty} '
      'mounted=$mounted',
    );
    if (movieId == null) {
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_SKIPPED] reason=missing_movie_id',
      );
      return;
    }

    final recommendations = await _loadRecommendations(
      movieId: movieId,
      isProxyEnabled: isProxyEnabled,
      proxyUrl: proxyUrl,
      language: language,
    );
    _metadata.recommendations = recommendations;
    debugPrint(
      '[MovieRecommendationsDebug][METADATA_SET] '
      'movieId=$movieId count=${recommendations.length} '
      'items=${recommendations.map((movie) => '${movie.movieId}:${movie.title}').join(' | ')}',
    );

    // Set the movie change callback
    _metadata.onMovieChange = (int movieId) async {
      // This will be called from the player when user selects a movie
    };
  }

  /// TMDB's "recommendations" is frequently empty for newer or niche titles, so
  /// fall back to the broader "similar" list before giving up.
  Future<List<MovieRecommendation>> _loadRecommendations({
    required int movieId,
    required bool isProxyEnabled,
    required String proxyUrl,
    required String language,
  }) async {
    var movies = await _fetchRecommendationList(
      label: 'recommendations',
      endpoint: Endpoints.getMovieRecommendations(movieId, 1, language),
      isProxyEnabled: isProxyEnabled,
      proxyUrl: proxyUrl,
    );
    if (movies.isEmpty) {
      debugPrint(
        '[MovieRecommendationsDebug][FALLBACK_SIMILAR] movieId=$movieId',
      );
      movies = await _fetchRecommendationList(
        label: 'similar',
        endpoint: Endpoints.getSimilarMovies(movieId, 1, language),
        isProxyEnabled: isProxyEnabled,
        proxyUrl: proxyUrl,
      );
    }
    return movies
        .take(10)
        .map(MovieRecommendation.fromMovie)
        .toList(growable: false);
  }

  Future<List<Movie>> _fetchRecommendationList({
    required String label,
    required String endpoint,
    required bool isProxyEnabled,
    required String proxyUrl,
  }) async {
    try {
      final movies = await fetchMovies(
        endpoint,
        isProxyEnabled,
        proxyUrl,
        debugLabel: 'MovieRecommendationsDebug',
      );
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_RESULT] '
        'label=$label rawCount=${movies.length} '
        'rawIds=${movies.take(10).map((movie) => movie.id).join(',')}',
      );
      return movies;
    } catch (error, stackTrace) {
      // A failed list is not fatal; the other list (or an empty result) is used.
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_FAILED] '
        'label=$label type=${error.runtimeType} error=$error',
      );
      debugPrintStack(
        label: '[MovieRecommendationsDebug][FETCH_FAILED_STACK]',
        stackTrace: stackTrace,
      );
      return const <Movie>[];
    }
  }
}
