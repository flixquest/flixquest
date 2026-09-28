import 'dart:async';
import 'dart:convert';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../functions/language_names.dart';
import '../../functions/live_playback_policy.dart';
import '../../models/live_tv.dart';
import '../../models/wellness.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../provider/wellness_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/daddylive_service.dart';
import '../../services/stream_intro_service.dart';
import 'player/player_sheet_ui.dart';
import 'player/player_strings.dart';

class LivePlayer extends StatefulWidget {
  const LivePlayer({
    required this.videoUrl,
    required this.colors,
    required this.autoFullScreen,
    required this.channelName,
    required this.analytics,
    required this.analyticsSurface,
    required this.scraperApiUrl,
    this.headers = const <String, String>{},
    this.mediaType = 'hls',
    this.clearKey,
    this.variants = const <LiveStreamVariant>[],
    this.streamIcon,
    this.channels = const <Channel>[],
    this.initialChannelId,
    this.service,
    this.onChannelSwitch,
    // MediaRouteButton is a native platform view and can crash on Android
    // devices whose Flutter window resolves its background as transparent.
    // Keep this opt-in until the native button is made safe for that context.
    this.enableCast = false,
    this.useTvControls = false,
    super.key,
  });

  final String videoUrl;
  final List<Color> colors;
  final bool autoFullScreen;
  final String channelName;
  final AnalyticsService analytics;
  final String analyticsSurface;
  final String scraperApiUrl;
  final Map<String, String> headers;
  final String mediaType;
  final String? clearKey;
  final List<LiveStreamVariant> variants;
  final String? streamIcon;

  /// Channels available for in-player switching. When empty, the channel
  /// switcher is hidden.
  final List<Channel> channels;
  final String? initialChannelId;
  final LiveTvService? service;
  final void Function(Channel channel)? onChannelSwitch;
  final bool enableCast;
  final bool useTvControls;

