import 'package:flixquest/services/adsterra_playback_ads_service.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flixquest/functions/function.dart';
import 'package:flixquest/functions/network.dart';
import 'package:flixquest/functions/video_utils.dart';
import 'package:flixquest/functions/player_route_handoff.dart';
import 'package:flixquest/models/tv_stream_metadata.dart';
import 'package:flixquest/models/offline_download.dart';
import 'package:flixquest/models/provider_video_source.dart';
import 'package:flixquest/constants/app_constants.dart' show MediaType;
import 'package:flixquest/models/provider_load_state.dart';
import 'package:flixquest/services/globle_method.dart';
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
import '/provider/app_dependency_provider.dart';
import '/provider/offline_download_provider.dart';
import '/provider/settings_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player.dart';
import '../../models/sub_languages.dart';
import '../../widgets/common_widgets.dart';

import 'package:flutter/material.dart';
import '../../screens/common/player.dart';
import '../../screens/common/download_selection_sheets.dart';
import '../../screens/common/manual_source_picker.dart';
import '../../tv/player/tv_player_screen.dart';

class TVVideoLoader extends StatefulWidget {
  const TVVideoLoader(
      {required this.metadata,
      required this.download,
      this.useTvPlayer = false,
      this.onTvPlayerExit,
      super.key});

  final TVStreamMetadata metadata;
  final bool download;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;

  @override
  State<TVVideoLoader> createState() => _TVVideoLoaderState();
}

class _TVVideoLoaderState extends State<TVVideoLoader> {
  RecentlyWatchedEpisodeController recentlyWatchedEpisodeController =
      RecentlyWatchedEpisodeController();

