// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/models/tv_stream_metadata.dart';
import 'package:flixquest/models/wellness.dart';
import 'package:flixquest/provider/wellness_provider.dart';
import 'package:flixquest/models/offline_download.dart';

import '../../models/movie_stream_metadata.dart';
import '../../models/provider_video_source.dart';
import '../../video_providers/names.dart';
import '../../video_providers/provider_loader.dart';
import '../../video_providers/common.dart';
import '../../functions/video_utils.dart';
import '../../functions/network.dart';
import '../../functions/player_subtitle_configuration.dart';
import '../../functions/player_buffering_configuration.dart';
import '../../functions/subtitle_options.dart';
import '/constants/app_constants.dart';
import '/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../functions/function.dart';
import '../../provider/settings_provider.dart';
import '../../provider/offline_download_provider.dart';
import '../../provider/app_dependency_provider.dart';
import '../../constants/api_constants.dart';
import '../../api/endpoints.dart';
import '../../ui_components/app_ui_components.dart';
import '../../services/stream_intro_service.dart';
import '../../services/introdb_service.dart';
import '../../services/stream_size_estimator.dart';
import '../movie/movie_video_loader.dart';
import '../tv/tv_video_loader.dart';
import 'player/player_data_management.dart';
import 'player/player_completion_detector.dart';
import 'player/player_external_subtitles.dart';
import 'player/player_local_subtitles.dart';
import 'player/player_episode_selection.dart';
import 'player/player_movie_recommendations.dart';
import 'player/player_next_episode_policy.dart';
import 'player/player_sheet_ui.dart';
import 'player/player_widgets.dart';
import 'download_selection_sheets.dart';

class PlayerOne extends StatefulWidget {
  const PlayerOne(
      {required this.sources,
      required this.subs,
      required this.colors,
      required this.settings,
      this.movieMetadata,
      this.tvMetadata,
      required this.mediaType,
      required this.subtitleStyle,
      this.onEpisodeChange, // Callback for when user selects a different episode
      this.availableProviders, // Provider metadata for lazy loading
      this.currentProviderCode, // Current provider code
      this.initialPlaybackPosition, // For preserving position on provider switch
      this.scraperApiUrl = '',
      this.videoFormats,
      this.videoHeaders = const {},
      this.videoSizeTokens = const {},
      this.initialVideoLinks = const [],
      this.prefetchedProviderResults = const {},
      this.useTvControls = false,
      this.onTvPlayerExit,
      super.key});
  final Map<String, String> sources;
  final List<BetterPlayerSubtitlesSource> subs;
  final List<Color> colors;
  final SettingsProvider settings;
  final MovieStreamMetadata? movieMetadata;
  final TVStreamMetadata? tvMetadata;
  final MediaType? mediaType;
  final String? subtitleStyle;
  final Function(int episodeId, int episodeNumber, int seasonNumber)?
      onEpisodeChange;
  final List<VideoProvider>?
      availableProviders; // Changed to VideoProvider list
  final String? currentProviderCode;
  final Duration? initialPlaybackPosition;
  final String scraperApiUrl;
  final Map<String, BetterPlayerVideoFormat?>? videoFormats;
  final Map<String, Map<String, String>> videoHeaders;
  final Map<String, String> videoSizeTokens;
  final List<RegularVideoLinks> initialVideoLinks;
  final Map<String, Future<ProviderLoaderResult>> prefetchedProviderResults;
  final bool useTvControls;
  final VoidCallback? onTvPlayerExit;

  @override
  State<PlayerOne> createState() => _PlayerOneState();
}

class _PlayerOneState extends State<PlayerOne> with WidgetsBindingObserver {
  late BetterPlayerController _betterPlayerController;
  bool _betterPlayerControllerInitialized = false;
  final StreamIntroService _introService = StreamIntroService();
  final IntroDbService _introDbService = IntroDbService();
  final BetterPlayerTvControlsController _tvControlsController =
      BetterPlayerTvControlsController();
  late BetterPlayerControlsConfiguration betterPlayerControlsConfiguration;
  late BetterPlayerBufferingConfiguration betterPlayerBufferingConfiguration;
  final PlayerDataManagement _dataManagement = PlayerDataManagement();
  final PlayerExternalSubtitles _externalSubtitles = PlayerExternalSubtitles();
  final PlayerLocalSubtitles _localSubtitles = PlayerLocalSubtitles();
  late final PlayerEpisodeSelection _episodeSelection;
  final PlayerMovieRecommendations _movieRecommendations =
      PlayerMovieRecommendations();
  final PlayerNextEpisodeWidget _nextEpisodeWidget = PlayerNextEpisodeWidget();
  late final List<EpisodeMetadata> _contentMenuEpisodes;
  late final List<SeasonMetadata> _contentMenuSeasons;
  int duration = 0;

  final GlobalKey _betterPlayerKey = GlobalKey();

  int totalMinutesWatched = 0;
  bool isVideoPaused = false;

  int playbackDurationInSeconds = 0;
  Timer? _durationTimer;
  // ignore: unused_field
  Timer? _resetTimer;

  // For next episode button
  bool _showNextEpisodeButton = false;
  bool _nextEpisodeButtonDismissed = false;
  bool _preRollActive = false;
  IntroDbTimings _introDbTimings = IntroDbTimings.empty;
  IntroDbSegment? _activeIntroDbSegment;
  final Set<String> _skippedIntroDbSegments = <String>{};
  bool _introDbLoading = false;
  bool _introDbCreditsActive = false;
  int _introDbRequestId = 0;
  bool _introDbLookupComplete = false;
  bool _introDbLookupSettled = false;
  bool _playbackCompletionHandled = false;
  final PlayerCompletionDetector _completionDetector = PlayerCompletionDetector(
    stalledEndTolerance: const Duration(seconds: 12),
    requiredStableSamples: 3,
  );
  Timer? _progressCheckTimer;
  OverlayEntry? _nextEpisodeOverlay;
  bool _playerControlsVisible = false;
  String? _lastNextEpisodeDebugSignature;
  Timer? _tvNextEpisodeTimer;
  EpisodeMetadata? _tvNextEpisode;
  int? _tvNextEpisodeCountdown;
  int _tvNextEpisodeCountdownTotal = 10;

  /// The prompt came up at the credits rather than the end, so declining it
  /// means watching them.
  bool _tvNextEpisodeAtCredits = false;
  _TvPlayerMenuData? _tvMenu;
  int? _portraitBrowsedSeasonNumber;
  bool _portraitSeasonLoading = false;
  Orientation? _lastScreenOrientation;
  bool _landscapeFullscreenRequestPending = false;

  late SettingsProvider settings;

  // Provider switching
  bool _isSwitchingProvider = false;
  late String? _currentProviderCode; // Track current provider
  final Map<String, ProviderVideoSource> _loadedProviders =
      {}; // Cache loaded providers
  late final Map<String, Future<ProviderLoaderResult>> _providerResults;
  final Map<String, Future<ProviderLoaderResult>> _fullProviderResults = {};
  final Map<String, List<RegularVideoLinks>> _rawVideoLinksByProvider = {};
  late Map<String, String> _activeSources;
  late List<BetterPlayerSubtitlesSource> _activeSubtitles;
  late Map<String, BetterPlayerVideoFormat?>? _activeVideoFormats;
  late Map<String, Map<String, String>> _activeVideoHeaders;
  late Map<String, String> _activeVideoSizeTokens;
  final Map<String, int> _sizeRequestGenerations = {};
  final Completer<void> _initialDataSourceReady = Completer<void>();
  final Map<String, int?> _streamSizeCacheByToken = {};
  final Set<String> _loadingProviders =
      {}; // Track which providers are being loaded
  final Map<String, String> _providerErrors = {};
  late final DateTime _analyticsSessionStartedAt;
  late final String _analyticsSessionId;
  late final WellnessPlaybackTracker _wellnessTracker;
  DateTime? _lastWellnessCheckpointAt;
  DateTime? _analyticsPlayingStartedAt;
  DateTime? _analyticsBufferingStartedAt;
  int _analyticsWatchedMs = 0;
  int _analyticsBufferingMs = 0;
  int _analyticsBufferCount = 0;
  int _analyticsProviderSwitchCount = 0;
  int _analyticsInitializationCount = 0;
  bool _analyticsWasPlayingBeforeBuffering = false;
  String? _lastAnalyticsError;
  DateTime? _lastAnalyticsErrorAt;
  late final AppDependencyProvider _appDependencies;
  int? _occasionalEffectsSuppressionId;
  bool _isContentMenuOpen = false;