  @override
  State<LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<LivePlayer> {
  static const Duration _recoveryWindow = Duration(minutes: 5);
  static const Duration _sourceSetupTimeout = Duration(seconds: 15);
  // Resolution includes the scraper request, device embed fetch, and playlist
  // validation. Live DLHD requests can take longer than 30 seconds.
  static const Duration _sourceResolveTimeout = Duration(minutes: 2);
  static const List<Duration> _automaticRecoveryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 30),
  ];

  late BetterPlayerController _betterPlayerController;
  final BetterPlayerTvControlsController _tvControlsController =
      BetterPlayerTvControlsController();
  final StreamIntroService _introService = StreamIntroService();
  late BetterPlayerControlsConfiguration betterPlayerControlsConfiguration;
  late BetterPlayerBufferingConfiguration betterPlayerBufferingConfiguration;

  final GlobalKey _betterPlayerKey = GlobalKey();

  String? _currentChannelId;
  late String _currentChannelName;
  bool _isSwitching = false;
  String? _bannerText;
  Timer? _bannerTimer;
  Timer? _recoveryDeadlineTimer;
  Timer? _recoveryAttemptTimer;
  Timer? _watchdogTimer;
  final _watchdogClock = Stopwatch()..start();
  final _watchdog = LivePlaybackWatchdog();
  late final DateTime _sessionStartedAt;
  late final String _sessionId;
  late final WellnessPlaybackTracker _wellnessTracker;
  DateTime? _playingStartedAt;
  DateTime? _bufferingStartedAt;
  int _watchedMs = 0;
  int _bufferingMs = 0;
  int _bufferCount = 0;
  int _channelSwitchCount = 0;
  bool _hasInitialized = false;
  bool _wasPlayingBeforeBuffering = false;
  bool _automaticRecoveryRunning = false;
  int _automaticRecoveryAttempt = 0;
  int _recoveryGeneration = 0;
  int _sourceOperationGeneration = 0;
  int? _pendingRecoveryOperation;
  String? _pendingSourceUrl;
  Duration? _lastRecoveryProgress;
  int _recoveryProgressSamples = 0;
  DateTime? _recoveryStartedAt;
  Object? _lastPlaybackError;
  late String _currentVideoUrl;
  late Map<String, String> _currentVideoHeaders;
  late String _currentMediaType;
  String? _currentClearKey;
  late List<LiveStreamVariant> _streamVariants;
  final LiveStreamFailoverQueue _variantFailover = LiveStreamFailoverQueue();
  final ValueNotifier<_LivePlaybackFailure?> _playbackFailure =
      ValueNotifier<_LivePlaybackFailure?>(null);
  late final AppDependencyProvider _appDependencies;
  late final SettingsProvider _settings;
  int? _occasionalEffectsSuppressionId;
  Orientation? _lastScreenOrientation;
  bool _landscapeFullscreenRequestPending = false;

  @override
  void initState() {
    super.initState();
    _appDependencies =
        Provider.of<AppDependencyProvider>(context, listen: false);
    _settings = Provider.of<SettingsProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _occasionalEffectsSuppressionId != null) return;
      _occasionalEffectsSuppressionId =
          _appDependencies.suppressOccasionalEffects();
    });
    _sessionStartedAt = DateTime.now();
    _sessionId =
        '${_sessionStartedAt.microsecondsSinceEpoch}-${identityHashCode(this)}';
    _wellnessTracker = WellnessPlaybackTracker(
      id: _sessionId,
      createdAt: _sessionStartedAt,
    );
    _currentChannelId =
        widget.initialChannelId ?? widget.channels.firstOrNull?.id;
    _currentChannelName = widget.channelName;
    _currentVideoUrl = widget.videoUrl;
    _currentVideoHeaders = Map<String, String>.of(widget.headers);
    _currentMediaType = widget.mediaType;
    _currentClearKey = widget.clearKey;
    _streamVariants = List<LiveStreamVariant>.of(widget.variants);
    _variantFailover.replace(
      _streamVariants,
      currentUrl: _currentVideoUrl,
    );

    betterPlayerBufferingConfiguration = liveBufferingConfiguration;

    betterPlayerControlsConfiguration =
        _buildControlsConfiguration(_currentChannelName);

    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      autoDetectFullscreenDeviceOrientation: !widget.useTvControls,
      autoDetectFullscreenAspectRatio: !widget.useTvControls,
      looping: false,
      autoPlay: true,
      allowedScreenSleep: false,
      fit: BoxFit.contain,
      // Sampling video frames for glow is costly on TV GPUs.
      enableAmbientGlow: !widget.useTvControls,
      autoDispose: true,
      controlsConfiguration: betterPlayerControlsConfiguration,
      errorBuilder: (_, __) => const SizedBox.expand(),
      overlayOnTop: true,
      overlay: ValueListenableBuilder<_LivePlaybackFailure?>(
        valueListenable: _playbackFailure,
        builder: (context, failure, _) {
          if (failure == null) return const SizedBox.expand();
          return _LivePlayerErrorOverlay(
            message: failure.message,
            retrying: failure.retrying,
            onRetry: _retryStream,
            onChannels: canSwitchChannels
                ? () => unawaited(_showChannelSwitcher())
                : null,
          );
        },
      ),
      showPlaceholderUntilPlay: true,
      subtitlesConfiguration: const BetterPlayerSubtitlesConfiguration(
        backgroundColor: Colors.black45,
        fontFamily: 'Figtree',
        fontColor: Colors.white,
        outlineEnabled: false,
        fontSize: 17,
      ),
    );

    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _settings.addListener(_syncAmbientGlowSetting);
    _syncAmbientGlowSetting();
    _betterPlayerController.addEventsListener(_onPlayerEvent);
    unawaited(_setupInitialStream());
    _betterPlayerController.setBetterPlayerGlobalKey(_betterPlayerKey);
    _watchdogTimer = Timer.periodic(
        const Duration(seconds: 2), (_) => _checkPlaybackProgress());
  }

  void _checkPlaybackProgress() {
    if (!mounted) return;
    final value = _betterPlayerController.videoPlayerController?.value;
    if (_isSwitching ||
        _recoveryStartedAt != null ||
        _playbackFailure.value != null ||
        value == null ||
        !value.initialized ||
        value.hasError) {
      _watchdog.reset();
      return;
    }
    var bufferedAhead = Duration.zero;
    for (final range in value.buffered) {
      if (range.start <= value.position && range.end > value.position) {
        bufferedAhead = range.end - value.position;
        break;
      }
    }
    if (_watchdog.observe(
      elapsed: _watchdogClock.elapsed,
      position: value.position,
      bufferedAhead: bufferedAhead,
      shouldPlay: value.isPlaying,
    )) {
      _beginPlaybackRecovery(tr('player_live_stalled'));
    }
  }

  Future<void> _setupInitialStream() async {
    final operation = _beginSourceOperation();
    try {
      final didSetup = await _setupStreamWithIntro(
        _buildDataSource(
          widget.videoUrl,
          widget.headers,
          mediaType: widget.mediaType,
          clearKey: widget.clearKey,
        ),
        operation,
      );
      if (!didSetup || !_isActiveSourceOperation(operation)) return;
      if (widget.autoFullScreen && !_betterPlayerController.isFullScreen) {
        _betterPlayerController.enterFullScreen();
      }
    } catch (error) {
      if (!_isActiveSourceOperation(operation)) return;
      _trackPlayerEvent('setup_error', error: error.toString());
      _beginPlaybackRecovery(error);
    }
  }

  void _syncAmbientGlowSetting() {
    _betterPlayerController.setAmbientGlowEnabled(
      !widget.useTvControls && _settings.playerAmbientGlowEnabled,
    );
  }

  Future<bool> _setupStreamWithIntro(
    BetterPlayerDataSource dataSource,
    int operation,
  ) async {
    StreamIntroConfig intro = const StreamIntroConfig.disabled();
    try {
      intro = await _introService.fetch(widget.scraperApiUrl);
    } catch (error) {
      debugPrint('[LivePlayer] Branded intro unavailable: $error');
    }
    if (!_isActiveSourceOperation(operation)) return false;
    return _setupDataSourceForOperation(
      operation,
      dataSource,
      preRollDataSource: intro.enabled && intro.url != null
          ? _buildIntroDataSource(intro.url!)
          : null,
    );
  }

  BetterPlayerDataSource _buildIntroDataSource(Uri url) =>
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url.toString(),
        cacheConfiguration: const BetterPlayerCacheConfiguration(
          useCache: true,
          maxCacheSize: 50 * 1024 * 1024,
          maxCacheFileSize: 20 * 1024 * 1024,
        ),
      );

  BetterPlayerControlsConfiguration _buildControlsConfiguration(
    String channelName,
  ) {
    final seekDuration = Provider.of<SettingsProvider>(context, listen: false)
        .defaultSeekDuration;

    return BetterPlayerControlsConfiguration(
      gestureConfiguration: BetterPlayerGestureConfiguration(
        enableVolumeSwipe: !widget.useTvControls,
        enableBrightnessSwipe: !widget.useTvControls,
        enableSeekSwipe: !widget.useTvControls,
      ),
      name: channelName,
      enableFullscreen: true,
      enableSubtitles: true,
      showSubtitlesButton: !widget.useTvControls,
      showQualitiesButton: !widget.useTvControls,
      enableCrop: true,
      cropIcon: PhosphorIcons.crop(),
      enablePip: !widget.useTvControls,
      enableCast: !widget.useTvControls && widget.enableCast,
      backgroundColor: Colors.black,
      controlBarColor: Colors.black.withValues(alpha: 0.48),
      progressBarBackgroundColor: Colors.white24,
      muteIcon: PhosphorIcons.speakerSimpleSlash(),
      unMuteIcon: PhosphorIcons.speakerHigh(),
      pauseIcon: PhosphorIcons.pause(PhosphorIconsStyle.fill),
      pipMenuIcon: PhosphorIcons.pictureInpicture(),
      playIcon: PhosphorIcons.play(PhosphorIconsStyle.fill),
      strings: playerControlsStrings(),
      languageLabelBuilder: languageDisplayName,
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
      // White controls; the accent belongs to the timeline, which a live
      // stream does not have.
      loadingColor: Colors.white,
      iconsColor: Colors.white,
      backwardSkipTimeInMilliseconds:
          Duration(seconds: seekDuration).inMilliseconds,
      forwardSkipTimeInMilliseconds:
          Duration(seconds: seekDuration).inMilliseconds,
      progressBarPlayedColor: widget.colors.first,
      progressBarBufferedColor: Colors.white38,
      skipForwardIcon: PhosphorIcons.arrowClockwise(),
      skipBackIcon: PhosphorIcons.arrowCounterClockwise(),
      fullscreenEnableIcon: PhosphorIcons.cornersOut(),
      fullscreenDisableIcon: PhosphorIcons.cornersIn(),
      overflowMenuIcon: PhosphorIcons.dotsThreeVertical(),
      subtitlesIcon: PhosphorIcons.closedCaptioning(),
      qualitiesIcon: PhosphorIcons.highDefinition(),
      enableAudioTracks: true,
      // On a phone these sit in the controls' action row, where live
      // television puts them; the TV remote gets them in its own menu.
      quickActions: widget.useTvControls
          ? const <BetterPlayerOverflowMenuItem>[]
          : <BetterPlayerOverflowMenuItem>[
              if (canSwitchChannels)
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.televisionSimple(),
                  tr('channels'),
                  _showChannelSwitcher,
                ),
              if (canSwitchVariants)
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.gauge(),
                  tr('player_backup_streams'),
                  _showStreamVariantSwitcher,
                ),
            ],
      overflowMenuCustomItems: widget.useTvControls
          ? <BetterPlayerOverflowMenuItem>[
              if (canSwitchVariants)
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.gauge(),
                  tr('player_backup_streams'),
                  _showStreamVariantSwitcher,
                ),
              if (canSwitchChannels)
                BetterPlayerOverflowMenuItem(
                  PhosphorIcons.televisionSimple(),
                  tr('channels'),
                  _showChannelSwitcher,
                ),
            ]
          : const <BetterPlayerOverflowMenuItem>[],
    );
  }

  bool get canSwitchChannels =>
      widget.service != null &&
      widget.channels.isNotEmpty &&
      widget.channels.length > 1;

  bool get canSwitchVariants => _streamVariants.length > 1;

  BetterPlayerDataSource _buildDataSource(
    String url,
    Map<String, String> headers, {
    String mediaType = 'hls',
    String? clearKey,
  }) {
    final resolvedHeaders = _playbackHeaders(headers);
    final isDash = mediaType.toLowerCase() == 'dash';
    final keyParts = clearKey?.split(':');
    final clearKeyJson = keyParts != null && keyParts.length == 2
        ? _clearKeyJson(keyParts[0], keyParts[1])
        : null;
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      liveStream: true,
      bufferingConfiguration: betterPlayerBufferingConfiguration,
      // A live manifest is mutable. Caching it freezes the current playlist
      // window, so playback fails after the cached segments are consumed.
      cacheConfiguration: const BetterPlayerCacheConfiguration(useCache: false),
      headers: resolvedHeaders,
      videoFormat:
          isDash ? BetterPlayerVideoFormat.dash : BetterPlayerVideoFormat.hls,
      drmConfiguration: clearKeyJson == null
          ? null
          : BetterPlayerDrmConfiguration(
              drmType: BetterPlayerDrmType.clearKey,
              clearKey: clearKeyJson,
            ),
      castConfiguration: widget.enableCast && !isDash && clearKeyJson == null
          ? BetterPlayerCastConfiguration(
              title: _currentChannelName,
              subtitle: tr('live_tv'),
              imageUrl: widget.streamIcon,
              contentType: 'application/x-mpegURL',
              isLive: true,
              requestHeaders: resolvedHeaders,
              customData: <String, Object?>{
                'mediaType': 'live',
                'channelId': _currentChannelId,
              },
            )
          : null,
    );
  }

  Future<void> _retryStream() async {
    final failure = _playbackFailure.value;
    if (failure?.retrying == true || !mounted) return;
    _cancelPlaybackRecovery();
    final operation = _beginSourceOperation();
    _playbackFailure.value = _LivePlaybackFailure(
      message: failure?.message ?? tr('player_channel_temporarily_unavailable'),
      retrying: true,
    );
    _betterPlayerController.setControlsEnabled(true);
    _trackPlayerEvent('retry');
    try {
      final service = widget.service;
      final channelId = _currentChannelId;
      final stream = service != null && channelId != null
          ? await service.getStream(channelId).timeout(_sourceResolveTimeout)
          : null;
      if (!_isActiveSourceOperation(operation)) return;
      final url = stream?.url ?? _currentVideoUrl;
      final headers = stream?.headers ?? _currentVideoHeaders;
      final mediaType = stream?.mediaType ?? _currentMediaType;
      final clearKey = stream?.clearKey ?? _currentClearKey;
      if (url.trim().isEmpty) {
        throw StateError(tr('player_no_playable_stream'));
      }
      if (_recoveryStartedAt == null) {
        _beginPlaybackRecovery(tr('player_waiting_for_live'));
      }

      // Do not replay the branded intro during recovery.
      final didSetup = await _setupDataSourceForOperation(
        operation,
        _buildDataSource(
          url,
          headers,
          mediaType: mediaType,
          clearKey: clearKey,
        ),
      );
      if (!didSetup || !_isActiveSourceOperation(operation)) return;
      _currentVideoUrl = url;
      _currentVideoHeaders = Map<String, String>.of(headers);
      _currentMediaType = mediaType;
      _currentClearKey = clearKey;
      if (stream != null) {
        _streamVariants = List<LiveStreamVariant>.of(stream.variants);
        _variantFailover.replace(
          _streamVariants,
          currentUrl: url,
        );
        _betterPlayerController.setBetterPlayerControlsConfiguration(
          _buildControlsConfiguration(_currentChannelName),
        );
      }
      if (_betterPlayerController.isPlaying() != true) {
        await _betterPlayerController.play();
      }
      _trackPlayerEvent('retry_success');
    } catch (error) {
      if (!_isActiveSourceOperation(operation)) return;
      _trackPlayerEvent('retry_error', error: error.toString());
      _beginPlaybackRecovery(error);
    }
  }

  void _beginPlaybackRecovery(Object error) {
    if (!mounted) return;
    _stopWatchClock();
    _wasPlayingBeforeBuffering = false;
    _lastPlaybackError = error;
    if (_recoveryStartedAt == null) {
      _recoveryStartedAt = DateTime.now();
      _automaticRecoveryAttempt = 0;
      final generation = ++_recoveryGeneration;
      _recoveryDeadlineTimer = Timer(
        _recoveryWindow,
        () => _showTerminalPlaybackError(generation),
      );
      _trackPlayerEvent('reconnecting', error: error.toString());
    }
    // Recover transient failures with an unobtrusive loading indicator. Reserve
    // the error prompt for when the automatic recovery window is exhausted.
    _playbackFailure.value = _LivePlaybackFailure(
      message: tr('player_waiting_for_live'),
      retrying: true,
    );
    // Native HLS loading still retries individual requests. This app-level
    // loop is the only component allowed to replace the live source, so fresh
    // tokens cannot race a second Better Player source-retry loop.
    _betterPlayerController.setControlsEnabled(true);
    _scheduleAutomaticRecovery();
  }

  void _scheduleAutomaticRecovery() {
    if (_recoveryStartedAt == null ||
        _automaticRecoveryRunning ||
        _recoveryAttemptTimer?.isActive == true) {
      return;
    }
    final delayIndex = _automaticRecoveryAttempt.clamp(
      0,
      _automaticRecoveryDelays.length - 1,
    );
    final delay = _automaticRecoveryDelays[delayIndex];
    _recoveryAttemptTimer = Timer(
      delay,
      () => unawaited(_attemptAutomaticRecovery()),
    );
  }

  Future<void> _attemptAutomaticRecovery() async {
    _recoveryAttemptTimer = null;
    if (!mounted || _recoveryStartedAt == null || _automaticRecoveryRunning) {
      return;
    }
    final value = _betterPlayerController.videoPlayerController?.value;
    if (_recoveryProgressSamples > 0 &&
        value?.isPlaying == true &&
        value?.isBuffering == false &&
        value?.hasError == false) {
      // Let native recovery prove sustained playback before replacing a source
      // that is already producing frames again.
      _scheduleAutomaticRecovery();
      return;
    }
    _automaticRecoveryRunning = true;
    final generation = _recoveryGeneration;
    final operation = _beginSourceOperation();
    final attempt = ++_automaticRecoveryAttempt;
    _trackPlayerEvent('auto_retry_$attempt');
    try {
      final backup = _variantFailover.next();
      final service = widget.service;
      final channelId = _currentChannelId;
      if (backup != null) {
        final didSetup = await _setupDataSourceForOperation(
          operation,
          _buildDataSource(
            backup.url,
            backup.headers,
            mediaType: backup.mediaType,
            clearKey: backup.clearKey,
          ),
        );
        if (!didSetup ||
            !_isActiveRecovery(generation) ||
            !_isActiveSourceOperation(operation)) {
          return;
        }
        _currentVideoUrl = backup.url;
        _currentVideoHeaders = Map<String, String>.of(backup.headers);
        _currentMediaType = backup.mediaType;
        _currentClearKey = backup.clearKey;
        _showBanner(
          tr(
            'player_trying_backup',
            namedArgs: {'name': backup.title ?? tr('player_stream')},
          ),
        );
        _trackPlayerEvent('auto_failover');
      } else if (service != null && channelId != null) {
        final stream =
            await service.getStream(channelId).timeout(_sourceResolveTimeout);
        if (!_isActiveRecovery(generation) ||
            !_isActiveSourceOperation(operation)) {
          return;
        }
        final didSetup = await _setupDataSourceForOperation(
          operation,
          _buildDataSource(
            stream.url,
            stream.headers,
            mediaType: stream.mediaType,
            clearKey: stream.clearKey,
          ),
        );
        if (!didSetup ||
            !_isActiveRecovery(generation) ||
            !_isActiveSourceOperation(operation)) {
          return;
        }
        _currentVideoUrl = stream.url;
        _currentVideoHeaders = Map<String, String>.of(stream.headers);
        _currentMediaType = stream.mediaType;
        _currentClearKey = stream.clearKey;
        _streamVariants = List<LiveStreamVariant>.of(stream.variants);
        _variantFailover.replace(
          _streamVariants,
          currentUrl: stream.url,
        );
        _betterPlayerController.setBetterPlayerControlsConfiguration(
          _buildControlsConfiguration(_currentChannelName),
        );
      } else {
        final didSetup = await _setupDataSourceForOperation(
          operation,
          _buildDataSource(
            _currentVideoUrl,
            _currentVideoHeaders,
            mediaType: _currentMediaType,
            clearKey: _currentClearKey,
          ),
        );
        if (!didSetup) return;
      }
      if (!_isActiveRecovery(generation) ||
          !_isActiveSourceOperation(operation)) {
        return;
      }
      if (_betterPlayerController.isPlaying() != true) {
        await _betterPlayerController.play();
      }
    } catch (error) {
      if (_isActiveRecovery(generation) &&
          _isActiveSourceOperation(operation)) {
        _lastPlaybackError = error;
        _trackPlayerEvent('auto_retry_error', error: error.toString());
      }
    } finally {
      _automaticRecoveryRunning = false;
      if (mounted && _recoveryStartedAt != null) {
        _scheduleAutomaticRecovery();
      }
    }
  }

  bool _isActiveRecovery(int generation) =>
      mounted &&
      _recoveryStartedAt != null &&
      generation == _recoveryGeneration;

  int _beginSourceOperation() {
    _watchdog.reset();
    return ++_sourceOperationGeneration;
  }

  bool _isActiveSourceOperation(int generation) =>
      mounted && generation == _sourceOperationGeneration;

  Future<bool> _setupDataSourceForOperation(
    int operation,
    BetterPlayerDataSource dataSource, {
    BetterPlayerDataSource? preRollDataSource,
  }) async {
    if (!_isActiveSourceOperation(operation)) return false;
    _pendingSourceUrl = dataSource.url;
    if (preRollDataSource != null) {
      await _betterPlayerController
          .setupDataSourceWithPreRoll(
            preRollDataSource: preRollDataSource,
            betterPlayerDataSource: dataSource,
          )
          .timeout(_sourceSetupTimeout);
    } else {
      await _betterPlayerController
          .setupDataSource(dataSource)
          .timeout(_sourceSetupTimeout);
    }
    if (!_isActiveSourceOperation(operation)) return false;
    if (_recoveryStartedAt != null) {
      _pendingRecoveryOperation = operation;
      _lastRecoveryProgress = null;
      _recoveryProgressSamples = 0;
    }
    return true;
  }

  Map<String, String> _playbackHeaders(Map<String, String> headers) {
    const allowedNames = <String, String>{
      'accept': 'Accept',
      'origin': 'Origin',
      'referer': 'Referer',
      'user-agent': 'User-Agent',
    };
    final result = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
    for (final entry in headers.entries) {
      final name = allowedNames[entry.key.trim().toLowerCase()];
      final value = entry.value.trim();
      if (name != null && value.isNotEmpty) result[name] = value;
    }
    return result;
  }

  void _finishPlaybackRecovery() {
    if (_recoveryStartedAt != null) {
      _trackPlayerEvent('reconnected');
    }
    _cancelPlaybackRecovery();
    _playbackFailure.value = null;
    _betterPlayerController.setControlsEnabled(true);
  }

  void _showTerminalPlaybackError(int generation) {
    if (!_isActiveRecovery(generation)) return;
    final error = _lastPlaybackError ??
        tr('player_did_not_recover');
    _sourceOperationGeneration++;
    _cancelPlaybackRecovery();
    _playbackFailure.value = _LivePlaybackFailure(
      message: friendlyLiveTvError(error),
    );
    _betterPlayerController.setControlsEnabled(false);
    _trackPlayerEvent('reconnect_exhausted', error: error.toString());
  }

  void _cancelPlaybackRecovery() {
    _recoveryGeneration++;
    _recoveryDeadlineTimer?.cancel();
    _recoveryDeadlineTimer = null;
    _recoveryAttemptTimer?.cancel();
    _recoveryAttemptTimer = null;
    _recoveryStartedAt = null;
    _automaticRecoveryAttempt = 0;
    _lastPlaybackError = null;
    _pendingRecoveryOperation = null;
    _pendingSourceUrl = null;
    _lastRecoveryProgress = null;
    _recoveryProgressSamples = 0;
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!_isRelevantPlayerEvent(event)) return;
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        if (!_hasInitialized) {
          _hasInitialized = true;
          _trackPlayerEvent(
            'initialized',
            startupMs: _sessionElapsedMs,
          );
        }
        break;
      case BetterPlayerEventType.play:
        _startWatchClock();
        _wellnessTracker.play();
        _trackPlayerEvent('play');
        break;
      case BetterPlayerEventType.pause:
        _wasPlayingBeforeBuffering = false;
        _stopWatchClock();
        _wellnessTracker.pause();
        _trackPlayerEvent('pause');
        break;
      case BetterPlayerEventType.bufferingStart:
        _wasPlayingBeforeBuffering = _playingStartedAt != null;
        _stopWatchClock();
        _wellnessTracker.pause();
        _bufferingStartedAt ??= DateTime.now();
        _bufferCount++;
        _trackPlayerEvent('buffering_started');
        break;
      case BetterPlayerEventType.bufferingEnd:
        final startedAt = _bufferingStartedAt;
        final durationMs = startedAt == null
            ? 0
            : DateTime.now().difference(startedAt).inMilliseconds;
        _bufferingMs += durationMs;
        _bufferingStartedAt = null;
        if (_wasPlayingBeforeBuffering) _startWatchClock();
        if (_wasPlayingBeforeBuffering) _wellnessTracker.play();
        _wasPlayingBeforeBuffering = false;
        _trackPlayerEvent('buffering_ended', bufferingMs: durationMs);
        break;
      case BetterPlayerEventType.progress:
        final operation = _pendingRecoveryOperation;
        final position = event.parameters?['progress'];
        final value = _betterPlayerController.videoPlayerController?.value;
        if (_recoveryStartedAt != null &&
            (operation == null || _isActiveSourceOperation(operation)) &&
            value?.isPlaying == true &&
            value?.isBuffering == false &&
            value?.hasError == false &&
            position is Duration &&
            (_lastRecoveryProgress == null ||
                position != _lastRecoveryProgress!)) {
          _lastRecoveryProgress = position;
          _recoveryProgressSamples++;
          if (_recoveryProgressSamples >= 3) _finishPlaybackRecovery();
        } else if (_recoveryStartedAt != null) {
          _recoveryProgressSamples = 0;
        }
        break;
      case BetterPlayerEventType.exception:
        final error = event.parameters?['exception']?.toString() ??
            event.parameters?.toString() ??
            'Unknown player error';
        _trackPlayerEvent('error', error: error);
        _beginPlaybackRecovery(error);
        break;
      case BetterPlayerEventType.finished:
        _beginPlaybackRecovery(tr('player_live_stopped'));
        break;
      case BetterPlayerEventType.openFullscreen:
        _trackPlayerEvent('fullscreen_opened');
        break;
      case BetterPlayerEventType.hideFullscreen:
        _trackPlayerEvent('fullscreen_closed');
        break;
      case BetterPlayerEventType.pipStart:
        _trackPlayerEvent('pip_started');
        break;
      case BetterPlayerEventType.pipStop:
        _trackPlayerEvent('pip_stopped');
        break;
      default:
        break;
    }
  }

  bool _isRelevantPlayerEvent(BetterPlayerEvent event) {
    final sourceKey = event.parameters?['sourceKey']?.toString();
    final expectedUrl = _pendingSourceUrl ?? _currentVideoUrl;
    if (sourceKey == null || expectedUrl.isEmpty) return true;
    return sourceKey == expectedUrl || sourceKey.startsWith('$expectedUrl:');
  }

  int get _sessionElapsedMs =>
      DateTime.now().difference(_sessionStartedAt).inMilliseconds;

  void _startWatchClock() => _playingStartedAt ??= DateTime.now();

  void _stopWatchClock() {
    final startedAt = _playingStartedAt;
    if (startedAt == null) return;
    _watchedMs += DateTime.now().difference(startedAt).inMilliseconds;
    _playingStartedAt = null;
  }

  void _trackPlayerEvent(
    String event, {
    int? startupMs,
    int? bufferingMs,
    String? error,
  }) {
    widget.analytics.trackLiveTVPlayerEvent(
      surface: widget.analyticsSurface,
      sessionId: _sessionId,
      channelId: _currentChannelId ?? 'unknown',
      channelName: _currentChannelName,
      event: event,
      sessionElapsedMs: _sessionElapsedMs,
      startupMs: startupMs,
      bufferingMs: bufferingMs,
      bufferCount: _bufferCount,
      error: error,
    );
  }

  Future<void> _persistWellnessSession() async {
    await WellnessProvider.instance.recordPlayback(
      sessionId: _sessionId,
      tracker: _wellnessTracker,
      mediaType: WellnessMediaType.live,
      source: WellnessPlaybackSource.live,
      contentId: _currentChannelId ?? 'unknown',
      title: _currentChannelName,
      durationMs: _sessionElapsedMs,
      progressEndMs: _sessionElapsedMs,
      completed: false,
      provider: 'Live TV',
      syncImmediately: true,
    );
  }

  Future<void> _showChannelSwitcher() async {
    widget.analytics.trackLiveTVInteraction(
      surface: widget.analyticsSurface,
      action: 'channel_switcher_opened',
      resultCount: widget.channels.length,
    );
    final selected = await showPlayerSheet<Channel>(
      context: context,
      builder: (context) => _ChannelSwitcherSheet(
        channels: widget.channels,
        currentChannelId: _currentChannelId,
      ),
    );
    if (selected == null) {
      widget.analytics.trackLiveTVInteraction(
        surface: widget.analyticsSurface,
        action: 'channel_switcher_dismissed',
      );
      return;
    }
    await _switchChannel(selected);
  }

  Future<void> _showStreamVariantSwitcher() async {
    final selected = await showPlayerSheet<LiveStreamVariant>(
      context: context,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .62,
        minChildSize: .4,
        maxChildSize: .92,
        expand: false,
        snap: true,
        builder: (context, scrollController) => PlayerSheetScaffold(
          title: tr('player_backup_streams'),
          subtitle: tr(
            'player_stream_count',
            namedArgs: {'count': '${_streamVariants.length}'},
          ),
          actions: [
            PlayerSheetAction(
              icon: PhosphorIcons.x(),
              tooltip: tr('close'),
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ],
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: _streamVariants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final variant = _streamVariants[index];
              final current = variant.url == _currentVideoUrl;
              return PlayerChoiceCard(
                title: variant.title ?? '${tr('player_stream')} ${index + 1}',
                subtitle: variant.mediaType.toUpperCase(),
                selected: current,
                kicker: current ? tr('player_now_playing') : null,
                onTap: () => Navigator.pop(sheetContext, variant),
              );
            },
          ),
        ),
      ),
    );
    if (selected == null) return;
    await _switchVariant(selected);
  }

  Future<void> _switchVariant(LiveStreamVariant variant) async {
    if (_isSwitching) return;
    final operation = _beginSourceOperation();
    setState(() => _isSwitching = true);
    try {
      final didSetup = await _setupDataSourceForOperation(
        operation,
        _buildDataSource(
          variant.url,
          variant.headers,
          mediaType: variant.mediaType,
          clearKey: variant.clearKey,
        ),
      );
      if (!didSetup || !_isActiveSourceOperation(operation)) return;
      _currentVideoUrl = variant.url;
      _currentVideoHeaders = Map<String, String>.of(variant.headers);
      _currentMediaType = variant.mediaType;
      _currentClearKey = variant.clearKey;
      _variantFailover.select(variant);
      _showBanner(variant.title ?? tr('player_stream'));
    } catch (error) {
      _trackPlayerEvent('quality_switch_error', error: error.toString());
      _beginPlaybackRecovery(error);
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  Future<void> _switchChannel(Channel channel) async {
    final service = widget.service;
    if (_isSwitching || service == null || channel.id == _currentChannelId) {
      return;
    }
    _cancelPlaybackRecovery();
    final operation = _beginSourceOperation();
    final hadPlaybackFailure = _playbackFailure.value != null;
    final failure = _playbackFailure.value;
    if (failure != null) {
      _playbackFailure.value = _LivePlaybackFailure(
        message: failure.message,
        retrying: true,
      );
    }
    setState(() {
      _isSwitching = true;
      _currentChannelId = channel.id;
      _currentChannelName = channel.name;
      betterPlayerControlsConfiguration =
          _buildControlsConfiguration(channel.name);
      _betterPlayerController.setBetterPlayerControlsConfiguration(
        betterPlayerControlsConfiguration,
      );
    });
    _showBanner(
      tr(
        'player_switching_to',
        namedArgs: {'name': channel.name},
      ),
    );
    final stopwatch = Stopwatch()..start();
    widget.analytics.trackLiveTVInteraction(
      surface: widget.analyticsSurface,
      action: 'channel_switch_requested',
      value: 'player',
    );
    try {
      final stream =
          await service.getStream(channel.id).timeout(_sourceResolveTimeout);
      if (!_isActiveSourceOperation(operation)) return;
      if (hadPlaybackFailure) {
        _beginPlaybackRecovery(tr('player_waiting_for_live'));
      }
      final didSetup = await _setupDataSourceForOperation(
        operation,
        _buildDataSource(
          stream.url,
          stream.headers,
          mediaType: stream.mediaType,
          clearKey: stream.clearKey,
        ),
      );
      if (!didSetup || !_isActiveSourceOperation(operation)) return;
      _currentVideoUrl = stream.url;
      _currentVideoHeaders = Map<String, String>.of(stream.headers);
      _currentMediaType = stream.mediaType;
      _currentClearKey = stream.clearKey;
      _streamVariants = List<LiveStreamVariant>.of(stream.variants);
      _variantFailover.replace(
        _streamVariants,
        currentUrl: stream.url,
      );
      _betterPlayerController.setBetterPlayerControlsConfiguration(
        _buildControlsConfiguration(_currentChannelName),
      );
      setState(() {
        _isSwitching = false;
      });
      _channelSwitchCount++;
      widget.analytics.trackLiveTVChannelView(
        channelName: channel.name,
        streamId: channel.id,
      );
      widget.analytics.trackLiveTVStreamResolution(
        surface: widget.analyticsSurface,
        channelId: channel.id,
        channelName: channel.name,
        outcome: 'success',
        durationMs: stopwatch.elapsedMilliseconds,
        source: 'player_switcher',
      );
      widget.onChannelSwitch?.call(channel);
      _showBanner(channel.name);
    } catch (error) {
      if (!_isActiveSourceOperation(operation)) return;
      widget.analytics.trackLiveTVStreamResolution(
        surface: widget.analyticsSurface,
        channelId: channel.id,
        channelName: channel.name,
        outcome: 'error',
        durationMs: stopwatch.elapsedMilliseconds,
        source: 'player_switcher',
        error: error.toString(),
      );
      if (!mounted) return;
      setState(() => _isSwitching = false);
      _beginPlaybackRecovery(tr('player_switch_channel_failed'));
    } finally {
      if (mounted && _currentChannelId == channel.id && _isSwitching) {
        setState(() => _isSwitching = false);
      }
    }
  }

  void _showBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _bannerText = text);
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_syncAmbientGlowSetting);
    _sourceOperationGeneration++;
    final suppressionId = _occasionalEffectsSuppressionId;
    if (suppressionId != null) {
      _occasionalEffectsSuppressionId = null;
      // Do not reveal the app-level particle canvas over the outgoing player
      // transition. Nested scopes keep replacement players suppressed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _appDependencies.releaseOccasionalEffectsSuppression(suppressionId);
      });
    }
    _bannerTimer?.cancel();
    _watchdogTimer?.cancel();
    _watchdogClock.stop();
    _cancelPlaybackRecovery();
    _betterPlayerController.removeEventsListener(_onPlayerEvent);
    _playbackFailure.dispose();
    _stopWatchClock();
    _wellnessTracker.pause();
    final bufferingStartedAt = _bufferingStartedAt;
    if (bufferingStartedAt != null) {
      _bufferingMs +=
          DateTime.now().difference(bufferingStartedAt).inMilliseconds;
    }
    widget.analytics.trackLiveTVSessionEnded(
      surface: widget.analyticsSurface,
      sessionId: _sessionId,
      channelId: _currentChannelId ?? 'unknown',
      channelName: _currentChannelName,
      durationMs: _sessionElapsedMs,
      watchedMs: _watchedMs,
      bufferingMs: _bufferingMs,
      bufferCount: _bufferCount,
      channelSwitchCount: _channelSwitchCount,
    );
    unawaited(_persistWellnessSession());
    _betterPlayerController.dispose();
    _introService.close();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _handleScreenOrientation(context);
    if (_isPortraitInlineLayout(context)) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _exitPlayer();
        },
        // The page around the video follows the app's mode; the video
        // itself stays black.
        child: PlayerTheme(
          child: Builder(
            builder: (context) => Scaffold(
              backgroundColor: BetterPlayerPanelColors.of(context).page,
              body: _buildPortraitInlineLayout(context),
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.useTvControls && _tvControlsController.handleBack()) return;
        _exitPlayer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: double.infinity,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: BetterPlayer(
                    key: _betterPlayerKey,
                    controller: _betterPlayerController,
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedSlide(
                        offset: _bannerText == null
                            ? const Offset(0, -2)
                            : Offset.zero,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _bannerText == null ? 0 : 1,
                          duration: const Duration(milliseconds: 240),
                          child: Material(
                            color: Colors.black.withValues(alpha: .78),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 9,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (_isSwitching)
                                    const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Icon(
                                      PhosphorIcons.broadcast(
                                        PhosphorIconsStyle.fill,
                                      ),
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  const SizedBox(width: 9),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              .62,
                                    ),
                                    child: Text(
                                      _bannerText ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'FigtreeSB',
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        MediaQuery.of(context).orientation == Orientation.portrait &&
        !_betterPlayerController.isFullScreen;
  }

  Widget _buildPortraitInlineLayout(BuildContext context) {
    final panel = BetterPlayerPanelColors.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BetterPlayer(
                    key: _betterPlayerKey,
                    controller: _betterPlayerController,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedSlide(
                        offset: _bannerText == null
                            ? const Offset(0, -2)
                            : Offset.zero,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _bannerText == null ? 0 : 1,
                          duration: const Duration(milliseconds: 240),
                          child: Material(
                            color: Colors.black.withValues(alpha: .78),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 9,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSwitching)
                                    const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Icon(
                                      PhosphorIcons.broadcast(
                                        PhosphorIconsStyle.fill,
                                      ),
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  const SizedBox(width: 9),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              .62,
                                    ),
                                    child: Text(
                                      _bannerText ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'FigtreeSB',
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _currentChannelName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: panel.foreground,
                          fontFamily: 'FigtreeSB',
                          fontSize: 17,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: BetterPlayerLiveBadge(label: tr('player_live')),
                    ),
                  ],
                ),
                if (widget.channels.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.televisionSimple(),
                        size: 20,
                        color: panel.secondary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          tr('channels'),
                          style: TextStyle(
                            color: panel.foreground,
                            fontFamily: 'FigtreeSB',
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        tr(
                          'player_channel_count',
                          namedArgs: {'count': '${widget.channels.length}'},
                        ),
                        style: TextStyle(
                          color: panel.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...widget.channels.map((channel) {
                    final current = channel.id == _currentChannelId;
                    final secondary = channel.nowPlaying ??
                        (channel.categories.isEmpty
                            ? null
                            : channel.categories.join(' • '));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: PlayerChoiceCard(
                        kicker: current ? tr('player_now_playing') : null,
                        title: channel.name,
                        subtitle: secondary,
                        selected: current,
                        thumbnail: _ChannelThumbnail(channel: channel),
                        onTap: current || !canSwitchChannels
                            ? null
                            : () => unawaited(_switchChannel(channel)),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _exitPlayer() {
    Navigator.of(context).pop();
  }
}

String? _clearKeyJson(String keyId, String key) {
  final hex = RegExp(r'^[0-9a-fA-F]{32}$');
  if (!hex.hasMatch(keyId) || !hex.hasMatch(key)) return null;
  List<int> bytes(String value) => <int>[
        for (var index = 0; index < value.length; index += 2)
          int.parse(value.substring(index, index + 2), radix: 16),
      ];
  String encode(String value) =>
      base64Url.encode(bytes(value)).replaceAll('=', '');
  return jsonEncode(<String, Object>{
    'type': 'temporary',
    'keys': <Map<String, String>>[
      <String, String>{'kty': 'oct', 'kid': encode(keyId), 'k': encode(key)},
    ],
  });
}

class _ChannelSwitcherSheet extends StatefulWidget {
  const _ChannelSwitcherSheet({
    required this.channels,
    required this.currentChannelId,
  });

  final List<Channel> channels;
  final String? currentChannelId;

  @override
  State<_ChannelSwitcherSheet> createState() => _ChannelSwitcherSheetState();
}

class _ChannelSwitcherSheetState extends State<_ChannelSwitcherSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = searchTokens(_query);
    final filtered = tokens.isEmpty
        ? widget.channels
        : widget.channels
            .where(
              (channel) => normalizeSearchText(
                '${channel.name} ${channel.id}',
              ).contains(tokens.join(' ')),
            )
            .toList(growable: false);
    return DraggableScrollableSheet(
      initialChildSize: .82,
      minChildSize: .5,
      maxChildSize: .95,
      expand: false,
      snap: true,
      builder: (context, scrollController) => PlayerSheetScaffold(
        title: tr('channels'),
        subtitle: tr(
          'player_channel_count',
          namedArgs: {'count': '${widget.channels.length}'},
        ),
        actions: [
          PlayerSheetAction(
            icon: PhosphorIcons.x(),
            tooltip: tr('close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: tr('player_search_channels'),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr('close'),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: Icon(PhosphorIcons.x()),
                        ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: BetterPlayerEmptyState(
                        icon: PhosphorIcons.televisionSimple(),
                        title: tr('player_no_channels'),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final channel = filtered[index];
                        final isCurrent = channel.id == widget.currentChannelId;
                        final secondary = channel.nowPlaying ??
                            (channel.categories.isEmpty
                                ? null
                                : channel.categories.join(' • '));
                        return PlayerChoiceCard(
                          kicker:
                              isCurrent ? tr('player_now_playing') : null,
                          title: channel.name,
                          subtitle: secondary,
                          selected: isCurrent,
                          thumbnail: _ChannelThumbnail(channel: channel),
                          onTap: () => Navigator.pop(context, channel),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A channel's logo, or its initial, in the player's thumbnail frame.
class _ChannelThumbnail extends StatelessWidget {
  const _ChannelThumbnail({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final logo = channel.logo?.trim();
    final name = channel.name.trim();
    final letter = channel.letter?.trim();
    final initial = letter?.isNotEmpty == true
        ? letter!
        : name.isEmpty
            ? '?'
            : name.toUpperCase().substring(0, 1);
    return PlayerThumbnail(
      width: 48,
      height: 48,
      child: logo?.isNotEmpty == true
          ? CachedNetworkImage(
              cacheManager: cacheProp(),
              imageUrl: logo!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox.expand(),
              errorWidget: (_, __, ___) => _initial(context, initial),
            )
          : _initial(context, initial),
    );
  }

  Widget _initial(BuildContext context, String letter) => Center(
        child: Text(
          letter,
          style: TextStyle(
            color: BetterPlayerPanelColors.of(context).secondary,
            fontFamily: 'FigtreeBold',
            fontSize: 19,
          ),
        ),
      );
}

class _LivePlaybackFailure {
  const _LivePlaybackFailure({required this.message, this.retrying = false});

  final String message;
  final bool retrying;
}

class _LivePlayerErrorOverlay extends StatelessWidget {
  const _LivePlayerErrorOverlay({
    required this.message,
    required this.retrying,
    required this.onRetry,
    this.onChannels,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback? onChannels;

  @override
  Widget build(BuildContext context) {
    if (retrying) {
      // Keep the last frame and let viewers use playback/channel controls while
      // recovery runs. A transient network failure is not an actionable error.
      return const IgnorePointer(
        child: Center(
          child: SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return PlayerTheme(
      onVideo: true,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .86),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 300;
              final titleSize = compact ? 18.0 : 22.0;
              final messageLines = compact ? 2 : 3;
              final gapAfterIcon = compact ? 10.0 : 18.0;
              final gapAfterTitle = compact ? 4.0 : 8.0;
              final gapBeforeActions = compact ? 10.0 : 22.0;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BetterPlayerIconSurface(
                        icon: PhosphorIcons.warningCircle(),
                        color: Colors.white,
                      ),
                      SizedBox(height: gapAfterIcon),
                      Text(
                        tr('player_channel_unavailable'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'FigtreeSB',
                          fontSize: titleSize,
                        ),
                      ),
                      SizedBox(height: gapAfterTitle),
                      Text(
                        message,
                        maxLines: messageLines,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: BetterPlayerColors.muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: gapBeforeActions),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: onRetry,
                            style: compact
                                ? FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  )
                                : null,
                            icon: Icon(PhosphorIcons.arrowClockwise(),
                                size: 18),
                            label: Text(tr('retry')),
                          ),
                          if (onChannels != null)
                            OutlinedButton.icon(
                              onPressed: onChannels,
                              style: OutlinedButton.styleFrom(
                                visualDensity: compact
                                    ? VisualDensity.compact
                                    : VisualDensity.standard,
                                padding: compact
                                    ? const EdgeInsets.symmetric(horizontal: 12)
                                    : null,
                              ),
                              icon: Icon(
                                PhosphorIcons.televisionSimple(),
                                size: 18,
                              ),
                              label: Text(tr('player_choose_channel')),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