  List<RegularVideoLinks>? tvVideoLinks;
  List<RegularSubtitleLinks>? tvVideoSubs;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPlayback());
  }

  Future<void> _startPlayback() async {
    if (!mounted) return;
    _adPreload = AdsterraPlaybackAdsService.instance.preloadStreamFound(context,
        download: widget.download, television: widget.useTvPlayer);
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
      if (widget.download) {
        if (!mounted) return;
        selectedDownloadProvider = await DownloadSelectionSheets.showProvider(
          context,
          providers: videoProviders,
        );
        if (!mounted) return;
        if (selectedDownloadProvider == null) {
          settings.analytics.trackDownload(
            action: 'provider_selection',
            mediaType: 'tv',
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
      // The player's episode list is not needed until it opens, so fetch it
      // alongside the source race instead of in front of it. Downloads never
      // open the player.
      final seasonEpisodesFetch =
          widget.download ? null : _fetchSeasonEpisodes();

      var isBookmarked = await recentlyWatchedEpisodeController
          .contain(widget.metadata.episodeId!);
      int elapsed = 0;
      if (isBookmarked) {
        if (mounted) {
          var rEpisodes =
              Provider.of<RecentProvider>(context, listen: false).episodes;

          int index = rEpisodes
              .indexWhere((element) => element.id == widget.metadata.episodeId);
          // See [MovieVideoLoader]: the row can reach the database through a
          // cloud merge before this list snapshot is refreshed.
          if (index != -1) {
            setState(() {
              elapsed = rEpisodes[index].elapsed!;
            });
          }
          widget.metadata.elapsed = elapsed;
        }
      } else {
        widget.metadata.elapsed = 0;
      }

      final isUnreleased = widget.metadata.airDate != null &&
          !isReleased(widget.metadata.airDate!);
      if (isUnreleased) {
        GlobalMethods.showScaffoldMessage(
            tr('episode_may_not_be_available'), context);
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
        // Race the sources in batches and use the first playable response.
        selection = await _fetchSelection(
          providers: selectedDownloadProvider == null
              ? videoProviders
              : [selectedDownloadProvider],
        );
      }

      if (selection != null) {
        if (!await AdsterraPlaybackAdsService.instance.streamFound(context,
                download: widget.download,
                television: widget.useTvPlayer,
                preload: _adPreload) ||
            !mounted) {
          return;
        }
      }
      final firstWorkingProviderCode = selection?.provider.codeName;
      if (selection != null) {
        _showSelectedProvider(selection.provider);
        final result = selection.result;
        videos = VideoUtils.convertVideoLinksToMap(result.videoLinks!);
        tvVideoLinks = result.videoLinks;
        tvVideoSubs = result.subtitleLinks;
        _addSubtitles(result.subtitleLinks);
      }

      // Check if we found a working provider
      if (firstWorkingProviderCode == null && mounted) {
        _showErrorSheet(tr('tv_vid_404'));
        return;
      }

      // Prepare final video map (reversed for quality ordering)
      Map<String, String> reversedVids =
          VideoUtils.reverseVideoQualityMap(videos);
      final videoFormats = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoFormatsToMap(tvVideoLinks ?? const []),
      );
      final videoHeaders = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoHeadersToMap(tvVideoLinks ?? const []),
      );
      final videoSizeTokens = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoSizeTokensToMap(tvVideoLinks ?? const []),
      );

      if (firstWorkingProviderCode != null && mounted) {
        if (widget.download) {
          await _enqueueDownload(
            sources: reversedVids,
            videoFormats: videoFormats,
            videoHeaders: videoHeaders,
            videoSizeTokens: videoSizeTokens,
            providerName: selection?.provider.displayName,
          );
          return;
        }
        if (!isUnreleased) {
          Provider.of<SettingsProvider>(context, listen: false)
              .analytics
              .trackTVWatched(
                tvName: widget.metadata.seriesName,
                tvId: widget.metadata.tvId,
                episodeName: widget.metadata.episodeName,
                seasonNumber: widget.metadata.seasonNumber,
                episodeNumber: widget.metadata.episodeNumber,
              );
        }

        await seasonEpisodesFetch;
        if (!mounted) return;

        // Navigate to player with provider list for lazy loading
        handoffLoaderToPlayer<Function>(
          context,
          (context) {
            final player = PlayerOne(
              mediaType: MediaType.tvShow,
              sources: reversedVids,
              subs: subs,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).colorScheme.surface
              ],
              settings: settings,
              tvMetadata: widget.metadata,
              availableProviders:
                  videoProviders, // Pass provider list for lazy loading
              currentProviderCode: firstWorkingProviderCode, // Current provider
              scraperApiUrl: _scraperApiUrl,
              videoFormats: videoFormats,
              videoHeaders: videoHeaders,
              videoSizeTokens: videoSizeTokens,
              initialVideoLinks: tvVideoLinks ?? const [],
              prefetchedProviderResults: selection?.batchResults ?? const {},
              subtitleStyle:
                  Provider.of<SettingsProvider>(context).subtitleTextStyle,
              onEpisodeChange: (episodeId, episodeNumber, seasonNumber) async {
                // This callback is now unused but kept for backwards compatibility
                // Episode changes are handled directly in the player
              },
              useTvControls: widget.useTvPlayer,
              onTvPlayerExit: widget.onTvPlayerExit,
            );
            return widget.useTvPlayer ? TvPlayerScreen(child: player) : player;
          },
        ).then((value) async {
          if (value != null) {
            Function callback = value;
            await callback.call();
          }
        });
      } else {
        if (mounted) {
          _showErrorSheet(tr('tv_vid_404'));
        }
      }
    } on Exception catch (e) {
      debugPrint('[TVVideoLoader] Exception loading video: $e');
      if (mounted) {
        _showErrorSheet(tr('tv_vid_404'));
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

  /// Shows [provider] as the one being played, once the race has chosen it.
  /// Sources later in its batch may still be answering, and would otherwise
  /// keep the focus.
  void _showSelectedProvider(VideoProvider provider) {
    if (!mounted) return;
    setState(() {
      currentProviderIndex = videoProviders.indexWhere(
        (candidate) => candidate.codeName == provider.codeName,
      );
    });
  }

  /// Races [providers] (in configured order) until one returns playable links.
  Future<ProviderSelection?> _fetchSelection({
    required List<VideoProvider> providers,
  }) {
    return ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) {
        _providerStopwatches[provider.codeName] = Stopwatch()..start();
        // Only the batch in flight shows as loading; the rest wait their turn.
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
          '[TVVideoLoader] Request provider=${provider.displayName} '
          '(${provider.codeName}), tmdbId=${widget.metadata.tvId}, '
          'season=${widget.metadata.seasonNumber}, episode=${widget.metadata.episodeNumber}',
        );
        return ProviderLoader.loadTVFromProvider(
          provider: provider,
          tvId: widget.metadata.tvId!,
          seasonNumber: widget.metadata.seasonNumber!,
          episodeNumber: widget.metadata.episodeNumber!,
          scraperApiUrl: _scraperApiUrl,
          full: widget.download,
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
          mediaType: 'tv',
          contentId: widget.metadata.tvId,
          contentTitle: widget.metadata.seriesName,
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
          '[TVVideoLoader] Response provider=${provider.displayName} '
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
    final metadata = widget.metadata;
    final download = widget.download;
    final useTvPlayer = widget.useTvPlayer;
    final onTvPlayerExit = widget.onTvPlayerExit;
    navigator.pop();
    ReportErrorWidget.show(
      navigator.context,
      error: message,
      onRetry: () => navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => TVVideoLoader(
            metadata: metadata,
            download: download,
            useTvPlayer: useTvPlayer,
            onTvPlayerExit: onTvPlayerExit,
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
  }) async {
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
    if (!mounted) return;
    final quality = await DownloadSelectionSheets.showResolution(
      context,
      resolutions: sources.keys.toList(),
      providerName: providerName,
      estimatedSizesListenable: estimatedSizes,
    );
    sizePickerOpen = false;
    estimatedSizes.dispose();
    if (!mounted) return;
    if (quality == null) {
      settings.analytics.trackDownload(
        action: 'resolution_selection',
        mediaType: 'tv',
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
    final posterPath = widget.metadata.posterPath;
    final season = widget.metadata.seasonNumber ?? 0;
    final episode = widget.metadata.episodeNumber ?? 0;
    final subtitleTrack = _preferredSubtitle(tvVideoSubs);
    try {
      await context.read<OfflineDownloadProvider>().enqueue(
            OfflineDownloadRequest(
              id: 'tv_${widget.metadata.tvId}_s${season}_e$episode',
              url: url,
              format: format,
              title: widget.metadata.seriesName ?? 'TV episode',
              subtitle:
                  'S${season.toString().padLeft(2, '0')} • E${episode.toString().padLeft(2, '0')} '
                  '${widget.metadata.episodeName ?? ''}'
                  '${providerName == null ? '' : ' • $providerName'}',
              mediaType: 'episode',
              quality: quality,
              posterUrl: posterPath == null
                  ? null
                  : '${TMDB_BASE_IMAGE_URL}w500$posterPath',
              maxVideoHeight: _qualityHeight(quality),
              headers: videoHeaders[quality] ??
                  VideoUtils.inferVideoHeaders(url) ??
                  const {},
              contentId: widget.metadata.tvId,
              seasonNumber: season,
              episodeNumber: episode,
              subtitleTrackUrl: subtitleTrack?.url,
              subtitleTrackName: subtitleTrack?.language,
              subtitleTrackHeaders: subtitleTrack?.headers ?? const {},
            ),
          );
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'tv',
        outcome: 'success',
        provider: providerName,
        quality: quality,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'tv',
        outcome: 'error',
        provider: providerName,
        quality: quality,
        error: error.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start download: $error')),
      );
      Navigator.pop(context, false);
    }
  }

  int? _qualityHeight(String quality) {
    final match = RegExp(r'(\d{3,4})').firstMatch(quality);
    return int.tryParse(match?.group(1) ?? '');
  }

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

  void getAppLanguage() {
    for (int i = 0; i < supportedLanguages.length; i++) {
      if (supportedLanguages[i].languageCode ==
          settings.defaultSubtitleLanguage) {
        foundIndex = i;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final season = widget.metadata.seasonNumber;
    final episode = widget.metadata.episodeNumber;
    final contextLine = <String>[
      if (widget.download) tr('download'),
      if (season != null && episode != null) 'S$season:E$episode',
      if (widget.metadata.episodeName?.trim().isNotEmpty == true)
        widget.metadata.episodeName!.trim(),
    ].join('  ·  ');
    return PlaybackLoadingScreen(
      title: widget.metadata.seriesName?.trim().isNotEmpty == true
          ? widget.metadata.seriesName!.trim()
          : widget.metadata.episodeName?.trim() ?? '',
      subtitle: contextLine,
      backdropPath: widget.metadata.backdropPath,
      posterPath: widget.metadata.posterPath,
      providers: providerStates,
      currentProviderIndex: currentProviderIndex,
    );
  }

  Future<void> _fetchSeasonEpisodes() async {
    try {
      if (widget.metadata.tvId != null &&
          widget.metadata.seasonNumber != null) {
        final isProxyEnabled =
            Provider.of<SettingsProvider>(context, listen: false).enableProxy;
        final proxyUrl =
            Provider.of<AppDependencyProvider>(context, listen: false)
                .tmdbProxy;

        if (widget.metadata.allSeasons?.isNotEmpty != true) {
          final tvDetails = await fetchTVDetails(
            Endpoints.tvDetailsUrl(widget.metadata.tvId!, settings.appLanguage),
            isProxyEnabled,
            proxyUrl,
          );
          if (tvDetails.seasons?.isNotEmpty == true) {
            widget.metadata.allSeasons = tvDetails.seasons!
                .map((season) => SeasonMetadata.fromSeason(season))
                .toList();
          }
        }

        final selectedSeason = widget.metadata.seasonNumber!;
        final hasSelectedSeasonEpisodes =
            widget.metadata.seasonEpisodes?.isNotEmpty == true &&
                widget.metadata.seasonEpisodes!.every(
                  (episode) => episode.seasonNumber == selectedSeason,
                );
        if (!hasSelectedSeasonEpisodes) {
          final seasonDetails = await fetchTVDetails(
            Endpoints.getSeasonDetails(
              widget.metadata.tvId!,
              selectedSeason,
              settings.appLanguage,
            ),
            isProxyEnabled,
            proxyUrl,
          );
          if (seasonDetails.episodes?.isNotEmpty == true) {
            widget.metadata.seasonEpisodes = seasonDetails.episodes!
                .map((episode) => EpisodeMetadata(
                      episodeId: episode.episodeId ?? 0,
                      episodeName:
                          episode.name ?? 'Episode ${episode.episodeNumber}',
                      episodeNumber: episode.episodeNumber ?? 0,
                      seasonNumber: selectedSeason,
                      stillPath: episode.stillPath,
                      airDate: episode.airDate,
                      runtime: null,
                      overview: episode.overview,
                      voteAverage: episode.voteAverage,
                    ))
                .toList();
          }
        }

        // Set the season change callback
        widget.metadata.onSeasonChange = (int seasonNumber) async {
          // This will be called from the player when user changes season
          // We don't need to implement the fetch here, it's handled in the player
        };
      }
    } catch (e) {
      // If fetching episodes fails, continue without them
      debugPrint('Failed to fetch season episodes: $e');
    }
  }
}