  @override
  void initState() {
    settings = Provider.of<SettingsProvider>(context, listen: false);
    _currentProviderCode = widget.currentProviderCode; // Initialize from widget
    _providerResults = Map.of(widget.prefetchedProviderResults);
    _activeSources = Map.of(widget.sources);
    _activeSubtitles = List.of(widget.subs);
    _activeVideoFormats =
        widget.videoFormats == null ? null : Map.of(widget.videoFormats!);
    _activeVideoHeaders = Map.of(widget.videoHeaders);
    _activeVideoSizeTokens = Map.of(widget.videoSizeTokens);
    final initialProviderCode = widget.currentProviderCode;
    if (initialProviderCode != null && widget.initialVideoLinks.isNotEmpty) {
      _rawVideoLinksByProvider[initialProviderCode] =
          List.of(widget.initialVideoLinks);
    }
    if (widget.mediaType == MediaType.movie) {
      final recommendations = widget.movieMetadata?.recommendations;
      debugPrint(
        '[MovieRecommendationsDebug][PLAYER_INIT] '
        'movieId=${widget.movieMetadata?.movieId} '
        'title=${widget.movieMetadata?.movieName} '
        'metadataCount=${recommendations?.length ?? 0} '
        'ids=${recommendations?.map((movie) => movie.movieId).join(',') ?? ''}',
      );
    }
    _contentMenuEpisodes = List<EpisodeMetadata>.of(
      widget.tvMetadata?.seasonEpisodes ?? const <EpisodeMetadata>[],
    );
    _contentMenuSeasons = List<SeasonMetadata>.of(
      widget.tvMetadata?.allSeasons ?? const <SeasonMetadata>[],
    );
    super.initState();
    _appDependencies =
        Provider.of<AppDependencyProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _occasionalEffectsSuppressionId != null) return;
      _occasionalEffectsSuppressionId =
          _appDependencies.suppressOccasionalEffects();
    });
    _analyticsSessionStartedAt = DateTime.now();
    _analyticsSessionId =
        '${_analyticsSessionStartedAt.microsecondsSinceEpoch}-${identityHashCode(this)}';
    _wellnessTracker = WellnessPlaybackTracker(
      id: _analyticsSessionId,
      createdAt: _analyticsSessionStartedAt,
    );

    // Initialize episode selection with current season
    _episodeSelection = PlayerEpisodeSelection(widget.tvMetadata?.seasonNumber);

    WidgetsBinding.instance.addObserver(this);
    // Playback owns the screen for the whole session on both surfaces. Better
    // Player only holds a wakelock inside its own fullscreen route, which TV
    // playback never enters.
    unawaited(WakelockPlus.enable());
    betterPlayerBufferingConfiguration = buildPlayerBufferingConfiguration(
      maximumDurationMs: widget.settings.defaultMaxBufferDuration,
      television: widget.useTvControls,
    );
    final hasEpisodeSelection =
        widget.mediaType == MediaType.tvShow && _contentMenuEpisodes.isNotEmpty;
    final hasMovieRecommendations = widget.mediaType == MediaType.movie &&
        (widget.movieMetadata?.recommendations?.isNotEmpty ?? false);
    debugPrint(
      '[PlayerContentMenu] configure '
      'mediaType=${widget.mediaType} '
      'useTvControls=${widget.useTvControls} '
      'episodes=${widget.tvMetadata?.seasonEpisodes?.length ?? 0} '
      'recommendations=${widget.movieMetadata?.recommendations?.length ?? 0} '
      'episodeButton=$hasEpisodeSelection '
      'recommendationsButton=$hasMovieRecommendations',
    );
    betterPlayerControlsConfiguration = BetterPlayerControlsConfiguration(
        // Gesture controls configuration
        gestureConfiguration: BetterPlayerGestureConfiguration(
          enableVolumeSwipe: !widget.useTvControls,
          enableBrightnessSwipe: !widget.useTvControls,
          enableSeekSwipe: !widget.useTvControls,
          enableDoubleTapSeek: !widget.useTvControls,
          volumeSwipeSensitivity: 0.5,
          brightnessSwipeSensitivity: 0.5,
          seekSwipeSensitivity: 1.0,
        ),
        onFullScreenChange: () {
          widget.mediaType == MediaType.movie
              ? insertRecentMovieData()
              : insertRecentEpisodeData();
        },
        enableFullscreen: true,
        enableEpisodeSelection: hasEpisodeSelection,
        // Open immediately: addPostFrameCallback does not request a frame and
        // can leave these controls unresponsive while playback is idle.
        onEpisodeListTap: () {
          debugPrint('[PlayerContentMenu] episodes control tapped');
          unawaited(_openEpisodeList());
        },
        enableMovieRecommendations: hasMovieRecommendations,
        onMovieRecommendationsTap: () {
          debugPrint('[PlayerContentMenu] recommendations control tapped');
          unawaited(_openMovieRecommendations());
        },
        enableNextEpisodeButton: widget.mediaType == MediaType.tvShow &&
            widget.settings.enableNextEpisodeButton,
        introDbSkipButtonBuilder: _buildIntroDbSkipButton,
        introDbSkipAvailable: _canSkipIntroDbSegment,
        onIntroDbSkip: _skipActiveIntroDbSegment,
        // The native MediaRouteButton currently crashes on some Android
        // devices when its platform-view background resolves to transparent.
        enableCast: false,
        name: widget.mediaType == MediaType.movie
            ? '${widget.movieMetadata!.movieName!} (${widget.movieMetadata!.releaseYear!})'
            : '${widget.tvMetadata!.seriesName!} - ${widget.tvMetadata!.episodeName!} | ${episodeSeasonFormatter(widget.tvMetadata!.episodeNumber!, widget.tvMetadata!.seasonNumber!)}',
        backgroundColor: Colors.black,
        progressBarBackgroundColor: Colors.white,
        controlBarColor: Colors.black.withValues(alpha: 0.48),
        muteIcon: PhosphorIcons.speakerSimpleSlash(),
        unMuteIcon: PhosphorIcons.speakerHigh(),
        pauseIcon: PhosphorIcons.pause(),
        pipMenuIcon: PhosphorIcons.appWindow(),
        playIcon: PhosphorIcons.play(),
        showControlsOnInitialize: widget.useTvControls,
        controlsHideTime: widget.useTvControls
            ? const Duration(seconds: 4)
            : const Duration(milliseconds: 300),
        playerTheme: widget.useTvControls ? BetterPlayerTheme.custom : null,
        customControlsBuilder: widget.useTvControls
            ? (controller, onVisibilityChanged) => BetterPlayerTvControls(
                  controller: controller,
                  controlsController: _tvControlsController,
                  onControlsVisibilityChanged: onVisibilityChanged,
                  accentColor: widget.colors.first,
                  onExit: _exitPlayer,
                )
            : null,
        // On TV only the timeline's played part carries the brand colour.
        loadingColor: _tvNeutral ?? widget.colors.first,
        loadingWidget: SizedBox(
          width: 60,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: _tvNeutral ?? widget.colors.first,
              backgroundColor:
                  (_tvNeutral ?? widget.colors.first).withValues(alpha: .24),
            ),
          ),
        ),
        iconsColor: widget.colors.first,
        backwardSkipTimeInMilliseconds:
            Duration(seconds: widget.settings.defaultSeekDuration)
                .inMilliseconds,
        forwardSkipTimeInMilliseconds:
            Duration(seconds: widget.settings.defaultSeekDuration)
                .inMilliseconds,
        progressBarPlayedColor: widget.colors.first,
        progressBarBufferedColor: Colors.black45,
        skipForwardIcon: PhosphorIcons.fastForward(),
        skipBackIcon: PhosphorIcons.rewind(),
        fullscreenEnableIcon: PhosphorIcons.cornersOut(),
        fullscreenDisableIcon: PhosphorIcons.cornersIn(),
        overflowMenuIcon: PhosphorIcons.list(),
        overflowMenuIconsColor: widget.colors.first,
        overflowModalTextColor: widget.colors.first,
        overflowModalColor: widget.colors.last,
        subtitlesIcon: PhosphorIcons.closedCaptioning(),
        enableSubtitles: true,
        showSubtitlesButton: !widget.useTvControls,
        onSubtitlesTap: widget.useTvControls ? null : _showSubtitleSwitcher,
        qualitiesIcon: PhosphorIcons.highDefinition(),
        showQualitiesButton: !widget.useTvControls,
        enableDownloadButton: !widget.useTvControls,
        onDownloadTap:
            widget.useTvControls ? null : _downloadFromCurrentProvider,
        enableCrop: true,
        cropIcon: PhosphorIcons.crop(),
        enableAudioTracks: true,
        controlBarHeight: 56,
        watchingText: tr('watching_text'),
        playerTimeMode: settings.playerTimeDisplay,
        // Add custom overflow menu item for external subtitles
        overflowMenuCustomItems: widget.useTvControls
            ? [
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.timer(),
                  tr('subtitle_timing'),
                  _showSubtitleTimingAdjuster,
                ),
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.fileArrowUp(),
                  tr('upload_subtitles'),
                  () {
                    _localSubtitles.showLocalSubtitlesUpload(
                      context: context,
                      colors: widget.colors,
                      betterPlayerController: _betterPlayerController,
                    );
                  },
                ),
                if (widget.availableProviders?.isNotEmpty == true)
                  BetterPlayerOverflowMenuItem(
                    PhosphorIcons.arrowsLeftRight(),
                    tr('switch_provider'),
                    _showTvProviderMenu,
                  ),
              ]
            : [
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.timer(),
                  tr('subtitle_timing'),
                  _showSubtitleTimingAdjuster,
                ),
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.closedCaptioning(),
                  tr('external_subtitles'),
                  () {
                    _externalSubtitles.showExternalSubtitlesMenu(
                      context: context,
                      colors: widget.colors,
                      scraperApiUrl: _resolveScraperApiUrl(),
                      mediaType: widget.mediaType,
                      movieMetadata: widget.movieMetadata,
                      tvMetadata: widget.tvMetadata,
                      betterPlayerController: _betterPlayerController,
                    );
                  },
                ),
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.fileArrowUp(),
                  tr('upload_subtitles'),
                  () {
                    _localSubtitles.showLocalSubtitlesUpload(
                      context: context,
                      colors: widget.colors,
                      betterPlayerController: _betterPlayerController,
                    );
                  },
                ),
                if (widget.availableProviders?.isNotEmpty == true)
                  BetterPlayerOverflowMenuItem(
                    PhosphorIcons.arrowsLeftRight(),
                    tr('switch_provider'),
                    _showProviderSwitcher,
                  ),
              ]);
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
            autoDetectFullscreenDeviceOrientation: !widget.useTvControls,
            fullScreenByDefault:
                widget.useTvControls ? false : widget.settings.defaultViewMode,
            autoPlay: true,
            fit: BoxFit.contain,
            // Ambient glow continuously samples the video frame and is costly
            // on TV GPUs. Keep the existing effect for mobile playback.
            enableAmbientGlow: !widget.useTvControls,
            autoDispose: true,
            controlsConfiguration: betterPlayerControlsConfiguration,
            showPlaceholderUntilPlay: true,
            allowedScreenSleep: false,
            autoDetectFullscreenAspectRatio: !widget.useTvControls,
            errorBuilder: (context, errorMessage) =>
                _buildCustomPlayerErrorWidget(context, errorMessage),
            subtitlesConfiguration: buildPlayerSubtitleConfiguration(
              backgroundColor: widget.settings.subtitleBackgroundColor,
              foregroundColor: widget.settings.subtitleForegroundColor,
              fontSize: widget.settings.subtitleFontSize,
              textStyle:
                  widget.subtitleStyle ?? widget.settings.subtitleTextStyle,
            ));

    final dataSource = _buildDataSource(
      sources: _activeSources,
      subtitles: _activeSubtitles,
      videoFormats: _activeVideoFormats,
      videoHeaders: _activeVideoHeaders,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerControllerInitialized = true;
    if (widget.mediaType == MediaType.tvShow) {
      _logNextEpisodeState('player_init', force: true);
    }
    settings.addListener(_syncAmbientGlowSetting);
    _syncAmbientGlowSetting();
    _betterPlayerController.setBetterPlayerGlobalKey(_betterPlayerKey);
    _betterPlayerController.addEventsListener(_onAnalyticsPlayerEvent);
    // Attach listeners before setup so native initialization and pre-roll
    // transition events cannot race the first platform callback.
    unawaited(_setupInitialDataSource(dataSource));
    unawaited(_startActiveProviderEnrichment());

    // Monitor every stream because some platform/provider combinations reach
    // the final timestamp without delivering Better Player's finished event.
    _startPlaybackMonitor();

    // _betterPlayerController.addEventsListener((BetterPlayerEvent event) {
    //   if (event.betterPlayerEventType == BetterPlayerEventType.play ||
    //       event.betterPlayerEventType == BetterPlayerEventType.bufferingEnd) {
    //     startDurationTimer();
    //   } else if (event.betterPlayerEventType == BetterPlayerEventType.pause ||
    //       event.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
    //     pauseDurationTimer();
    //   } else if (event.betterPlayerEventType ==
    //       BetterPlayerEventType.finished) {
    //     resetDurationTimer();
    //   }
    // });
  }

  String _resolveScraperApiUrl() {
    if (widget.scraperApiUrl.trim().isNotEmpty) {
      return widget.scraperApiUrl.trim();
    }
    return Provider.of<AppDependencyProvider>(context, listen: false)
        .flixquestAPIURL;
  }

  void _syncAmbientGlowSetting() {
    _betterPlayerController.setAmbientGlowEnabled(
      !widget.useTvControls && settings.playerAmbientGlowEnabled,
    );
  }

  Future<void> _setupInitialDataSource(
      BetterPlayerDataSource dataSource) async {
    final metadataElapsed = widget.mediaType == MediaType.movie
        ? widget.movieMetadata?.elapsed
        : widget.tvMetadata?.elapsed;
    final requestedPosition = widget.initialPlaybackPosition ??
        Duration(seconds: metadataElapsed ?? 0);
    final initialPosition =
        requestedPosition < Duration.zero ? Duration.zero : requestedPosition;
    try {
      StreamIntroConfig intro = const StreamIntroConfig.disabled();
      try {
        intro = await _introService.fetch(_resolveScraperApiUrl());
      } catch (error) {
        debugPrint('[Player] Branded intro unavailable: $error');
      }

      if (intro.enabled && intro.url != null) {
        _preRollActive = true;
        await _betterPlayerController.setupDataSourceWithPreRoll(
          preRollDataSource: _buildIntroDataSource(intro.url!),
          betterPlayerDataSource: dataSource,
          contentStartPosition: initialPosition,
        );
      } else {
        _preRollActive = false;
        await _betterPlayerController.setupDataSource(
          dataSource,
          initialPosition: initialPosition,
        );
      }
      if (!mounted) return;
      _applyPreferredAdaptiveQuality();
      duration = _betterPlayerController
              .videoPlayerController?.value.duration?.inSeconds ??
          0;
      debugPrint(
        '[Player][IntroDB] initial data source ready '
        'durationSeconds=$duration preRoll=$_preRollActive',
      );
      if (!_preRollActive) unawaited(_loadIntroDbTimings());
    } catch (error) {
      _preRollActive = false;
      debugPrint('[Player] Initial stream setup failed: $error');
    } finally {
      if (!_initialDataSourceReady.isCompleted) {
        _initialDataSourceReady.complete();
      }
    }
  }

  BetterPlayerDataSource _buildIntroDataSource(Uri url) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url.toString(),
      cacheConfiguration: const BetterPlayerCacheConfiguration(
        useCache: true,
        maxCacheSize: 50 * 1024 * 1024,
        maxCacheFileSize: 20 * 1024 * 1024,
      ),
    );
  }

  String get _analyticsMediaType =>
      widget.mediaType == MediaType.movie ? 'movie' : 'tv';

  dynamic get _analyticsContentId => widget.mediaType == MediaType.movie
      ? widget.movieMetadata?.movieId
      : widget.tvMetadata?.tvId;

  String? get _analyticsContentTitle => widget.mediaType == MediaType.movie
      ? widget.movieMetadata?.movieName
      : widget.tvMetadata?.seriesName;

  String? get _analyticsProviderName {
    final code = _currentProviderCode;
    if (code == null || code.trim().isEmpty) return null;
    return _providerDisplayName(code);
  }

  /// White in place of the accent on TV, where the brand colour is kept for
  /// the timeline alone.
  Color? get _tvNeutral => widget.useTvControls ? Colors.white : null;

  String get _analyticsSurface => widget.useTvControls ? 'tv' : 'standard';

  int get _analyticsElapsedMs =>
      DateTime.now().difference(_analyticsSessionStartedAt).inMilliseconds;

  void _onAnalyticsPlayerEvent(BetterPlayerEvent event) {
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        duration = _betterPlayerController
                .videoPlayerController?.value.duration?.inSeconds ??
            duration;
        _analyticsInitializationCount++;
        debugPrint(
          '[Player][IntroDB] player initialized '
          'preRoll=$_preRollActive durationSeconds=$duration',
        );
        if (!_preRollActive) unawaited(_loadIntroDbTimings());
        _trackPlaybackEvent(
          _analyticsInitializationCount == 1 ? 'initialized' : 'reinitialized',
          startupMs:
              _analyticsInitializationCount == 1 ? _analyticsElapsedMs : null,
        );
        break;
      case BetterPlayerEventType.preRollEnded:
        _preRollActive = false;
        _completionDetector.reset();
        _playbackCompletionHandled = false;
        duration = _betterPlayerController
                .videoPlayerController?.value.duration?.inSeconds ??
            duration;
        _trackPlaybackEvent('pre_roll_ended');
        if (_betterPlayerController.videoPlayerController?.value.isPlaying ==
            true) {
          _wellnessTracker.play();
        }
        unawaited(_loadIntroDbTimings());
        break;
      case BetterPlayerEventType.play:
        _analyticsPlayingStartedAt ??= DateTime.now();
        if (!_preRollActive) _wellnessTracker.play();
        _trackPlaybackEvent('play');
        break;
      case BetterPlayerEventType.pause:
        _analyticsWasPlayingBeforeBuffering = false;
        _stopAnalyticsWatchClock();
        _wellnessTracker.pause();
        _trackPlaybackEvent('pause');
        break;
      case BetterPlayerEventType.bufferingStart:
        _analyticsWasPlayingBeforeBuffering =
            _analyticsPlayingStartedAt != null;
        _stopAnalyticsWatchClock();
        _wellnessTracker.pause();
        _analyticsBufferingStartedAt ??= DateTime.now();
        _analyticsBufferCount++;
        _trackPlaybackEvent('buffering_started');
        break;
      case BetterPlayerEventType.bufferingEnd:
        final startedAt = _analyticsBufferingStartedAt;
        final bufferingMs = startedAt == null
            ? 0
            : DateTime.now().difference(startedAt).inMilliseconds;
        _analyticsBufferingMs += bufferingMs;
        _analyticsBufferingStartedAt = null;
        if (_analyticsWasPlayingBeforeBuffering) {
          _analyticsPlayingStartedAt = DateTime.now();
          _wellnessTracker.play();
        }
        _analyticsWasPlayingBeforeBuffering = false;
        _trackPlaybackEvent('buffering_ended', bufferingMs: bufferingMs);
        break;
      case BetterPlayerEventType.exception:
        final error = event.parameters?['exception']?.toString() ??
            'Unknown player error';
        final now = DateTime.now();
        if (error != _lastAnalyticsError ||
            _lastAnalyticsErrorAt == null ||
            now.difference(_lastAnalyticsErrorAt!).inSeconds >= 10) {
          _lastAnalyticsError = error;
          _lastAnalyticsErrorAt = now;
          _trackPlaybackEvent('error', error: error);
        }
        break;
      case BetterPlayerEventType.finished:
        debugPrint('[Player] BetterPlayer reported finished');
        _handlePlaybackCompleted(source: 'native');
        break;
      case BetterPlayerEventType.setupDataSource:
        _completionDetector.reset();
        _playbackCompletionHandled = false;
        _introDbRequestId++;
        _introDbLoading = false;
        _introDbTimings = IntroDbTimings.empty;
        _activeIntroDbSegment = null;
        _introDbCreditsActive = false;
        _introDbLookupComplete = false;
        _introDbLookupSettled = false;
        _skippedIntroDbSegments.clear();
        break;
      case BetterPlayerEventType.changedResolution:
        final name = event.parameters?['name']?.toString();
        settings.analytics.trackQualityChanged(quality: name ?? 'automatic');
        _trackPlaybackEvent('quality_changed', value: name ?? 'automatic');
        break;
      case BetterPlayerEventType.changedTrack:
        final height = event.parameters?['height'];
        final quality = height == null ? 'automatic' : '${height}p';
        settings.analytics.trackQualityChanged(quality: quality);
        _trackPlaybackEvent('quality_changed', value: quality);
        break;
      case BetterPlayerEventType.changedSubtitles:
        final source = _betterPlayerController.betterPlayerSubtitlesSource;
        final language = source?.type == BetterPlayerSubtitlesSourceType.none
            ? 'off'
            : source?.name ?? 'default';
        settings.analytics.trackSubtitleLanguageChanged(language: language);
        _trackPlaybackEvent('subtitle_changed', value: language);
        break;
      case BetterPlayerEventType.hideFullscreen:
        // Leaving Better Player's fullscreen route unconditionally clears the
        // screen-on flag. The route pop completes the awaiting fullscreen
        // continuation in a microtask, so re-asserting on the next frame lands
        // after that cleanup and restores the player-lifetime hold.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(WakelockPlus.enable());
        });
        break;
      case BetterPlayerEventType.controlsVisible:
        _updatePlayerControlsVisibility(true);
        break;
      case BetterPlayerEventType.controlsHiddenStart:
      case BetterPlayerEventType.controlsHiddenEnd:
        _updatePlayerControlsVisibility(false);
        break;
      default:
        break;
    }
  }

  void _updatePlayerControlsVisibility(bool visible) {
    if (_playerControlsVisible == visible) return;
    _playerControlsVisible = visible;
    _nextEpisodeOverlay?.markNeedsBuild();
  }

  void _stopAnalyticsWatchClock() {
    final startedAt = _analyticsPlayingStartedAt;
    if (startedAt == null) return;
    _analyticsWatchedMs += DateTime.now().difference(startedAt).inMilliseconds;
    _analyticsPlayingStartedAt = null;
  }

  bool _isVideoInitializedSafely() {
    if (!_betterPlayerControllerInitialized) return false;
    return _betterPlayerController.videoPlayerController?.value.initialized ==
        true;
  }

  void _trackPlaybackEvent(
    String event, {
    int? startupMs,
    int? bufferingMs,
    String? value,
    String? error,
  }) {
    settings.analytics.trackPlaybackEvent(
      mediaType: _analyticsMediaType,
      contentId: _analyticsContentId,
      contentTitle: _analyticsContentTitle,
      surface: _analyticsSurface,
      sessionId: _analyticsSessionId,
      event: event,
      sessionElapsedMs: _analyticsElapsedMs,
      provider: _analyticsProviderName,
      startupMs: startupMs,
      bufferingMs: bufferingMs,
      bufferCount: _analyticsBufferCount,
      value: value,
      error: error,
    );
  }

  void _startPlaybackMonitor() {
    _progressCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bool initialized;
      try {
        initialized = _betterPlayerController.isVideoInitialized() == true;
      } catch (error) {
        debugPrint('[Player] playback monitor waiting for data source: $error');
        return;
      }
      if (initialized &&
          _betterPlayerController.videoPlayerController != null) {
        final position =
            _betterPlayerController.videoPlayerController!.value.position;
        final duration =
            _betterPlayerController.videoPlayerController!.value.duration;
        final isFullScreen = _betterPlayerController.isFullScreen;
        final value = _betterPlayerController.videoPlayerController!.value;

        final now = DateTime.now();
        if (!_preRollActive &&
            value.isPlaying &&
            !value.isBuffering &&
            (_lastWellnessCheckpointAt == null ||
                now.difference(_lastWellnessCheckpointAt!).inSeconds >= 30)) {
          _lastWellnessCheckpointAt = now;
          unawaited(_persistWellnessSession());
        }

        if (duration != null && duration.inMilliseconds > 0) {
          if (_preRollActive) return;

          // Completion exclusively owns the post-play surface. Without this
          // guard the periodic monitor sees 100% progress and recreates the
          // teaser immediately after completion removed it.
          if (_playbackCompletionHandled) {
            if (_showNextEpisodeButton || _nextEpisodeOverlay != null) {
              _showNextEpisodeButton = false;
              _hideNextEpisodeOverlay();
            }
            return;
          }

          _updateIntroDbSegment(position, duration);

          final completed = _completionDetector.observe(
            position: position,
            duration: duration,
            isPlaying: value.isPlaying,
            isBuffering: value.isBuffering,
          );
          if (completed) {
            _handlePlaybackCompleted(source: 'position_fallback');
            return;
          }

          if (widget.mediaType != MediaType.tvShow) return;
          final progress = position.inMilliseconds / duration.inMilliseconds;
          final hasIntroDbOutroTiming = _introDbTimings.segments.any(
            (segment) => segment.type == IntroDbSegmentType.credits,
          );
          final introDbOutroReached = _introDbTimings.segments.any(
            (segment) =>
                segment.type == IntroDbSegmentType.credits &&
                position.inMilliseconds >= segment.startMs,
          );
          final shouldShowNextEpisode = shouldShowNextEpisodeTeaser(
            progress: progress,
            introDbLookupSettled: _introDbLookupSettled,
            hasIntroDbOutroTiming: hasIntroDbOutroTiming,
            introDbOutroReached: introDbOutroReached,
          );
          if (progress >= 0.90 || introDbOutroReached) {
            _logNextEpisodeState(
              'near_end',
              position: position,
              duration: duration,
            );
          }

          // An IntroDB outro is authoritative. The percentage threshold is
          // only a fallback once the lookup has settled without an outro.
          // TV playback already owns the full screen route, so Better Player's
          // internal fullscreen flag is intentionally false there.
          if (shouldShowNextEpisode &&
              !_showNextEpisodeButton &&
              !_nextEpisodeButtonDismissed &&
              _hasNextEpisode() &&
              (widget.useTvControls || isFullScreen) &&
              betterPlayerControlsConfiguration.enableNextEpisodeButton) {
            _showNextEpisodeButton = true;
            if (widget.useTvControls) {
              // IntroDB's credits mark are trusted to count down to the next
              // episode; the percentage fallback only offers it.
              _showTvNextEpisodePrompt(
                startCountdown: introDbOutroReached,
                atCredits: true,
              );
            } else {
              _showNextEpisodeOverlay();
            }
          } else if ((!shouldShowNextEpisode ||
                  (!widget.useTvControls && !isFullScreen)) &&
              _showNextEpisodeButton) {
            _showNextEpisodeButton = false;
            _nextEpisodeButtonDismissed = false;
            if (widget.useTvControls) {
              _clearTvNextEpisodePrompt(showControls: false);
            } else {
              _hideNextEpisodeOverlay();
            }
          }
        }
      }
    });
  }

  Future<void> _loadIntroDbTimings() async {
    if (_introDbLoading || _introDbLookupComplete) {
      debugPrint(
        '[Player][IntroDB] lookup skipped: loading=$_introDbLoading '
        'complete=$_introDbLookupComplete',
      );
      return;
    }
    final durationMs = _betterPlayerController
            .videoPlayerController?.value.duration?.inMilliseconds ??
        0;
    final isTv = widget.mediaType == MediaType.tvShow;
    final tmdbId =
        isTv ? widget.tvMetadata?.tvId : widget.movieMetadata?.movieId;
    if (tmdbId == null || tmdbId <= 0) {
      _introDbLookupSettled = true;
      debugPrint(
        '[Player][IntroDB] lookup skipped: missing TMDB ID '
        'mediaType=${widget.mediaType} tvId=${widget.tvMetadata?.tvId} '
        'movieId=${widget.movieMetadata?.movieId}',
      );
      return;
    }
    debugPrint(
      '[Player][IntroDB] loading '
      'mediaType=${isTv ? 'tv' : 'movie'} tmdbId=$tmdbId '
      'season=${widget.tvMetadata?.seasonNumber} '
      'episode=${widget.tvMetadata?.episodeNumber} durationMs=$durationMs',
    );
    _introDbLoading = true;
    _introDbLookupSettled = false;
    final requestId = ++_introDbRequestId;
    try {
      final timings = await _introDbService.fetch(
        tmdbId: tmdbId,
        isTv: isTv,
        season: widget.tvMetadata?.seasonNumber,
        episode: widget.tvMetadata?.episodeNumber,
        durationMs: durationMs > 0 ? durationMs : null,
      );
      if (!mounted || requestId != _introDbRequestId) return;
      setState(() {
        _introDbTimings = timings;
        _activeIntroDbSegment = null;
        _skippedIntroDbSegments.clear();
      });
      _introDbLookupComplete = true;
      debugPrint(
        '[Player][IntroDB] timings ready count=${timings.segments.length}',
      );
    } catch (error) {
      if (requestId == _introDbRequestId) {
        _introDbLookupComplete = false;
        debugPrint('[Player][IntroDB] timings unavailable: $error');
      }
    } finally {
      if (requestId == _introDbRequestId) {
        _introDbLoading = false;
        _introDbLookupSettled = true;
      }
    }
  }

  bool _introDbTypeEnabled(IntroDbSegmentType type) {
    return settings.enableIntroDbSkipButtons;
  }

  String _segmentKey(IntroDbSegment segment) =>
      '${segment.type.name}:${segment.startMs}:${segment.endMs}';

  void _updateIntroDbSegment(Duration position, Duration duration) {
    if (_introDbTimings.segments.isEmpty) return;
    final positionMs = position.inMilliseconds;
    IntroDbSegment? active;
    var creditsActive = false;
    for (final segment in _introDbTimings.segments) {
      final endMs = segment.endMs ?? duration.inMilliseconds;
      final contains = positionMs >= segment.startMs && positionMs < endMs;
      if (contains && segment.type == IntroDbSegmentType.credits) {
        creditsActive = true;
      }
      if (active == null &&
          contains &&
          settings.enableIntroDbSkipButtons &&
          _introDbTypeEnabled(segment.type) &&
          !_skippedIntroDbSegments.contains(_segmentKey(segment))) {
        active = segment;
      }
    }
    final creditsStateChanged = creditsActive != _introDbCreditsActive;
    _introDbCreditsActive = creditsActive;
    if (creditsStateChanged) {
      debugPrint('[Player][IntroDB] credits active=$creditsActive');
    }
    if (creditsActive &&
        !_playbackCompletionHandled &&
        settings.enableNextEpisodeButton &&
        widget.mediaType == MediaType.tvShow &&
        _hasNextEpisode() &&
        (widget.useTvControls || _betterPlayerController.isFullScreen) &&
        !_showNextEpisodeButton) {
      _showNextEpisodeButton = true;
      if (widget.useTvControls) {
        _showTvNextEpisodePrompt(startCountdown: true, atCredits: true);
      } else {
        _showNextEpisodeOverlay();
      }
    }
    if (active != _activeIntroDbSegment) {
      debugPrint(
        '[Player][IntroDB] active segment '
        '${active == null ? 'none' : '${active.type.name} '
            '${active.startMs}-${active.endMs ?? duration.inMilliseconds}'}',
      );
    }
    if (active != _activeIntroDbSegment && mounted) {
      setState(() => _activeIntroDbSegment = active);
      _nextEpisodeOverlay?.markNeedsBuild();
    }
    if (active == null) {
      for (final segment in _introDbTimings.segments) {
        if (positionMs < segment.startMs) {
          _skippedIntroDbSegments.remove(_segmentKey(segment));
        }
      }
    }
  }

  void _skipActiveIntroDbSegment() {
    final segment = _activeIntroDbSegment;
    if (segment == null) return;
    final duration =
        _betterPlayerController.videoPlayerController?.value.duration;
    final endMs = segment.endMs ?? duration?.inMilliseconds;
    if (endMs == null || endMs <= segment.startMs) return;
    _skippedIntroDbSegments.add(_segmentKey(segment));
    debugPrint(
      '[Player][IntroDB] skipping ${segment.type.name} '
      '${segment.startMs}ms -> ${endMs}ms',
    );
    setState(() => _activeIntroDbSegment = null);
    _nextEpisodeOverlay?.markNeedsBuild();
    // IntroDB is always user-driven. This is the only IntroDB path that seeks,
    // and it is invoked exclusively by the visible skip button.
    unawaited(_betterPlayerController.seekTo(Duration(milliseconds: endMs)));
  }

  String _introDbLabel(IntroDbSegmentType type) => switch (type) {
        IntroDbSegmentType.intro => tr('skip_intro'),
        IntroDbSegmentType.recap => tr('skip_recap'),
        IntroDbSegmentType.credits => tr('skip_credits'),
        IntroDbSegmentType.preview => tr('skip_preview'),
      };

  /// The controls keep this button outside their fade, so they ask whether it
  /// has anything to skip before giving it space. On television the TV menu and
  /// the next-episode prompt own the select key while they are up, so the skip
  /// button steps aside rather than competing with them.
  bool _canSkipIntroDbSegment() =>
      _activeIntroDbSegment != null &&
      widget.settings.enableIntroDbSkipButtons &&
      (!widget.useTvControls || (_tvMenu == null && _tvNextEpisode == null));

  Widget _buildIntroDbSkipButton(BuildContext context) {
    final segment = _activeIntroDbSegment;
    if (segment == null || !_canSkipIntroDbSegment()) {
      return const SizedBox.shrink();
    }
    if (widget.useTvControls) {
      return _TvSkipButton(
        label: _introDbLabel(segment.type),
        onPressed: _skipActiveIntroDbSegment,
      );
    }
    return FilledButton.icon(
      onPressed: _skipActiveIntroDbSegment,
      icon: Icon(PhosphorIcons.skipForward()),
      label: Text(_introDbLabel(segment.type)),
    );
  }

  bool _hasNextEpisode() {
    _restoreEpisodeSnapshotIfNeeded('has_next_episode');
    final episodes = widget.tvMetadata?.seasonEpisodes;
    if (episodes == null || episodes.isEmpty) {
      return false;
    }

    final currentIndex = _currentEpisodeIndex();

    return currentIndex >= 0 && currentIndex < episodes.length - 1;
  }

  void _restoreEpisodeSnapshotIfNeeded(String stage) {
    final metadata = widget.tvMetadata;
    if (metadata == null ||
        metadata.seasonEpisodes?.isNotEmpty == true ||
        _contentMenuEpisodes.isEmpty) {
      return;
    }
    metadata.seasonEpisodes = List<EpisodeMetadata>.of(_contentMenuEpisodes);
    debugPrint(
      '[NextEpisodeDebug][episodes_restored] stage=$stage '
      'snapshotEpisodes=${_contentMenuEpisodes.length} '
      'current=S${metadata.seasonNumber}E${metadata.episodeNumber}',
    );
  }

  void _logNextEpisodeState(
    String stage, {
    Duration? position,
    Duration? duration,
    bool force = false,
  }) {
    _restoreEpisodeSnapshotIfNeeded(stage);
    final metadata = widget.tvMetadata;
    final episodes = metadata?.seasonEpisodes;
    final currentIndex = _currentEpisodeIndex();
    final strictIndex = episodes?.indexWhere(
          (episode) =>
              episode.episodeNumber == metadata?.episodeNumber &&
              episode.seasonNumber == metadata?.seasonNumber,
        ) ??
        -1;
    final hasNext = episodes != null &&
        currentIndex >= 0 &&
        currentIndex < episodes.length - 1;
    final nextEpisode = hasNext ? episodes[currentIndex + 1] : null;
    final isFullScreen = _betterPlayerControllerInitialized
        ? _betterPlayerController.isFullScreen
        : null;
    final hasIntroDbOutroTiming = _introDbTimings.segments.any(
      (segment) => segment.type == IntroDbSegmentType.credits,
    );
    final introDbOutroReached = position != null &&
        _introDbTimings.segments.any(
          (segment) =>
              segment.type == IntroDbSegmentType.credits &&
              position.inMilliseconds >= segment.startMs,
        );
    final signature = <Object?>[
      stage,
      metadata?.seasonNumber,
      metadata?.episodeNumber,
      metadata?.episodeId,
      episodes?.length,
      currentIndex,
      strictIndex,
      nextEpisode?.seasonNumber,
      nextEpisode?.episodeNumber,
      hasNext,
      widget.useTvControls,
      isFullScreen,
      betterPlayerControlsConfiguration.enableNextEpisodeButton,
      _showNextEpisodeButton,
      _nextEpisodeButtonDismissed,
      _introDbCreditsActive,
      _introDbLookupSettled,
      hasIntroDbOutroTiming,
      introDbOutroReached,
    ].join('|');
    if (!force && signature == _lastNextEpisodeDebugSignature) return;
    _lastNextEpisodeDebugSignature = signature;
    final progress = position != null &&
            duration != null &&
            duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).toStringAsFixed(4)
        : 'n/a';
    debugPrint(
      '[NextEpisodeDebug][$stage] media=S${metadata?.seasonNumber}'
      'E${metadata?.episodeNumber} episodeId=${metadata?.episodeId} '
      'episodes=${episodes?.length ?? 0} currentIndex=$currentIndex '
      'strictIndex=$strictIndex hasNext=$hasNext '
      'next=S${nextEpisode?.seasonNumber}E${nextEpisode?.episodeNumber} '
      'progress=$progress positionMs=${position?.inMilliseconds} '
      'durationMs=${duration?.inMilliseconds} tvControls=${widget.useTvControls} '
      'fullscreen=$isFullScreen setting='
      '${betterPlayerControlsConfiguration.enableNextEpisodeButton} '
      'show=$_showNextEpisodeButton dismissed=$_nextEpisodeButtonDismissed '
      'credits=$_introDbCreditsActive introDbSettled=$_introDbLookupSettled '
      'outroTiming=$hasIntroDbOutroTiming outroReached=$introDbOutroReached',
    );
  }

  int _currentEpisodeIndex() {
    _restoreEpisodeSnapshotIfNeeded('current_episode_index');
    final metadata = widget.tvMetadata;
    final episodes = metadata?.seasonEpisodes;
    if (metadata == null || episodes == null || episodes.isEmpty) return -1;

    final bySeasonAndNumber = episodes.indexWhere(
      (episode) =>
          episode.episodeNumber == metadata.episodeNumber &&
          (metadata.seasonNumber == null ||
              episode.seasonNumber == metadata.seasonNumber),
    );
    if (bySeasonAndNumber >= 0) return bySeasonAndNumber;

    final episodeId = metadata.episodeId;
    if (episodeId == null) return -1;
    return episodes.indexWhere((episode) => episode.episodeId == episodeId);
  }

  void _showNextEpisodeOverlay() {
    _logNextEpisodeState('floating_overlay_requested', force: true);
    if (_playbackCompletionHandled) {
      debugPrint(
        '[NextEpisodeDebug][floating_overlay_skipped] reason=completed',
      );
      return;
    }
    if (_nextEpisodeOverlay != null) {
      debugPrint(
        '[NextEpisodeDebug][floating_overlay_skipped] reason=already_inserted',
      );
      return;
    }

    _nextEpisodeOverlay = OverlayEntry(
      builder: (context) => _nextEpisodeWidget.buildNextEpisodeFloatingButton(
        context: context,
        tvMetadata: widget.tvMetadata!,
        showNextEpisodeButton: _showNextEpisodeButton,
        controlsVisible: _playerControlsVisible,
        onSaveProgress: _handleContentSwitch,
        closePlayer: () => Navigator.pop(context),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_nextEpisodeOverlay!);
    debugPrint(
      '[NextEpisodeDebug][floating_overlay_inserted] '
      'overlay=${identityHashCode(Overlay.of(context, rootOverlay: true))}',
    );
  }

  void _hideNextEpisodeOverlay() {
    _nextEpisodeOverlay?.remove();
    _nextEpisodeOverlay = null;
  }

  void startDurationTimer() {
    if (_durationTimer == null) {
      _durationTimer =
          Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        setState(() {
          playbackDurationInSeconds++;
        });
      });

      _resetTimer = Timer.periodic(const Duration(seconds: 60), (Timer timer) {
        resetDurationTimer();
      });
    }
  }

  BetterPlayerDataSource _buildDataSource({
    required Map<String, String> sources,
    required List<BetterPlayerSubtitlesSource> subtitles,
    required Map<String, BetterPlayerVideoFormat?>? videoFormats,
    required Map<String, Map<String, String>> videoHeaders,
  }) {
    final selectedSource = VideoUtils.preferredVideoSource(
      sources,
      widget.settings.defaultVideoResolution,
    )!;
    final link = selectedSource.value;
    final suppliedHeaders = videoHeaders[selectedSource.key];
    final resolvedHeaders = suppliedHeaders?.isNotEmpty == true
        ? suppliedHeaders!
        : VideoUtils.inferVideoHeaders(link) ?? const <String, String>{};
    final resolutionVideoFormats = <String, BetterPlayerVideoFormat?>{
      for (final source in sources.entries)
        source.key:
            videoFormats?[source.key] ?? _inferVideoFormat(source.value),
    };
    final resolutionHeaders = <String, Map<String, String>>{
      for (final source in sources.entries)
        source.key: videoHeaders[source.key]?.isNotEmpty == true
            ? videoHeaders[source.key]!
            : VideoUtils.inferVideoHeaders(source.value) ??
                const <String, String>{},
    };
    final resolutionDisplayNames = <String, String>{
      for (final source in sources.entries)
        source.key: _resolutionDisplayName(source.key),
    };
    final resolutionDescriptions = _resolutionDescriptions(sources);

    final appSuppliedSubtitles = <BetterPlayerSubtitlesSource>[
      ...subtitles,
      ..._localSubtitles.appliedSubtitles,
      ..._externalSubtitles.appliedSubtitles,
    ];

    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      link,
      resolutions: sources.length > 1 ? sources : null,
      selectedResolution: selectedSource.key,
      resolutionVideoFormats:
          sources.length > 1 ? resolutionVideoFormats : null,
      resolutionHeaders: sources.length > 1 ? resolutionHeaders : null,
      resolutionDisplayNames:
          sources.length > 1 ? resolutionDisplayNames : null,
      resolutionDescriptions:
          sources.length > 1 ? resolutionDescriptions : null,
      videoFormat: videoFormats?[selectedSource.key] ?? _inferVideoFormat(link),
      headers: resolvedHeaders,
      castConfiguration: widget.useTvControls
          ? null
          : BetterPlayerCastConfiguration(
              title: widget.mediaType == MediaType.movie
                  ? widget.movieMetadata?.movieName
                  : widget.tvMetadata?.seriesName,
              subtitle: widget.mediaType == MediaType.movie
                  ? widget.movieMetadata?.releaseYear?.toString()
                  : 'S${widget.tvMetadata?.seasonNumber ?? 0} '
                      'E${widget.tvMetadata?.episodeNumber ?? 0} · '
                      '${widget.tvMetadata?.episodeName ?? ''}',
              imageUrl: _castArtworkUrl(),
              contentType: _castContentType(
                videoFormats?[selectedSource.key] ?? _inferVideoFormat(link),
              ),
              requestHeaders: resolvedHeaders,
              customData: <String, Object?>{
                'mediaType':
                    widget.mediaType == MediaType.movie ? 'movie' : 'tv',
                'mediaId': widget.mediaType == MediaType.movie
                    ? widget.movieMetadata?.movieId
                    : widget.tvMetadata?.tvId,
                if (widget.tvMetadata != null)
                  'seasonNumber': widget.tvMetadata!.seasonNumber,
                if (widget.tvMetadata != null)
                  'episodeNumber': widget.tvMetadata!.episodeNumber,
              },
            ),
      subtitles: appSuppliedSubtitles,
      // Streaming already has a bounded in-memory buffer. A persistent media
      // cache can fill the limited internal storage available on Android TVs.
      cacheConfiguration: const BetterPlayerCacheConfiguration(useCache: false),
      bufferingConfiguration: betterPlayerBufferingConfiguration,
    );
  }

  String _resolutionDisplayName(String sourceKey) {
    final separator = sourceKey.indexOf(' · ');
    return separator < 0 ? sourceKey : sourceKey.substring(0, separator);
  }

  VideoProvider? _providerByCode(String? code) {
    if (code == null) return null;
    for (final provider
        in widget.availableProviders ?? const <VideoProvider>[]) {
      if (provider.codeName == code) return provider;
    }
    return null;
  }

  Future<void> _startActiveProviderEnrichment() async {
    final providerCode = _currentProviderCode;
    final provider = _providerByCode(providerCode);
    if (providerCode == null ||
        provider?.type != VideoProviderType.scraperApi) {
      await _initialDataSourceReady.future;
      unawaited(_loadActiveSourceSizes(providerCode));
      return;
    }
    final fullResult = _fullProviderResults[providerCode] ??=
        widget.mediaType == MediaType.movie
            ? ProviderLoader.loadMovieFromProvider(
                provider: provider!,
                movieId: widget.movieMetadata!.movieId!,
                scraperApiUrl: _resolveScraperApiUrl(),
                full: true,
              )
            : ProviderLoader.loadTVFromProvider(
                provider: provider!,
                tvId: widget.tvMetadata!.tvId!,
                seasonNumber: widget.tvMetadata!.seasonNumber!,
                episodeNumber: widget.tvMetadata!.episodeNumber!,
                scraperApiUrl: _resolveScraperApiUrl(),
                full: true,
              );
    await _initialDataSourceReady.future;
    if (!mounted || providerCode != _currentProviderCode) return;
    unawaited(_loadActiveSourceSizes(providerCode));
    final result = await fullResult;
    if (!mounted || providerCode != _currentProviderCode) return;
    if (result.success && result.videoLinks?.isNotEmpty == true) {
      _mergeActiveProviderResult(providerCode, result);
    }
    unawaited(_loadActiveSourceSizes(providerCode));
  }

  void _mergeActiveProviderResult(
    String providerCode,
    ProviderLoadResult result,
  ) {
    final merged = <RegularVideoLinks>[];
    final seen = <String>{};
    for (final link in [
      ...(_rawVideoLinksByProvider[providerCode] ??
          const <RegularVideoLinks>[]),
      ...?result.videoLinks,
    ]) {
      final identity = _videoLinkIdentity(link);
      if (identity != null && seen.add(identity)) merged.add(link);
    }
    if (merged.isEmpty) return;
    _rawVideoLinksByProvider[providerCode] = merged;
    final sources = VideoUtils.reverseVideoQualityMap(
      VideoUtils.convertVideoLinksToMap(merged),
    );
    final formats = VideoUtils.reverseVideoQualityMap(
      VideoUtils.convertVideoFormatsToMap(merged),
    );
    final headers = VideoUtils.reverseVideoQualityMap(
      VideoUtils.convertVideoHeadersToMap(merged),
    );
    final tokens = VideoUtils.reverseVideoQualityMap(
      VideoUtils.convertVideoSizeTokensToMap(merged),
    );
    final currentUrl = _betterPlayerController.betterPlayerDataSource?.url;
    final selected = sources.entries
        .firstWhere(
          (entry) => entry.value == currentUrl,
          orElse: () => sources.entries.first,
        )
        .key;
    final mergedSubtitles = _mergeSubtitles(result.subtitleLinks ?? const []);
    final allSubtitles = <BetterPlayerSubtitlesSource>[
      ...mergedSubtitles,
      ..._localSubtitles.appliedSubtitles,
      ..._externalSubtitles.appliedSubtitles,
    ];
    _activeSources = sources;
    _activeVideoFormats = formats;
    _activeVideoHeaders = headers;
    _activeVideoSizeTokens = tokens;
    _activeSubtitles = mergedSubtitles;
    _loadedProviders[providerCode] = ProviderVideoSource(
      providerCode: providerCode,
      providerName: _providerDisplayName(providerCode),
      videoSources: sources,
      videoFormats: formats,
      videoHeaders: headers,
      videoSizeTokens: tokens,
      subtitles: mergedSubtitles,
      rawVideoLinks: merged,
    );
    if (!_betterPlayerControllerInitialized ||
        _betterPlayerController.betterPlayerDataSource == null) {
      return;
    }
    _betterPlayerController.updateDataSourceMetadata(
      resolutions: sources,
      selectedResolution: selected,
      resolutionVideoFormats: formats,
      resolutionHeaders: headers,
      resolutionDisplayNames: _resolutionNames(sources),
      resolutionDescriptions: _resolutionDescriptions(sources),
      subtitles: allSubtitles,
    );
    setState(() {});
  }

  String? _videoLinkIdentity(RegularVideoLinks link) {
    final url = link.url?.trim();
    if (url == null || url.isEmpty) return null;
    final headers = (link.headers ?? const <String, String>{})
        .entries
        .map((entry) => '${entry.key.toLowerCase()}=${entry.value.trim()}')
        .toList()
      ..sort();
    final format = link.isM3U8 == true
        ? 'hls'
        : link.isDash == true
            ? 'dash'
            : 'other';
    return '$url|$format|${headers.join('&')}';
  }

  List<BetterPlayerSubtitlesSource> _mergeSubtitles(
    List<RegularSubtitleLinks> additional,
  ) {
    final merged = List<BetterPlayerSubtitlesSource>.of(_activeSubtitles);
    final keys = <String>{
      for (final subtitle in merged)
        '${subtitle.urls?.first ?? ''}|${subtitle.name ?? ''}',
    };
    for (final subtitle in additional) {
      final url = subtitle.url?.trim();
      final language = subtitle.language ?? tr('not_available');
      if (url == null || url.isEmpty || !keys.add('$url|$language')) continue;
      merged.add(BetterPlayerSubtitlesSource(
        type: BetterPlayerSubtitlesSourceType.network,
        urls: [url],
        name: language,
        headers: subtitle.headers,
      ));
    }
    return merged;
  }

  Future<void> _loadActiveSourceSizes(String? providerCode) async {
    if (!mounted ||
        providerCode != _currentProviderCode ||
        _activeVideoSizeTokens.isEmpty) {
      return;
    }
    final cacheKey = providerCode ?? '';
    final generation = (_sizeRequestGenerations[cacheKey] ?? 0) + 1;
    _sizeRequestGenerations[cacheKey] = generation;
    final tokens = Map<String, String>.of(_activeVideoSizeTokens);
    await StreamSizeEstimator.load(
      scraperApiUrl: _resolveScraperApiUrl(),
      tokens: tokens,
      cacheByToken: _streamSizeCacheByToken,
      onEstimate: (_, __) {
        if (!mounted ||
            providerCode != _currentProviderCode ||
            _sizeRequestGenerations[cacheKey] != generation) {
          return;
        }
        _betterPlayerController.updateDataSourceMetadata(
          resolutionDisplayNames: _resolutionNames(_activeSources),
        );
      },
    );
    if (mounted &&
        providerCode == _currentProviderCode &&
        _sizeRequestGenerations[cacheKey] == generation) {
      _betterPlayerController.updateDataSourceMetadata(
        resolutionDisplayNames: _resolutionNames(_activeSources),
      );
    }
  }

  Map<String, String> _resolutionNames(Map<String, String> sources) => {
        for (final key in sources.keys)
          key: () {
            final token = _activeVideoSizeTokens[key];
            final bytes = token == null ? null : _streamSizeCacheByToken[token];
            final base = _resolutionDisplayName(key);
            return bytes == null ? base : '$base (~${_formatBytes(bytes)})';
          }(),
      };

  Map<String, String> _resolutionDescriptions(Map<String, String> sources) => {
        for (final key in sources.keys)
          if (key.contains(' · ')) key: key.split(' · ').skip(1).join(' · '),
      };

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  String? _castArtworkUrl() {
    final path = widget.mediaType == MediaType.movie
        ? widget.movieMetadata?.backdropPath ?? widget.movieMetadata?.posterPath
        : widget.tvMetadata?.backdropPath ?? widget.tvMetadata?.posterPath;
    return path == null || path.isEmpty
        ? null
        : '${TMDB_BASE_IMAGE_URL}w780$path';
  }

  String _castContentType(BetterPlayerVideoFormat? format) => switch (format) {
        BetterPlayerVideoFormat.hls => 'application/x-mpegURL',
        BetterPlayerVideoFormat.dash => 'application/dash+xml',
        _ => 'video/mp4',
      };

  void _applyPreferredAdaptiveQuality() {
    final preferredHeight = widget.settings.defaultVideoResolution;
    if (preferredHeight == 0) return;

    final tracks = _betterPlayerController.betterPlayerAsmsTracks
        .where((track) => (track.height ?? 0) > 0)
        .toList();
    if (tracks.isEmpty) return;

    final exact = tracks.where((track) => track.height == preferredHeight);
    if (exact.isNotEmpty) {
      _betterPlayerController.setTrack(exact.first);
      return;
    }

    final atOrBelow = tracks.where(
      (track) => track.height! <= preferredHeight,
    );
    if (atOrBelow.isNotEmpty) {
      _betterPlayerController.setTrack(
        atOrBelow.reduce(
          (best, track) => track.height! > best.height! ? track : best,
        ),
      );
      return;
    }
    _betterPlayerController.setTrack(
      tracks.reduce(
        (best, track) => track.height! < best.height! ? track : best,
      ),
    );
  }

  BetterPlayerVideoFormat? _inferVideoFormat(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(url);
    final path = uri?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.m3u8') || path.contains('/playlist/')) {
      return BetterPlayerVideoFormat.hls;
    }

    if (path.endsWith('.mpd')) {
      return BetterPlayerVideoFormat.dash;
    }

    return null;
  }

  void pauseDurationTimer() {
    updateAndLogTotalStreamingDuration(playbackDurationInSeconds);
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void resetDurationTimer() {
    setState(() {
      playbackDurationInSeconds = 0;
    });
  }

  Future<void> insertRecentMovieData() async {
    await _dataManagement.insertRecentMovieData(
      context: context,
      betterPlayerController: _betterPlayerController,
      duration: duration,
      movieMetadata: widget.movieMetadata!,
    );
  }

  Future<void> insertRecentEpisodeData() async {
    await _dataManagement.insertRecentEpisodeData(
      context: context,
      betterPlayerController: _betterPlayerController,
      duration: duration,
      tvMetadata: widget.tvMetadata!,
    );
  }

  /// Close the player (pop navigation)
  void _closePlayer() {
    Navigator.pop(context);
  }

  BuildContext get _playerModalContext {
    // Fullscreen Better Player controls live on a separate root route. Use
    // the active navigator overlay so sheets are pushed above that route.
    final navigator = Navigator.of(context, rootNavigator: true);
    return navigator.overlay?.context ?? context;
  }

  MovieStreamMetadata? get _movieMetadataForContentMenu =>
      widget.movieMetadata;

  TVStreamMetadata? get _tvMetadataForContentMenu {
    final metadata = widget.tvMetadata;
    if (metadata != null &&
        metadata.seasonEpisodes?.isNotEmpty != true &&
        _contentMenuEpisodes.isNotEmpty) {
      metadata.seasonEpisodes = List<EpisodeMetadata>.of(_contentMenuEpisodes);
      debugPrint(
        '[PlayerContentMenu] restored '
        '${metadata.seasonEpisodes!.length} season episodes',
      );
    }
    if (metadata != null &&
        metadata.allSeasons?.isNotEmpty != true &&
        _contentMenuSeasons.isNotEmpty) {
      metadata.allSeasons = List<SeasonMetadata>.of(_contentMenuSeasons);
    }
    return metadata;
  }

  Future<void> _openEpisodeList() async {
    debugPrint(
      '[PlayerContentMenu] open episodes requested '
      'mounted=$mounted menuOpen=$_isContentMenuOpen '
      'useTvControls=${widget.useTvControls}',
    );
    if (!mounted) {
      debugPrint('[PlayerContentMenu] episodes aborted: player unmounted');
      return;
    }
    if (_isContentMenuOpen) {
      debugPrint('[PlayerContentMenu] episodes aborted: menu already open');
      return;
    }
    if (widget.useTvControls) {
      debugPrint('[PlayerContentMenu] episodes routed to TV menu');
      _showTvEpisodeMenu();
      return;
    }

    final metadata = _tvMetadataForContentMenu;
    if (metadata?.seasonEpisodes?.isNotEmpty != true) {
      debugPrint('[PlayerContentMenu] episodes aborted: metadata is empty');
      return;
    }
    _isContentMenuOpen = true;
    try {
      final menuContext = _playerModalContext;
      final navigator = Navigator.of(menuContext, rootNavigator: true);
      debugPrint(
        '[PlayerContentMenu] showing episodes sheet '
        'episodes=${metadata!.seasonEpisodes!.length} '
        'context=${identityHashCode(menuContext)} '
        'overlay=${identityHashCode(navigator.overlay)} '
        'canPop=${navigator.canPop()}',
      );
      await _episodeSelection.showEpisodeSelectionBottomSheet(
        context: menuContext,
        colors: widget.colors,
        tvMetadata: metadata,
        onSaveProgress: _handleContentSwitch,
        closePlayer: _closePlayer,
      );
      debugPrint('[PlayerContentMenu] episodes sheet future completed');
    } catch (error, stackTrace) {
      _reportContentMenuError(error, stackTrace);
    } finally {
      _isContentMenuOpen = false;
      debugPrint('[PlayerContentMenu] episodes menu state reset');
    }
  }

  Future<void> _openMovieRecommendations() async {
    debugPrint(
      '[PlayerContentMenu] open recommendations requested '
      'mounted=$mounted menuOpen=$_isContentMenuOpen '
      'useTvControls=${widget.useTvControls}',
    );
    if (!mounted) {
      debugPrint(
          '[PlayerContentMenu] recommendations aborted: player unmounted');
      return;
    }
    if (_isContentMenuOpen) {
      debugPrint(
          '[PlayerContentMenu] recommendations aborted: menu already open');
      return;
    }
    if (widget.useTvControls) {
      debugPrint('[PlayerContentMenu] recommendations routed to TV menu');
      _showTvMovieRecommendationsMenu();
      return;
    }

    final metadata = _movieMetadataForContentMenu;
    if (metadata?.recommendations?.isNotEmpty != true) {
      debugPrint(
          '[PlayerContentMenu] recommendations aborted: metadata is empty');
      return;
    }
    _isContentMenuOpen = true;
    try {
      final menuContext = _playerModalContext;
      final navigator = Navigator.of(menuContext, rootNavigator: true);
      debugPrint(
        '[PlayerContentMenu] showing recommendations sheet '
        'recommendations=${metadata!.recommendations!.length} '
        'context=${identityHashCode(menuContext)} '
        'overlay=${identityHashCode(navigator.overlay)} '
        'canPop=${navigator.canPop()}',
      );
      await _movieRecommendations.showMovieRecommendationsBottomSheet(
        context: menuContext,
        colors: widget.colors,
        movieMetadata: metadata,
        onSaveProgress: _handleContentSwitch,
        closePlayer: _closePlayer,
      );
      debugPrint('[PlayerContentMenu] recommendations sheet future completed');
    } catch (error, stackTrace) {
      _reportContentMenuError(error, stackTrace);
    } finally {
      _isContentMenuOpen = false;
      debugPrint('[PlayerContentMenu] recommendations menu state reset');
    }
  }

  void _reportContentMenuError(Object error, StackTrace stackTrace) {
    debugPrint('[PlayerContentMenu] unable to open content menu: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(tr('error_occured'))),
    );
  }

  Future<void> _persistWellnessSession({
    bool completed = false,
    bool syncImmediately = false,
  }) async {
    if (_preRollActive) return;
    final value = _betterPlayerController.videoPlayerController?.value;
    final positionMs = value?.position.inMilliseconds ?? 0;
    final durationMs = value?.duration?.inMilliseconds ?? duration * 1000;
    final isMovie = widget.mediaType == MediaType.movie;
    final movie = widget.movieMetadata;
    final episode = widget.tvMetadata;
    final rawId = isMovie ? movie?.movieId : episode?.episodeId;
    final fallbackEpisodeId = episode == null
        ? null
        : '${episode.tvId ?? 'unknown'}:${episode.seasonNumber ?? 0}:'
            '${episode.episodeNumber ?? 0}';
    final contentId = rawId?.toString() ?? fallbackEpisodeId;
    final title = isMovie ? movie?.movieName : episode?.seriesName;
    if (contentId == null || title == null || title.trim().isEmpty) return;
    final releaseDate = isMovie ? movie?.releaseDate : episode?.airDate;
    await WellnessProvider.instance.recordPlayback(
      sessionId: _analyticsSessionId,
      tracker: _wellnessTracker,
      mediaType: isMovie ? WellnessMediaType.movie : WellnessMediaType.episode,
      source: WellnessPlaybackSource.streaming,
      contentId: contentId,
      seriesId: isMovie ? null : episode?.tvId?.toString(),
      title: title,
      subtitle: isMovie ? null : episode?.episodeName,
      seasonNumber: episode?.seasonNumber,
      episodeNumber: episode?.episodeNumber,
      durationMs: durationMs,
      progressEndMs: positionMs,
      completed: completed,
      posterPath: isMovie ? movie?.posterPath : episode?.posterPath,
      backdropPath: isMovie ? movie?.backdropPath : episode?.backdropPath,
      releaseYear: isMovie
          ? movie?.releaseYear
          : DateTime.tryParse(releaseDate ?? '')?.year,
      provider: _analyticsProviderName,
      genres: isMovie ? movie?.genres ?? const [] : episode?.genres ?? const [],
      languages: isMovie
          ? movie?.languages ?? const []
          : episode?.languages ?? const [],
      countries: isMovie
          ? movie?.countries ?? const []
          : episode?.countries ?? const [],
      syncImmediately: syncImmediately,
    );
  }

  /// Handles saving progress and analytics before switching to a new episode/movie
  Future<void> _handleContentSwitch() async {
    await _persistWellnessSession(
      completed: _playbackCompletionHandled,
      syncImmediately: true,
    );
    if (!mounted) return;
    await _dataManagement.handleContentSwitch(
      context: context,
      mediaType: widget.mediaType!,
      betterPlayerController: _betterPlayerController,
      duration: duration,
      playbackDurationInSeconds: playbackDurationInSeconds,
      movieMetadata: widget.movieMetadata,
      tvMetadata: widget.tvMetadata,
    );

    // Reset playback duration timer for next content
    playbackDurationInSeconds = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final isInBackground = (state == AppLifecycleState.paused) ||
        (state == AppLifecycleState.inactive);
    if (isInBackground) {
      unawaited(_persistWellnessSession(
        completed: _playbackCompletionHandled,
        syncImmediately: true,
      ));
      if (_isVideoInitializedSafely()) {
        widget.mediaType == MediaType.movie
            ? insertRecentMovieData()
            : insertRecentEpisodeData();
      }
    }
  }

  @override
  void dispose() {
    _betterPlayerControllerInitialized = false;
    settings.removeListener(_syncAmbientGlowSetting);
    final suppressionId = _occasionalEffectsSuppressionId;
    if (suppressionId != null) {
      _occasionalEffectsSuppressionId = null;
      // Keep effects suppressed through the outgoing route frame. This also
      // overlaps safely with a replacement player's newly acquired scope.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _appDependencies.releaseOccasionalEffectsSuppression(suppressionId);
      });
    }
    // _resetTimer?.cancel();
    _progressCheckTimer?.cancel();
    _tvNextEpisodeTimer?.cancel();
    _hideNextEpisodeOverlay();

    // Restore original brightness before disposing
    BetterPlayerBrightnessManager.restoreOriginalBrightness();
    unawaited(WakelockPlus.disable());

    _betterPlayerController.removeEventsListener(_onAnalyticsPlayerEvent);
    _stopAnalyticsWatchClock();
    _wellnessTracker.pause();
    final bufferingStartedAt = _analyticsBufferingStartedAt;
    if (bufferingStartedAt != null) {
      _analyticsBufferingMs +=
          DateTime.now().difference(bufferingStartedAt).inMilliseconds;
    }
    settings.analytics.trackPlaybackSessionEnded(
      mediaType: _analyticsMediaType,
      contentId: _analyticsContentId,
      contentTitle: _analyticsContentTitle,
      surface: _analyticsSurface,
      sessionId: _analyticsSessionId,
      durationMs: _analyticsElapsedMs,
      watchedMs: _analyticsWatchedMs,
      bufferingMs: _analyticsBufferingMs,
      bufferCount: _analyticsBufferCount,
      providerSwitchCount: _analyticsProviderSwitchCount,
      provider: _analyticsProviderName,
    );
    unawaited(_persistWellnessSession(
      completed: _playbackCompletionHandled,
      syncImmediately: true,
    ));

    // Dispose the BetterPlayer controller to clean up resources
    _betterPlayerController.dispose();
    _introService.close();
    _introDbService.close();

    // Reset orientation to portrait when leaving the player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleVideoFinished() {
    if (widget.mediaType == MediaType.tvShow) {
      _restoreEpisodeSnapshotIfNeeded('video_finished');
    }
    if (widget.mediaType == MediaType.tvShow) {
      _logNextEpisodeState('video_finished', force: true);
    }
    debugPrint(
      '[MovieRecommendationsDebug][VIDEO_FINISHED_ENTER] '
      'mediaType=${widget.mediaType} mounted=$mounted '
      'useTvControls=${widget.useTvControls} '
      'movieId=${widget.movieMetadata?.movieId} '
      'recommendations=${widget.movieMetadata?.recommendations?.length ?? 0}',
    );
    if (widget.mediaType == MediaType.tvShow &&
        widget.tvMetadata?.seasonEpisodes != null &&
        widget.tvMetadata!.seasonEpisodes!.isNotEmpty) {
      final episodes = widget.tvMetadata!.seasonEpisodes!;
      final currentIndex = _currentEpisodeIndex();

      // Check if there's a next episode
      if (currentIndex >= 0 && currentIndex < episodes.length - 1) {
        final nextEpisode = episodes[currentIndex + 1];

        if (widget.useTvControls) {
          // Having chosen to watch the credits, the end still moves on, as
          // Netflix does; the count leaves time to stop it.
          _showTvNextEpisodePrompt(startCountdown: true);
        } else {
          // Show countdown dialog for next episode
          debugPrint(
            '[NextEpisodeDebug][countdown_requested] '
            'next=S${nextEpisode.seasonNumber}E${nextEpisode.episodeNumber} '
            'contextMounted=${_playerModalContext.mounted} '
            'scheduler=${WidgetsBinding.instance.schedulerPhase}',
          );
          _nextEpisodeWidget.showNextEpisodeCountdown(
            context: _playerModalContext,
            nextEpisode: nextEpisode,
            colors: widget.colors,
            tvMetadata: widget.tvMetadata!,
            onSaveProgress: _handleContentSwitch,
            closePlayer: _closePlayer,
          );
        }
      } else {
        // No next episode, show episode list
        if (widget.useTvControls) {
          _showTvEpisodeMenu();
        } else {
          unawaited(_openEpisodeList());
        }
      }
    } else if (widget.mediaType == MediaType.movie) {
      debugPrint(
        '[MovieRecommendationsDebug][MOVIE_FINISHED] '
        'movieId=${widget.movieMetadata?.movieId} '
        'recommendations=${widget.movieMetadata?.recommendations?.length ?? 0} '
        'ids=${widget.movieMetadata?.recommendations?.map((movie) => movie.movieId).join(',') ?? 'none'}',
      );
      if (widget.movieMetadata?.recommendations != null &&
          widget.movieMetadata!.recommendations!.isNotEmpty) {
        if (widget.useTvControls) {
          debugPrint(
            '[MovieRecommendationsDebug][PRESENT] target=tv_menu',
          );
          _showTvMovieRecommendationsMenu();
        } else {
          // Show recommended movie countdown
          final modalContext = _playerModalContext;
          final navigator = Navigator.of(modalContext, rootNavigator: true);
          debugPrint(
            '[MovieRecommendationsDebug][PRESENT] '
            'target=countdown contextMounted=${modalContext.mounted} '
            'fullscreen=${_betterPlayerController.isFullScreen} '
            'rootCanPop=${navigator.canPop()} '
            'overlay=${identityHashCode(navigator.overlay)}',
          );
          _movieRecommendations.showRecommendedMovieCountdown(
            context: modalContext,
            colors: widget.colors,
            movieMetadata: widget.movieMetadata!,
            onSaveProgress: _handleContentSwitch,
            closePlayer: _closePlayer,
          );
        }
      } else {
        debugPrint(
          '[MovieRecommendationsDebug][PRESENT_SKIPPED] '
          'reason=no_recommendations movieId=${widget.movieMetadata?.movieId}',
        );
      }
    }
  }

  void _handlePlaybackCompleted({required String source}) {
    final value = _betterPlayerController.videoPlayerController?.value;
    debugPrint(
      '[MovieRecommendationsDebug][COMPLETION_ENTER] '
      'source=$source mounted=$mounted preRoll=$_preRollActive '
      'handled=$_playbackCompletionHandled '
      'position=${value?.position.inMilliseconds} '
      'duration=${value?.duration?.inMilliseconds} '
      'playing=${value?.isPlaying} buffering=${value?.isBuffering}',
    );
    if (!mounted) {
      debugPrint(
        '[MovieRecommendationsDebug][COMPLETION_BLOCKED] reason=unmounted',
      );
      return;
    }
    if (_preRollActive) {
      debugPrint(
        '[MovieRecommendationsDebug][COMPLETION_BLOCKED] reason=pre_roll',
      );
      return;
    }
    if (_playbackCompletionHandled) {
      debugPrint(
        '[MovieRecommendationsDebug][COMPLETION_BLOCKED] '
        'reason=already_handled',
      );
      return;
    }
    debugPrint('[Player] Playback completed via $source');
    _playbackCompletionHandled = true;
    _stopAnalyticsWatchClock();
    _wellnessTracker.pause();
    _trackPlaybackEvent('finished', value: source);
    unawaited(_persistWellnessSession(
      completed: true,
      syncImmediately: true,
    ));

    // Remove the near-end teaser before presenting the definitive completion
    // action. Native and fallback completion can arrive close together.
    _showNextEpisodeButton = false;
    _hideNextEpisodeOverlay();
    setState(() {
      _activeIntroDbSegment = null;
      _introDbCreditsActive = false;
    });
    _betterPlayerController.setControlsVisibility(false);
    _handleVideoFinished();
  }

  void _openTvMenu(String title, List<BetterPlayerTvMenuItem> items) {
    if (!mounted || !widget.useTvControls || items.isEmpty) return;
    _tvNextEpisodeTimer?.cancel();
    setState(() {
      _tvNextEpisode = null;
      _tvNextEpisodeCountdown = null;
      _tvMenu = _TvPlayerMenuData(title, items);
    });
    _tvControlsController.hide(preserveFocus: true);
  }

  void _closeTvMenu({bool showControls = true}) {
    if (!mounted || _tvMenu == null) return;
    setState(() => _tvMenu = null);
    if (showControls) {
      _tvControlsController.show(restorePreviousFocus: true);
    }
  }

  bool _handleTvOverlayBack() {
    if (_tvMenu != null) {
      _closeTvMenu();
      return true;
    }
    if (_tvNextEpisode != null) {
      _dismissTvNextEpisodePrompt();
      return true;
    }
    return false;
  }

  void _showTvEpisodeMenu() {
    final metadata = widget.tvMetadata;
    final episodes = metadata?.seasonEpisodes;
    if (metadata == null || episodes == null || episodes.isEmpty) return;
    final season = episodes.first.seasonNumber;
    final items = <BetterPlayerTvMenuItem>[
      if ((metadata.allSeasons?.length ?? 0) > 1)
        BetterPlayerTvMenuItem(
          label: tr('select_season'),
          subtitle: tr('season_episodes', namedArgs: {'season': '$season'}),
          icon: PhosphorIcons.stack(),
          showsNext: true,
          onSelected: _showTvSeasonMenu,
        ),
      ...episodes.map(
        (episode) => BetterPlayerTvMenuItem(
          label: '${episode.episodeNumber}. ${episode.episodeName}',
          subtitle: [
            if (episode.runtime != null) '${episode.runtime}m',
            if (episode.voteAverage != null && episode.voteAverage! > 0)
              '★ ${episode.voteAverage!.toStringAsFixed(1)}',
          ].join('  •  '),
          icon: episode.episodeNumber == metadata.episodeNumber &&
                  episode.seasonNumber == metadata.seasonNumber
              ? PhosphorIcons.playCircle(PhosphorIconsStyle.fill)
              : PhosphorIcons.playCircle(),
          selected: episode.episodeNumber == metadata.episodeNumber &&
              episode.seasonNumber == metadata.seasonNumber,
          onSelected: () => _playTvEpisode(episode),
        ),
      ),
    ];
    _openTvMenu(
      tr('season_episodes', namedArgs: {'season': '$season'}),
      items,
    );
  }

  void _showTvSeasonMenu() {
    final metadata = widget.tvMetadata;
    final seasons = metadata?.allSeasons;
    if (metadata == null || seasons == null || seasons.isEmpty) return;
    final browsedSeason = metadata.seasonEpisodes?.isNotEmpty == true
        ? metadata.seasonEpisodes!.first.seasonNumber
        : metadata.seasonNumber;
    _openTvMenu(
      tr('select_season'),
      seasons
          .map(
            (season) => BetterPlayerTvMenuItem(
              label: season.seasonName,
              subtitle: tr(
                'episodes_count',
                namedArgs: {'count': '${season.episodeCount}'},
              ),
              icon: PhosphorIcons.stack(),
              selected: season.seasonNumber == browsedSeason,
              showsNext: true,
              onSelected: () => unawaited(
                _loadTvSeasonEpisodes(season.seasonNumber),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _loadTvSeasonEpisodes(int seasonNumber) async {
    final metadata = widget.tvMetadata;
    if (metadata == null) return;
    _openTvMenu(
      tr('select_season'),
      [
        BetterPlayerTvMenuItem(
          label: 'Loading episodes…',
          icon: PhosphorIcons.spinnerGap(),
          enabled: false,
          onSelected: () {},
        ),
      ],
    );
    final loaded = await _episodeSelection.fetchEpisodesForSeason(
      context,
      seasonNumber,
      metadata,
      widget.colors,
    );
    if (!mounted || _tvMenu == null) return;
    if (loaded) {
      _showTvEpisodeMenu();
    } else {
      _showTvSeasonMenu();
    }
  }

  void _showTvMovieRecommendationsMenu() {
    final metadata = widget.movieMetadata;
    final recommendations = metadata?.recommendations;
    debugPrint(
      '[MovieRecommendationsDebug][TV_MENU_ENTER] '
      'mounted=$mounted movieId=${metadata?.movieId} '
      'recommendations=${recommendations?.length ?? 0}',
    );
    if (metadata == null ||
        recommendations == null ||
        recommendations.isEmpty) {
      debugPrint(
        '[MovieRecommendationsDebug][TV_MENU_SKIPPED] '
        'reason=missing_metadata_or_recommendations',
      );
      return;
    }
    _openTvMenu(
      tr('recommended_movies'),
      recommendations
          .map(
            (movie) => BetterPlayerTvMenuItem(
              label: movie.title,
              subtitle: [
                if (movie.releaseDate?.isNotEmpty == true)
                  movie.releaseDate!.split('-').first,
                if (movie.voteAverage != null && movie.voteAverage! > 0)
                  '★ ${movie.voteAverage!.toStringAsFixed(1)}',
              ].join('  •  '),
              icon: PhosphorIcons.filmSlate(),
              onSelected: () => _playTvMovie(movie),
            ),
          )
          .toList(growable: false),
    );
  }

  void _showTvProviderMenu() {
    final providers = widget.availableProviders;
    if (providers == null || providers.isEmpty) return;
    _openTvMenu(
      tr('select_provider'),
      providers.map(
        (provider) {
          final selected = provider.codeName == _currentProviderCode;
          final loading = _loadingProviders.contains(provider.codeName);
          final error = _providerErrors[provider.codeName];
          final content = provider.content?.trim();
          return BetterPlayerTvMenuItem(
            label: provider.displayName,
            subtitle: loading
                ? tr('loading_video_sources')
                : error ??
                    [
                      if (selected) tr('currently_playing'),
                      if (content?.isNotEmpty == true) content!,
                      if (!selected && content?.isNotEmpty != true)
                        tr('video_source'),
                    ].join('  •  '),
            icon: error != null
                ? PhosphorIcons.warningCircle()
                : selected
                    ? PhosphorIcons.playCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.hardDrives(),
            selected: selected,
            enabled: !loading && !_isSwitchingProvider,
            onSelected: selected
                ? _closeTvMenu
                : () => _switchToProvider(
                      provider.codeName,
                      refreshMenu: () {
                        if (_tvMenu != null) {
                          _showTvProviderMenu();
                        }
                      },
                      closeMenu: _closeTvMenu,
                    ),
          );
        },
      ).toList(growable: false),
    );
  }

  EpisodeMetadata? get _nextTvEpisode {
    final metadata = widget.tvMetadata;
    final episodes = metadata?.seasonEpisodes;
    if (metadata == null || episodes == null || episodes.isEmpty) return null;
    final currentIndex = episodes.indexWhere(
      (episode) =>
          episode.episodeNumber == metadata.episodeNumber &&
          episode.seasonNumber == metadata.seasonNumber,
    );
    if (currentIndex < 0 || currentIndex >= episodes.length - 1) return null;
    return episodes[currentIndex + 1];
  }

  /// Netflix's pace: a longer count at the credits, where the episode is
  /// still playing, and a short one once it has ended.
  static const _creditsCountdown = 15;
  static const _endCountdown = 10;

  void _showTvNextEpisodePrompt({
    required bool startCountdown,
    bool atCredits = false,
  }) {
    final nextEpisode = _nextTvEpisode;
    _logNextEpisodeState(
      startCountdown ? 'tv_countdown_requested' : 'tv_prompt_requested',
      force: true,
    );
    if (!mounted || nextEpisode == null) {
      debugPrint(
        '[NextEpisodeDebug][tv_prompt_skipped] mounted=$mounted '
        'nextEpisode=${nextEpisode == null ? 'null' : 'available'}',
      );
      return;
    }
    _tvNextEpisodeTimer?.cancel();
    final seconds = atCredits ? _creditsCountdown : _endCountdown;
    setState(() {
      _tvMenu = null;
      _tvNextEpisode = nextEpisode;
      _tvNextEpisodeAtCredits = atCredits;
      _tvNextEpisodeCountdownTotal = seconds;
      _tvNextEpisodeCountdown = startCountdown ? seconds : null;
    });
    _tvControlsController.hide(preserveFocus: true);
    if (!startCountdown) return;
    _tvNextEpisodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _tvNextEpisode == null) {
        timer.cancel();
        return;
      }
      final countdown = _tvNextEpisodeCountdown ?? 0;
      if (countdown <= 1) {
        timer.cancel();
        unawaited(_playTvEpisode(nextEpisode));
      } else {
        setState(() => _tvNextEpisodeCountdown = countdown - 1);
      }
    });
  }

  void _clearTvNextEpisodePrompt({bool showControls = true}) {
    _tvNextEpisodeTimer?.cancel();
    _tvNextEpisodeTimer = null;
    if (!mounted || _tvNextEpisode == null) return;
    setState(() {
      _tvNextEpisode = null;
      _tvNextEpisodeCountdown = null;
    });
    if (showControls) {
      _tvControlsController.show(restorePreviousFocus: true);
    }
  }

  void _dismissTvNextEpisodePrompt() {
    _nextEpisodeButtonDismissed = true;
    _showNextEpisodeButton = false;
    _clearTvNextEpisodePrompt();
  }

  Future<void> _playTvEpisode(EpisodeMetadata episode) async {
    _tvNextEpisodeTimer?.cancel();
    if (mounted) {
      setState(() {
        _tvMenu = null;
        _tvNextEpisode = null;
        _tvNextEpisodeCountdown = null;
      });
    }
    await _handleContentSwitch();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TVVideoLoader(
          download: false,
          useTvPlayer: widget.useTvControls,
          onTvPlayerExit: widget.onTvPlayerExit,
          metadata: _metadataForTvEpisode(episode),
        ),
      ),
    );
  }

  Future<void> _playTvMovie(MovieRecommendation movie) async {
    if (mounted) setState(() => _tvMenu = null);
    await _handleContentSwitch();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MovieVideoLoader(
          download: false,
          useTvPlayer: widget.useTvControls,
          onTvPlayerExit: widget.onTvPlayerExit,
          metadata: MovieStreamMetadata(
            movieId: movie.movieId,
            movieName: movie.title,
            posterPath: movie.posterPath,
            backdropPath: movie.backdropPath,
            releaseDate: movie.releaseDate,
            releaseYear: movie.releaseDate == null
                ? null
                : DateTime.tryParse(movie.releaseDate!)?.year,
            isAdult: false,
            elapsed: 0,
          ),
        ),
      ),
    );
  }

  TVStreamMetadata _metadataForTvEpisode(EpisodeMetadata episode) {
    final current = widget.tvMetadata!;
    return TVStreamMetadata(
      elapsed: null,
      episodeId: episode.episodeId,
      episodeName: episode.episodeName,
      episodeNumber: episode.episodeNumber,
      posterPath: current.posterPath,
      backdropPath: episode.stillPath ?? current.backdropPath,
      seasonNumber: episode.seasonNumber,
      seriesName: current.seriesName,
      tvId: current.tvId,
      airDate: episode.airDate,
      genres: current.genres,
      languages: current.languages,
      countries: current.countries,
      seasonEpisodes: current.seasonEpisodes,
      allSeasons: current.allSeasons,
    );
  }

  void _showProviderSwitcher() {
    final providers = widget.availableProviders;
    if (providers == null || providers.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .72,
            minChildSize: .45,
            maxChildSize: .96,
            snap: true,
            builder: (context, scrollController) => AppResponsiveContent(
              maxWidth: 680,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          PhosphorIcons.hardDrives(),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('select_provider'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${providers.length} ${tr('video_source')}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(PhosphorIcons.x()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: providers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final provider = providers[index];
                        final selected =
                            provider.codeName == _currentProviderCode;
                        final loading =
                            _loadingProviders.contains(provider.codeName);
                        final error = _providerErrors[provider.codeName];
                        final content = provider.content?.trim();
                        return AppSelectionTile(
                          title: provider.displayName,
                          selected: selected,
                          subtitle: loading
                              ? tr('loading_video_sources')
                              : error ??
                                  [
                                    if (selected) tr('currently_playing'),
                                    if (content?.isNotEmpty == true) content!,
                                    if (!selected &&
                                        content?.isNotEmpty != true)
                                      tr('video_source'),
                                  ].join('  •  '),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: loading
                                ? const Padding(
                                    padding: EdgeInsets.all(11),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    selected
                                        ? PhosphorIcons.playCircle(
                                            PhosphorIconsStyle.fill,
                                          )
                                        : PhosphorIcons.playCircle(),
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                          ),
                          trailing: error == null
                              ? null
                              : Icon(
                                  PhosphorIcons.warningCircle(),
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          onTap: selected || loading || _isSwitchingProvider
                              ? () {}
                              : () => _switchToProvider(
                                    provider.codeName,
                                    refreshMenu: () {
                                      if (sheetContext.mounted) {
                                        setSheetState(() {});
                                      }
                                    },
                                    closeMenu: () {
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                    },
                                  ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _switchToProvider(
    String providerCode, {
    required VoidCallback refreshMenu,
    required VoidCallback closeMenu,
  }) async {
    if (_isSwitchingProvider || providerCode == _currentProviderCode) return;
    final analyticsStopwatch = Stopwatch()..start();
    final providerName = _providerDisplayName(providerCode);

    setState(() {
      _isSwitchingProvider = true;
      _loadingProviders.add(providerCode);
      _providerErrors.remove(providerCode);
    });
    refreshMenu();

    final position =
        _betterPlayerController.videoPlayerController?.value.position ??
            Duration.zero;
    final wasPlaying =
        _betterPlayerController.videoPlayerController?.value.isPlaying == true;
    final previousDataSource = _betterPlayerController.betterPlayerDataSource;
    var replacementStarted = false;
    var switched = false;
    try {
      await _betterPlayerController.pause();
      var source = _loadedProviders[providerCode];
      if (source == null) {
        final provider = widget.availableProviders!.firstWhere(
          (candidate) => candidate.codeName == providerCode,
        );
        final resultFuture = _providerResults[providerCode] ??=
            widget.mediaType == MediaType.movie
                ? ProviderLoader.loadMovieFromProvider(
                    provider: provider,
                    movieId: widget.movieMetadata!.movieId!,
                    scraperApiUrl: _resolveScraperApiUrl(),
                  )
                : ProviderLoader.loadTVFromProvider(
                    provider: provider,
                    tvId: widget.tvMetadata!.tvId!,
                    seasonNumber: widget.tvMetadata!.seasonNumber!,
                    episodeNumber: widget.tvMetadata!.episodeNumber!,
                    scraperApiUrl: _resolveScraperApiUrl(),
                  );
        final result = await resultFuture;
        if (!result.success || result.videoLinks?.isEmpty != false) {
          // Failed futures are not cached, allowing a later explicit retry.
          _providerResults.remove(providerCode);
          throw Exception(result.errorMessage ?? tr('movie_vid_404'));
        }

        final subtitles = <BetterPlayerSubtitlesSource>[
          for (final subtitle in result.subtitleLinks ?? const [])
            BetterPlayerSubtitlesSource(
              type: BetterPlayerSubtitlesSourceType.network,
              urls: [subtitle.url ?? ''],
              name: subtitle.language ?? tr('not_available'),
              headers: subtitle.headers,
            ),
        ];
        source = ProviderVideoSource(
          providerCode: providerCode,
          providerName: provider.displayName,
          videoSources: VideoUtils.reverseVideoQualityMap(
            VideoUtils.convertVideoLinksToMap(result.videoLinks!),
          ),
          videoFormats: VideoUtils.reverseVideoQualityMap(
            VideoUtils.convertVideoFormatsToMap(result.videoLinks!),
          ),
          videoHeaders: VideoUtils.reverseVideoQualityMap(
            VideoUtils.convertVideoHeadersToMap(result.videoLinks!),
          ),
          videoSizeTokens: VideoUtils.reverseVideoQualityMap(
            VideoUtils.convertVideoSizeTokensToMap(result.videoLinks!),
          ),
          subtitles: subtitles,
          rawVideoLinks: result.videoLinks!,
        );
        _loadedProviders[providerCode] = source;
        _rawVideoLinksByProvider[providerCode] = List.of(result.videoLinks!);
      }

      if (!mounted) return;
      final nextSource = source;
      replacementStarted = true;
      _preRollActive = false;
      await _betterPlayerController.setupDataSource(
        _buildDataSource(
          sources: nextSource.videoSources,
          subtitles: nextSource.subtitles,
          videoFormats: nextSource.videoFormats,
          videoHeaders: nextSource.videoHeaders,
        ),
        initialPosition: position,
      );
      _applyPreferredAdaptiveQuality();
      if (!wasPlaying) await _betterPlayerController.pause();
      unawaited(_loadIntroDbTimings());

      if (!mounted) return;
      setState(() {
        _currentProviderCode = providerCode;
        _activeSources = Map.of(nextSource.videoSources);
        _activeSubtitles = List.of(nextSource.subtitles);
        _activeVideoFormats = Map.of(nextSource.videoFormats);
        _activeVideoHeaders = Map.of(nextSource.videoHeaders);
        _activeVideoSizeTokens = Map.of(nextSource.videoSizeTokens);
        final switchedDuration = _betterPlayerController
            .videoPlayerController?.value.duration?.inSeconds;
        if (switchedDuration != null) duration = switchedDuration;
      });
      _analyticsProviderSwitchCount++;
      settings.analytics.trackStreamServerChanged(
        mediaType: _analyticsMediaType,
        serverName: nextSource.providerName,
        contentId: _analyticsContentId,
        contentTitle: _analyticsContentTitle,
      );
      settings.analytics.trackProviderAttempt(
        mediaType: _analyticsMediaType,
        contentId: _analyticsContentId,
        contentTitle: _analyticsContentTitle,
        provider: nextSource.providerName,
        purpose: 'provider_switch',
        success: true,
        durationMs: analyticsStopwatch.elapsedMilliseconds,
        sourceCount: nextSource.videoSources.length,
        subtitleCount: nextSource.subtitles.length,
      );
      _trackPlaybackEvent(
        'provider_switch_succeeded',
        value: nextSource.providerName,
      );
      switched = true;
    } catch (error) {
      settings.analytics.trackProviderAttempt(
        mediaType: _analyticsMediaType,
        contentId: _analyticsContentId,
        contentTitle: _analyticsContentTitle,
        provider: providerName,
        purpose: 'provider_switch',
        success: false,
        durationMs: analyticsStopwatch.elapsedMilliseconds,
        sourceCount: 0,
        subtitleCount: 0,
        error: error.toString(),
      );
      _trackPlaybackEvent(
        'provider_switch_failed',
        value: providerName,
        error: error.toString(),
      );
      debugPrint(
        '[Player] Provider switch failed for $providerCode: $error',
      );
      if (!mounted) return;
      if (replacementStarted && previousDataSource != null) {
        try {
          await _betterPlayerController.setupDataSource(
            previousDataSource,
            initialPosition: position,
          );
          if (!wasPlaying) await _betterPlayerController.pause();
        } catch (restoreError) {
          debugPrint('Unable to restore provider after switch: $restoreError');
        }
      } else if (wasPlaying) {
        try {
          await _betterPlayerController.play();
        } catch (playError) {
          debugPrint(
              'Unable to resume playback after provider failure: $playError');
        }
      }
      // Provider errors are intentionally kept in debug logs only. Scraper and
      // platform exceptions can contain URLs, native class names, and complete
      // stack traces that should never be rendered in either player UI.
      setState(
        () => _providerErrors[providerCode] = tr('switch_provider_error'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingProvider = false;
          _loadingProviders.remove(providerCode);
        });
        if (switched) {
          closeMenu();
          unawaited(_startActiveProviderEnrichment());
        } else {
          if (widget.useTvControls) {
            // A failed switch must return focus to the TV controls; otherwise
            // the remote appears frozen after the error sheet closes.
            _tvControlsController.show(restorePreviousFocus: true);
          }
          refreshMenu();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _handleScreenOrientation(context);
    if (_isPortraitInlineLayout(context)) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitPlayer();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildPortraitInlineLayout(context),
          floatingActionButton: FloatingActionButton.small(
            tooltip: tr('video_source'),
            onPressed: _showExternalPlayerSheet,
            child: Icon(PhosphorIcons.arrowSquareOut()),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (widget.useTvControls && _handleTvOverlayBack()) return;
          if (widget.useTvControls && _tvControlsController.handleBack()) {
            return;
          }
          _exitPlayer();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: SizedBox(
                child: BetterPlayer(
                  controller: _betterPlayerController,
                  key: _betterPlayerKey,
                ),
              ),
            ),
            if (_tvMenu case final menu?)
              Positioned.fill(
                child: BetterPlayerTvMenu(
                  title: menu.title,
                  items: menu.items,
                  onClose: _closeTvMenu,
                  accentColor: widget.colors.first,
                ),
              ),
            if (_tvNextEpisode case final nextEpisode?)
              Positioned.fill(
                child: _TvNextEpisodeOverlay(
                  episode: nextEpisode,
                  countdown: _tvNextEpisodeCountdown,
                  countdownTotal: _tvNextEpisodeCountdownTotal,
                  cancelLabel: _tvNextEpisodeAtCredits
                      ? tr('watch_credits')
                      : tr('cancel'),
                  onCancel: _dismissTvNextEpisodePrompt,
                  onPlay: () => _playTvEpisode(nextEpisode),
                ),
              ),
          ],
        ),
        floatingActionButton: widget.useTvControls
            ? null
            : FloatingActionButton.small(
                tooltip: tr('video_source'),
                onPressed: _showExternalPlayerSheet,
                child: Icon(PhosphorIcons.arrowSquareOut()),
              ),
      ),
    );
  }

  void _handleScreenOrientation(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final changed = _lastScreenOrientation != orientation;
    _lastScreenOrientation = orientation;

    if (orientation == Orientation.portrait) {
      _landscapeFullscreenRequestPending = false;
      return;
    }
    if (!changed ||
        widget.useTvControls ||
        _betterPlayerController.isFullScreen ||
        _landscapeFullscreenRequestPending) {
      return;
    }

    _landscapeFullscreenRequestPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _landscapeFullscreenRequestPending = false;
      if (MediaQuery.of(context).orientation == Orientation.landscape &&
          !_betterPlayerController.isFullScreen) {
        _betterPlayerController.enterFullScreen();
      }
    });
  }

  bool _isPortraitInlineLayout(BuildContext context) {
    return !widget.useTvControls &&
        MediaQuery.orientationOf(context) == Orientation.portrait &&
        !_betterPlayerController.isFullScreen;
  }

  Widget _buildPortraitInlineLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final episodes = widget.tvMetadata?.seasonEpisodes ?? _contentMenuEpisodes;
    final recommendations =
        widget.movieMetadata?.recommendations ?? const <MovieRecommendation>[];
    final isTv = widget.mediaType == MediaType.tvShow;
    final title = isTv
        ? widget.tvMetadata?.seriesName ?? ''
        : widget.movieMetadata?.movieName ?? '';

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(
              controller: _betterPlayerController,
              key: _betterPlayerKey,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontFamily: 'FigtreeSB',
                    ),
                  ),
                if (isTv && episodes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildPortraitSectionHeader(
                    context,
                    icon: PhosphorIcons.playlist(),
                    title: tr(
                      'season_episodes',
                      namedArgs: {
                        'season':
                            '${widget.tvMetadata?.seasonNumber ?? episodes.first.seasonNumber}',
                      },
                    ),
                    subtitle: tr(
                      'episodes_count',
                      namedArgs: {'count': '${episodes.length}'},
                    ),
                    action: (widget.tvMetadata?.allSeasons == null ||
                            (widget.tvMetadata?.allSeasons?.length ?? 0) > 1)
                        ? IconButton(
                            tooltip: tr('select_season'),
                            onPressed: _portraitSeasonLoading
                                ? null
                                : _showPortraitSeasonPicker,
                            icon: _portraitSeasonLoading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(PhosphorIcons.stack()),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  ...episodes.map((episode) {
                    final current = episode.episodeNumber ==
                            widget.tvMetadata?.episodeNumber &&
                        episode.seasonNumber == widget.tvMetadata?.seasonNumber;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: PlayerChoiceCard(
                        title:
                            '${episode.episodeNumber}. ${episode.episodeName}',
                        subtitle: _portraitEpisodeSubtitle(episode),
                        description: episode.overview,
                        selected: current,
                        thumbnail: _PortraitMediaThumbnail(
                          path: episode.stillPath,
                          width: 124,
                          height: 76,
                          fallbackIcon: PhosphorIcons.filmStrip(),
                        ),
                        onTap: current ? null : () => _playTvEpisode(episode),
                      ),
                    );
                  }),
                ] else if (!isTv && recommendations.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildPortraitSectionHeader(
                    context,
                    icon: PhosphorIcons.sparkle(),
                    title: tr('recommended_movies'),
                    subtitle: tr('more_recommendations'),
                  ),
                  const SizedBox(height: 8),
                  ...recommendations.map((movie) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: PlayerChoiceCard(
                          title: movie.title,
                          subtitle: _portraitMovieSubtitle(movie),
                          description: movie.overview,
                          thumbnail: _PortraitMediaThumbnail(
                            path: movie.backdropPath ?? movie.posterPath,
                            width: 124,
                            height: 76,
                            fallbackIcon: PhosphorIcons.filmStrip(),
                          ),
                          onTap: () => _playTvMovie(movie),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 21, color: colors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'FigtreeSB',
                ),
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        if (action != null) action,
      ],
    );
  }

  Future<void> _showPortraitSeasonPicker() async {
    final metadata = widget.tvMetadata;
    if (!mounted || metadata == null) {
      return;
    }

    if (metadata.allSeasons?.isNotEmpty != true && metadata.tvId != null) {
      setState(() => _portraitSeasonLoading = true);
      try {
        final details = await fetchTVDetails(
          Endpoints.tvDetailsUrl(metadata.tvId!, settings.appLanguage),
          settings.enableProxy,
          _appDependencies.tmdbProxy,
        );
        final loadedSeasons = details.seasons;
        if (loadedSeasons != null && loadedSeasons.isNotEmpty) {
          metadata.allSeasons = loadedSeasons
              .map(SeasonMetadata.fromSeason)
              .where((season) => season.seasonNumber >= 0)
              .toList(growable: false);
        }
      } catch (error) {
        debugPrint(
            '[PlayerContentMenu] portrait season metadata failed: $error');
      } finally {
        if (mounted) setState(() => _portraitSeasonLoading = false);
      }
    }

    final seasons = metadata.allSeasons;
    if (!mounted || seasons == null || seasons.length < 2) return;

    final selectedSeason = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        final browsedSeason = _portraitBrowsedSeasonNumber ??
            metadata.seasonEpisodes?.firstOrNull?.seasonNumber ??
            metadata.seasonNumber;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: seasons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final season = seasons[index];
              final selected = season.seasonNumber == browsedSeason;
              return PlayerChoiceCard(
                title: season.seasonName,
                subtitle: tr(
                  'episodes_count',
                  namedArgs: {'count': '${season.episodeCount}'},
                ),
                description: season.overview,
                selected: selected,
                thumbnail: PlayerThumbnail(
                  width: 58,
                  height: 78,
                  child: season.posterPath == null
                      ? Icon(PhosphorIcons.television())
                      : CachedNetworkImage(
                          cacheManager: cacheProp(),
                          imageUrl:
                              'https://image.tmdb.org/t/p/w185${season.posterPath}',
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const AppCachedImagePlaceholder(),
                          errorWidget: (_, __, ___) =>
                              Icon(PhosphorIcons.television()),
                        ),
                ),
                trailing: Icon(
                  selected
                      ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                      : PhosphorIcons.caretRight(),
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                onTap: () => Navigator.pop(sheetContext, season.seasonNumber),
              );
            },
          ),
        );
      },
    );
    if (!mounted || selectedSeason == null) return;

    final currentBrowsedSeason = _portraitBrowsedSeasonNumber ??
        metadata.seasonEpisodes?.firstOrNull?.seasonNumber ??
        metadata.seasonNumber;
    if (selectedSeason == currentBrowsedSeason) return;

    setState(() => _portraitSeasonLoading = true);
    var loaded = false;
    try {
      loaded = await _episodeSelection.fetchEpisodesForSeason(
        context,
        selectedSeason,
        metadata,
        widget.colors,
      );
    } catch (error) {
      debugPrint('[PlayerContentMenu] portrait season switch failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _portraitSeasonLoading = false;
          if (loaded) _portraitBrowsedSeasonNumber = selectedSeason;
        });
      }
    }
  }

  String? _portraitEpisodeSubtitle(EpisodeMetadata episode) {
    final details = <String>[];
    if (episode.runtime != null) details.add('${episode.runtime}m');
    if (episode.voteAverage != null && episode.voteAverage! > 0) {
      details.add('★ ${episode.voteAverage!.toStringAsFixed(1)}');
    }
    return details.isEmpty ? null : details.join('  •  ');
  }

  String? _portraitMovieSubtitle(MovieRecommendation movie) {
    final details = <String>[];
    if (movie.releaseDate?.isNotEmpty == true) {
      details.add(movie.releaseDate!.split('-').first);
    }
    if (movie.voteAverage != null && movie.voteAverage! > 0) {
      details.add('★ ${movie.voteAverage!.toStringAsFixed(1)}');
    }
    return details.isEmpty ? null : details.join('  •  ');
  }

  void _exitPlayer() {
    final playerRoute = ModalRoute.of(context);
    final onTvPlayerExit = widget.onTvPlayerExit;
    Navigator.pop(
      context,
      _isVideoInitializedSafely()
          ? widget.mediaType == MediaType.movie
              ? insertRecentMovieData
              : insertRecentEpisodeData
          : null,
    );
    if (onTvPlayerExit == null) return;
    if (playerRoute == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onTvPlayerExit());
      return;
    }
    unawaited(playerRoute.completed.then((_) => onTvPlayerExit()));
  }

  void _showExternalPlayerSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => AppResponsiveContent(
        maxWidth: 680,
        padding: EdgeInsets.zero,
        child: ExternalPlay(
          videoSources: _activeSources,
          subtitleSources: _activeSubtitles,
        ),
      ),
    );
  }

  Future<void> _downloadFromCurrentProvider() async {
    if (_activeSources.isEmpty) return;
    await _startActiveProviderEnrichment();
    if (!mounted || _activeSources.isEmpty) return;
    final providerName = _currentProviderName();
    final sources = Map<String, String>.of(_activeSources);
    final formats = _activeVideoFormats == null
        ? <String, BetterPlayerVideoFormat?>{}
        : Map<String, BetterPlayerVideoFormat?>.of(_activeVideoFormats!);
    final headers = Map<String, Map<String, String>>.of(_activeVideoHeaders);
    final estimatedSizes = ValueNotifier<Map<String, int?>>({
      for (final entry in _activeVideoSizeTokens.entries)
        if (_streamSizeCacheByToken.containsKey(entry.value))
          entry.key: _streamSizeCacheByToken[entry.value],
    });
    var sizePickerOpen = true;
    unawaited(StreamSizeEstimator.load(
      scraperApiUrl: _resolveScraperApiUrl(),
      tokens: _activeVideoSizeTokens,
      cacheByToken: _streamSizeCacheByToken,
      onEstimate: (token, bytes) {
        if (!sizePickerOpen) return;
        final next = Map<String, int?>.of(estimatedSizes.value);
        for (final entry in _activeVideoSizeTokens.entries) {
          if (entry.value == token) next[entry.key] = bytes;
        }
        estimatedSizes.value = next;
      },
    ));
    final resolution = await DownloadSelectionSheets.showResolution(
      context,
      resolutions: sources.keys.toList(),
      providerName: providerName,
      estimatedSizesListenable: estimatedSizes,
    );
    sizePickerOpen = false;
    estimatedSizes.dispose();
    if (!mounted || resolution == null) return;

    final url = sources[resolution];
    if (url == null) return;
    final declaredFormat = formats[resolution];
    final format = declaredFormat == BetterPlayerVideoFormat.dash
        ? 'dash'
        : declaredFormat == BetterPlayerVideoFormat.hls
            ? 'hls'
            : url.toLowerCase().contains('.mpd')
                ? 'dash'
                : 'hls';
    final movie = widget.movieMetadata;
    final episode = widget.tvMetadata;
    final isMovie = widget.mediaType == MediaType.movie;
    final season = episode?.seasonNumber ?? 0;
    final episodeNumber = episode?.episodeNumber ?? 0;
    final posterPath = isMovie ? movie?.posterPath : episode?.posterPath;
    final subtitleTrack = _originalSubtitleTrack();

    try {
      await context.read<OfflineDownloadProvider>().enqueue(
            OfflineDownloadRequest(
              id: isMovie
                  ? 'movie_${movie!.movieId}'
                  : 'tv_${episode!.tvId}_s${season}_e$episodeNumber',
              url: url,
              format: format,
              title: isMovie
                  ? movie?.movieName ?? 'Movie'
                  : episode?.seriesName ?? 'TV episode',
              subtitle: isMovie
                  ? 'From $providerName'
                  : 'S${season.toString().padLeft(2, '0')} • '
                      'E${episodeNumber.toString().padLeft(2, '0')} '
                      '${episode?.episodeName ?? ''} • $providerName',
              mediaType: isMovie ? 'movie' : 'episode',
              quality: resolution,
              posterUrl: posterPath == null
                  ? null
                  : '${TMDB_BASE_IMAGE_URL}w500$posterPath',
              maxVideoHeight: _downloadResolutionHeight(resolution),
              headers: headers[resolution] ??
                  VideoUtils.inferVideoHeaders(url) ??
                  const {},
              contentId: isMovie ? movie?.movieId : episode?.tvId,
              seasonNumber: isMovie ? null : season,
              episodeNumber: isMovie ? null : episodeNumber,
              subtitleTrackUrl: subtitleTrack?.urls!.first,
              subtitleTrackName: subtitleTrack?.name,
              subtitleTrackHeaders: subtitleTrack?.headers ?? const {},
            ),
          );
      settings.analytics.trackDownload(
        action: 'enqueue_from_player',
        mediaType: _analyticsMediaType,
        outcome: 'success',
        provider: providerName,
        quality: resolution,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$resolution download added from $providerName'),
        ),
      );
    } catch (error) {
      settings.analytics.trackDownload(
        action: 'enqueue_from_player',
        mediaType: _analyticsMediaType,
        outcome: 'error',
        provider: providerName,
        quality: resolution,
        error: error.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start download: $error')),
      );
    }
  }

  String _providerDisplayName(String? code) {
    if (code == null || code.trim().isEmpty) return 'Current provider';
    final loadedName = _loadedProviders[code]?.providerName;
    if (loadedName?.isNotEmpty == true) return loadedName!;
    for (final provider
        in widget.availableProviders ?? const <VideoProvider>[]) {
      if (provider.codeName == code) return provider.displayName;
    }
    return code;
  }

  String _currentProviderName() => _providerDisplayName(_currentProviderCode);

  int? _downloadResolutionHeight(String resolution) {
    final match = RegExp(r'(\d{3,4})').firstMatch(resolution);
    return int.tryParse(match?.group(1) ?? '');
  }

  BetterPlayerSubtitlesSource? _originalSubtitleTrack() {
    BetterPlayerSubtitlesSource? fallback;
    for (final source in _activeSubtitles) {
      final urls = source.urls;
      if (source.type != BetterPlayerSubtitlesSourceType.network ||
          urls == null ||
          urls.isEmpty ||
          urls.first?.isNotEmpty != true) {
        continue;
      }
      if (source.selectedByDefault == true) return source;
      fallback ??= source;
    }
    return fallback;
  }

  void _showSubtitleSwitcher() {
    final subtitles = List<BetterPlayerSubtitlesSource>.of(
      _betterPlayerController.betterPlayerSubtitlesSourceList,
    );
    final offIndex = subtitles.indexWhere(
      (source) => source.type == BetterPlayerSubtitlesSourceType.none,
    );
    if (offIndex < 0) {
      subtitles.insert(
        0,
        BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.none,
        ),
      );
    } else if (offIndex > 0) {
      subtitles.insert(0, subtitles.removeAt(offIndex));
    }

    final options = buildSubtitleOptions(subtitles);

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (sheetContext) => _SubtitleSwitcherSheet(
        controller: _betterPlayerController,
        options: options,
        onClose: () => Navigator.pop(sheetContext),
      ),
    );
  }

  void _showSubtitleTimingAdjuster() {
    const initialSize = .52;
    const minSize = .42;
    const maxSize = .72;
    final dragController = DraggableScrollableController();

    void updateFromHeader(DragUpdateDetails details) {
      if (!dragController.isAttached) return;
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final nextSize = (dragController.size - details.delta.dy / viewportHeight)
          .clamp(minSize, maxSize);
      dragController.jumpTo(nextSize);
    }

    void settleFromHeader(DragEndDetails details) {
      if (!dragController.isAttached) return;
      final velocity = details.primaryVelocity ?? 0;
      final current = dragController.size;
      final target = velocity < -250
          ? maxSize
          : velocity > 250
              ? minSize
              : (current < (initialSize + minSize) / 2)
                  ? minSize
                  : (current > (initialSize + maxSize) / 2)
                      ? maxSize
                      : initialSize;
      unawaited(
        dragController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        controller: dragController,
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        expand: false,
        snap: true,
        builder: (context, scrollController) => PlayerSheetScaffold(
          icon: PhosphorIcons.timer(),
          title: tr('subtitle_timing'),
          subtitle: tr('subtitle_timing_help'),
          showDragHandle: true,
          onHeaderVerticalDragUpdate: updateFromHeader,
          onHeaderVerticalDragEnd: settleFromHeader,
          actions: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(sheetContext),
              icon: Icon(PhosphorIcons.x()),
            ),
          ],
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: _SubtitleTimingControl(
              controller: _betterPlayerController,
            ),
          ),
        ),
      ),
    ).whenComplete(dragController.dispose);
  }

  String _sanitizeError(dynamic error) {
    if (error == null) return tr('switch_provider_error');
    String msg = error.toString();
    final isDeveloperError = RegExp(
      r'(PlatformException|IndexOutOfBoundsException|MethodChannel|SourceFile:|java\.|android\.|io\.flutter|\n\s*at\s)',
      caseSensitive: false,
    ).hasMatch(msg);
    if (isDeveloperError) return tr('switch_provider_error');

    msg = msg.replaceAll(RegExp(r'https?://[^\s]+'), '').trim();
    msg = msg
        .replaceAll(
          RegExp(
              r'^(Exception|SocketException|FormatException|ScraperApiException):\s*'),
          '',
        )
        .trim();
    // Player surfaces are intentionally compact. Multi-line or very long
    // errors are diagnostics, not useful recovery guidance for the viewer.
    if (msg.isEmpty || msg.contains('\n') || msg.length > 160) {
      return tr('switch_provider_error');
    }
    return msg;
  }

  Widget _buildCustomPlayerErrorWidget(
      BuildContext context, String? errorText) {
    final cleanError = _sanitizeError(errorText);
    final hasProviders = widget.availableProviders != null &&
        widget.availableProviders!.isNotEmpty;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.warningCircle(),
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              cleanError,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'FigtreeSB',
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (hasProviders)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.colors.first,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (widget.useTvControls) {
                        _showTvProviderMenu();
                      } else {
                        _showProviderSwitcher();
                      }
                    },
                    icon: Icon(PhosphorIcons.arrowsLeftRight(), size: 18),
                    label: Text(tr('switch_provider')),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  onPressed: () {
                    final currentSource = _currentProviderCode;
                    if (currentSource != null) {
                      _switchToProvider(
                        currentSource,
                        closeMenu: () {},
                        refreshMenu: () {},
                      );
                    }
                  },
                  icon: Icon(PhosphorIcons.arrowClockwise(), size: 18),
                  label: Text(tr('retry')),
                ),
                IconButton(
                  onPressed: _exitPlayer,
                  icon: Icon(PhosphorIcons.x(), color: Colors.white70),
                  tooltip: tr('close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TvPlayerMenuData {
  const _TvPlayerMenuData(this.title, this.items);

  final String title;
  final List<BetterPlayerTvMenuItem> items;
}

/// Netflix's next-episode card: bottom right, over the picture rather than
/// dimming it, with the countdown filling the Next episode button.
class _TvNextEpisodeOverlay extends StatelessWidget {
  const _TvNextEpisodeOverlay({
    required this.episode,
    required this.onCancel,
    required this.onPlay,
    required this.cancelLabel,
    this.countdown,
    this.countdownTotal = 10,
  });

  final EpisodeMetadata episode;
  final int? countdown;
  final int countdownTotal;
  final String cancelLabel;
  final VoidCallback onCancel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final seconds = countdown;
    final elapsed = seconds == null
        ? null
        : ((countdownTotal - seconds + 1) / countdownTotal).clamp(0.0, 1.0);
    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.browserBack)) {
          onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DecoratedBox(
        // Only the corner the card sits in is shaded.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomRight,
            radius: 1.1,
            colors: [Color(0xb3000000), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(48, 30, 48, 36),
          child: Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          width: 160,
                          height: 90,
                          child: episode.stillPath == null
                              ? const ColoredBox(
                                  color: Color(0xff1b1c1c),
                                  child: Icon(
                                    PhosphorIconsRegular.filmStrip,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                )
                              : Image.network(
                                  'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                    color: Color(0xff1b1c1c),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('next_episode').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'S${episode.seasonNumber}:E${episode.episodeNumber}  '
                              '${episode.episodeName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            if (episode.overview?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 6),
                              Text(
                                episode.overview!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _TvPromptButton(
                        label: seconds == null
                            ? tr('next_episode')
                            : '${tr('next_episode')}  $seconds',
                        icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                        progress: elapsed,
                        autofocus: true,
                        onPressed: onPlay,
                      ),
                      const SizedBox(width: 10),
                      _TvPromptButton(
                        label: cancelLabel,
                        icon: PhosphorIcons.x(),
                        onPressed: onCancel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A prompt action: translucent at rest, white under focus. [progress]
/// fills it from the left, for a countdown.
class _TvPromptButton extends StatefulWidget {
  const _TvPromptButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.progress,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double? progress;
  final bool autofocus;

  @override
  State<_TvPromptButton> createState() => _TvPromptButtonState();
}

class _TvPromptButtonState extends State<_TvPromptButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final foreground = _focused ? Colors.black : Colors.white;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: _focused
                    ? const Color(0xf2ffffff)
                    : const Color(0x40ffffff),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: foreground, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.progress case final progress?)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: progress),
                      duration: const Duration(seconds: 1),
                      builder: (_, value, __) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: ColoredBox(
                          color: _focused
                              ? const Color(0x26000000)
                              : const Color(0x33ffffff),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// IntroDB's skip action on TV: a white-edged pill over the picture that
/// fills white under focus.
class _TvSkipButton extends StatelessWidget {
  const _TvSkipButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(PhosphorIcons.skipForward(PhosphorIconsStyle.fill), size: 18),
      label: Text(label),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Colors.white, width: 1.5),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const Color(0xf2ffffff)
              : const Color(0x99000000),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? Colors.black
              : Colors.white,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

class _SubtitleSwitcherSheet extends StatefulWidget {
  const _SubtitleSwitcherSheet({
    required this.controller,
    required this.options,
    required this.onClose,
  });

  final BetterPlayerController controller;
  final List<SubtitleOption> options;
  final VoidCallback onClose;

  @override
  State<_SubtitleSwitcherSheet> createState() => _SubtitleSwitcherSheetState();
}

class _SubtitleSwitcherSheetState extends State<_SubtitleSwitcherSheet> {
  SubtitleOption? _loadingOption;

  /// Applies [option], letting the controller fall through to its
  /// same-language tracks when it yields nothing: a track can answer with an
  /// error status, or with something the parser cannot read, and either way the
  /// user would be left staring at a video with no captions. A first failure is
  /// not worth a message of its own: the row is marked and, when nothing plays
  /// at all, subtitles go off with the sheet still open. A tap on a row already
  /// known to be dead is the one case worth saying out loud, because there is
  /// nothing left for it to try.
  Future<void> _selectSubtitle(SubtitleOption option) async {
    if (_loadingOption != null) return;
    final controller = widget.controller;
    if (option.sources.every(controller.subtitlesSourceHasFailed)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(tr('subtitle_unavailable_pick_another'))),
      );
      return;
    }

    setState(() => _loadingOption = option);
    BetterPlayerSubtitlesSource? applied;
    try {
      applied = await controller.selectSubtitlesSource(
        option.source,
        fallbacks: option.fallbacks,
      );
    } catch (_) {
      // The walk reports a dead track by leaving it unapplied, so an escaping
      // error needs nothing here beyond not stranding the row on its spinner.
      applied = null;
    }
    if (!mounted) return;
    setState(() => _loadingOption = null);

    final played = applied != null &&
        !controller.subtitlesSourceHasFailed(applied) &&
        applied.type != BetterPlayerSubtitlesSourceType.none;
    if (played || option.isOff) {
      widget.onClose();
      return;
    }
    // Nothing for this language plays. The controller has turned subtitles off
    // rather than leave an empty caption track on screen, and the sheet stays
    // open on the marked row so the user can pick something that works.
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.betterPlayerSubtitlesSource;
    return DraggableScrollableSheet(
      initialChildSize: .78,
      minChildSize: .55,
      maxChildSize: .95,
      expand: false,
      snap: true,
      builder: (context, scrollController) => PlayerSheetScaffold(
        icon: PhosphorIcons.closedCaptioning(),
        title: tr('subtitle'),
        subtitle: tr('choose_subtitle_language'),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: widget.onClose,
            icon: Icon(PhosphorIcons.x()),
          ),
        ],
        child: ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: widget.options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final option = widget.options[index];
            final isOff = option.isOff;
            final isSelected = isOff
                ? selected == null ||
                    selected.type == BetterPlayerSubtitlesSourceType.none
                : identical(option.source, selected);
            final isLoading = identical(option, _loadingOption);
            // Only a row with nothing left to try is marked: one whose own
            // track died but whose fallbacks are untouched can still play.
            final hasFailed = option.sources.every(
              widget.controller.subtitlesSourceHasFailed,
            );
            final label = isOff
                ? widget.controller.translations.generalNone
                : option.name ?? widget.controller.translations.generalDefault;
            return PlayerChoiceCard(
              title: option.number == null ? label : '$label #${option.number}',
              subtitle: isOff
                  ? null
                  : option.provider.isEmpty
                      ? tr('subtitle')
                      : option.provider,
              selected: isSelected,
              thumbnail: PlayerThumbnail(
                width: 48,
                height: 48,
                child: Icon(
                  isOff
                      ? PhosphorIcons.subtitlesSlash()
                      : PhosphorIcons.closedCaptioning(),
                ),
              ),
              trailing: isLoading
                  ? Semantics(
                      liveRegion: true,
                      label: tr('loading_subtitles'),
                      child: const SizedBox.square(
                        key: Key('subtitle_selection_progress'),
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : hasFailed
                      ? Semantics(
                          liveRegion: true,
                          label: tr('subtitle_unavailable_pick_another'),
                          child: Icon(
                            PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                            key: const Key('subtitle_selection_failed'),
                            size: 24,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : null,
              onTap:
                  _loadingOption == null ? () => _selectSubtitle(option) : null,
            );
          },
        ),
      ),
    );
  }
}

class _SubtitleTimingControl extends StatefulWidget {
  const _SubtitleTimingControl({required this.controller});

  final BetterPlayerController controller;

  @override
  State<_SubtitleTimingControl> createState() => _SubtitleTimingControlState();
}

class _SubtitleTimingControlState extends State<_SubtitleTimingControl> {
  static const _step = Duration(milliseconds: 500);
  static const _minimum = Duration(seconds: -10);
  static const _limit = Duration(seconds: 10);

  late Duration _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.controller.subtitleOffset;
  }

  @override
  void didUpdateWidget(_SubtitleTimingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _offset = widget.controller.subtitleOffset;
    }
  }

  void _setOffset(Duration offset) {
    final milliseconds = offset.inMilliseconds.clamp(
      -_limit.inMilliseconds,
      _limit.inMilliseconds,
    );
    widget.controller.setSubtitleOffset(Duration(milliseconds: milliseconds));
    setState(() => _offset = widget.controller.subtitleOffset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final offset = _offset;
    final isSynced = offset == Duration.zero;
    final status = isSynced
        ? tr('subtitle_timing_synced')
        : tr(offset.isNegative ? 'subtitle_earlier' : 'subtitle_later');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isSynced
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.timer(),
                color: colors.primary,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  status,
                  key: const Key('subtitle_timing_value'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'FigtreeSB',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Container(
                  key: ValueKey(offset.inMilliseconds),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _subtitleOffsetValue(offset),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontFamily: 'FigtreeSB',
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.primary.withValues(alpha: .16),
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: .12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              key: const Key('subtitle_timing_slider'),
              value: offset.inMilliseconds
                  .clamp(-_limit.inMilliseconds, _limit.inMilliseconds)
                  .toDouble(),
              min: -_limit.inMilliseconds.toDouble(),
              max: _limit.inMilliseconds.toDouble(),
              divisions: 80,
              semanticFormatterCallback: (_) => _subtitleOffsetLabel(offset),
              onChanged: (value) => _setOffset(
                Duration(milliseconds: value.round()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('−10s', style: theme.textTheme.labelSmall),
                Text('0s', style: theme.textTheme.labelSmall),
                Text('+10s', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.primary.withValues(alpha: .28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: '${tr('subtitle_earlier')} 0.5s',
                  child: IconButton(
                    key: const Key('subtitle_timing_earlier'),
                    onPressed: offset <= _minimum
                        ? null
                        : () => _setOffset(offset - _step),
                    icon: Icon(PhosphorIcons.minus(), size: 18),
                    constraints: const BoxConstraints.tightFor(
                      width: 42,
                      height: 38,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    color: colors.primary,
                    disabledColor: colors.onSurface.withValues(alpha: .28),
                  ),
                ),
                SizedBox(
                  height: 22,
                  child: VerticalDivider(
                    width: 1,
                    color: colors.outlineVariant,
                  ),
                ),
                TextButton(
                  key: const Key('subtitle_timing_reset'),
                  onPressed: isSynced ? null : () => _setOffset(Duration.zero),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    disabledForegroundColor:
                        colors.onSurface.withValues(alpha: .32),
                    minimumSize: const Size(86, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(tr('subtitle_timing_reset')),
                ),
                SizedBox(
                  height: 22,
                  child: VerticalDivider(
                    width: 1,
                    color: colors.outlineVariant,
                  ),
                ),
                Tooltip(
                  message: '${tr('subtitle_later')} 0.5s',
                  child: IconButton(
                    key: const Key('subtitle_timing_later'),
                    onPressed: offset >= _limit
                        ? null
                        : () => _setOffset(offset + _step),
                    icon: Icon(PhosphorIcons.plus(), size: 18),
                    constraints: const BoxConstraints.tightFor(
                      width: 42,
                      height: 38,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    color: colors.primary,
                    disabledColor: colors.onSurface.withValues(alpha: .28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _subtitleOffsetValue(Duration offset) {
  if (offset == Duration.zero) return '0.0s';
  final seconds = offset.inMilliseconds / 1000;
  final sign = seconds > 0 ? '+' : '−';
  return '$sign${seconds.abs().toStringAsFixed(1)}s';
}

String _subtitleOffsetLabel(Duration offset) {
  if (offset == Duration.zero) return tr('subtitle_timing_synced');
  final seconds = (offset.inMilliseconds.abs() / 1000).toStringAsFixed(2);
  final compactSeconds = seconds.replaceFirst(RegExp(r'\.?0+$'), '');
  return tr(
    offset.isNegative ? 'subtitle_offset_earlier' : 'subtitle_offset_later',
    namedArgs: {'offset': compactSeconds},
  );
}

class _PortraitMediaThumbnail extends StatelessWidget {
  const _PortraitMediaThumbnail({
    required this.path,
    required this.width,
    required this.height,
    required this.fallbackIcon,
  });

  final String? path;
  final double width;
  final double height;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return PlayerThumbnail(
      width: width,
      height: height,
      child: path == null
          ? Icon(fallbackIcon)
          : CachedNetworkImage(
              cacheManager: cacheProp(),
              imageUrl: 'https://image.tmdb.org/t/p/w300$path',
              fit: BoxFit.cover,
              placeholder: (_, __) => const AppCachedImagePlaceholder(),
              errorWidget: (_, __, ___) => Icon(fallbackIcon),
            ),
    );
  }
}
