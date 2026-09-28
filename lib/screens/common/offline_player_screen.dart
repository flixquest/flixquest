import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../functions/language_names.dart';
import '../../functions/player_subtitle_configuration.dart';
import '../../models/offline_download.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/tv_stream_metadata.dart';
import '../../models/wellness.dart';
import '../../constants/app_constants.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../provider/wellness_provider.dart';
import 'player/player_strings.dart';
import 'player/player_external_subtitles.dart';

/// The lightweight offline variant of FlixQuest's Better Player. It keeps the
/// same player actions as streaming playback while treating the downloaded
/// quality as a fixed, one-item quality selection.
class OfflinePlayerScreen extends StatefulWidget {
  const OfflinePlayerScreen({
    super.key,
    required this.download,
  });

  final OfflineDownload download;

  @override
  State<OfflinePlayerScreen> createState() => _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends State<OfflinePlayerScreen> {
  late final BetterPlayerController _controller;
  final GlobalKey _playerKey = GlobalKey();
  var _initialized = false;
  late final WellnessPlaybackTracker _wellnessTracker;
  late final String _wellnessSessionId;
  bool _completed = false;
  final PlayerExternalSubtitles _externalSubtitles = PlayerExternalSubtitles();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _wellnessSessionId =
        '${now.microsecondsSinceEpoch}-offline-${widget.download.id}';
    _wellnessTracker = WellnessPlaybackTracker(
      id: _wellnessSessionId,
      createdAt: now,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final accent = Theme.of(context).primaryColor;
    final settings = context.read<SettingsProvider>();
    final controls = BetterPlayerControlsConfiguration(
      gestureConfiguration: const BetterPlayerGestureConfiguration(
        enableVolumeSwipe: true,
        enableBrightnessSwipe: true,
        enableSeekSwipe: true,
        enableDoubleTapSeek: true,
        volumeSwipeSensitivity: 0.5,
        brightnessSwipeSensitivity: 0.5,
        seekSwipeSensitivity: 1.0,
      ),
      name: widget.download.title,
      subtitle: widget.download.subtitle,
      strings: playerControlsStrings(),
      languageLabelBuilder: languageDisplayName,
      emphasisFontFamily: 'FigtreeSB',
      enableFullscreen: true,
      enableSubtitles: true,
      showSubtitlesButton: true,
      enableQualities: true,
      showQualitiesButton: true,
      enableDownloadButton: true,
      onDownloadTap: _showAlreadyDownloaded,
      enableCrop: true,
      cropIcon: PhosphorIcons.crop(),
      enablePip: true,
      enableAudioTracks: true,
      backgroundColor: Colors.black,
      progressBarBackgroundColor: Colors.white24,
      progressBarHandleColor: accent,
      controlBarColor: Colors.black.withValues(alpha: .48),
      muteIcon: PhosphorIcons.speakerSimpleSlash(),
      unMuteIcon: PhosphorIcons.speakerHigh(),
      pauseIcon: PhosphorIcons.pause(PhosphorIconsStyle.fill),
      pipMenuIcon: PhosphorIcons.pictureInpicture(),
      playIcon: PhosphorIcons.play(PhosphorIconsStyle.fill),
      showControlsOnInitialize: false,
      controlsHideTime: const Duration(milliseconds: 300),
      // White controls; the accent is the timeline's played part alone.
      loadingColor: Colors.white,
      iconsColor: Colors.white,
      progressBarPlayedColor: accent,
      progressBarBufferedColor: Colors.white38,
      skipForwardIcon: PhosphorIcons.arrowClockwise(),
      skipBackIcon: PhosphorIcons.arrowCounterClockwise(),
      fullscreenEnableIcon: PhosphorIcons.cornersOut(),
      fullscreenDisableIcon: PhosphorIcons.cornersIn(),
      overflowMenuIcon: PhosphorIcons.dotsThreeVertical(),
      overflowMenuCustomItems: [
        BetterPlayerOverflowMenuItem(
          PhosphorIcons.closedCaptioning(),
          tr('external_subtitles'),
          _showExternalSubtitles,
        ),
      ],
      controlBarHeight: 56,
    );
    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoDetectFullscreenDeviceOrientation: true,
        autoDetectFullscreenAspectRatio: true,
        autoPlay: true,
        fit: BoxFit.contain,
        autoDispose: true,
        allowedScreenSleep: false,
        controlsConfiguration: controls,
        subtitlesConfiguration: buildPlayerSubtitleConfiguration(
          backgroundColor: settings.subtitleBackgroundColor,
          foregroundColor: settings.subtitleForegroundColor,
          fontSize: settings.subtitleFontSize,
          textStyle: settings.subtitleTextStyle,
        ),
        showPlaceholderUntilPlay: true,
        errorBuilder: (_, __) => const Center(
          child: Text(
            'This downloaded video could not be played.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
    _controller.setBetterPlayerGlobalKey(_playerKey);
    _controller.addEventsListener(_onPlayerEvent);
    final savedSubtitle = widget.download.offlineSubtitlePath;
    final quality = widget.download.quality.trim().isEmpty
        ? 'Auto'
        : widget.download.quality.trim();
    final offlineUrl = 'flixquest-offline://${widget.download.id}';
    _controller.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        offlineUrl,
        videoFormat: BetterPlayerVideoFormat.other,
        resolutions: <String, String>{quality: offlineUrl},
        selectedResolution: quality,
        cacheConfiguration: BetterPlayerCacheConfiguration(
          key: 'flixquest-offline:${widget.download.id}',
        ),
        subtitles: savedSubtitle?.isNotEmpty == true
            ? [
                BetterPlayerSubtitlesSource(
                  type: BetterPlayerSubtitlesSourceType.file,
                  urls: [savedSubtitle],
                  name: widget.download.offlineSubtitleName ??
                      'Downloaded subtitle',
                  selectedByDefault: true,
                ),
              ]
            : const [],
      ),
    );
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.play:
        _wellnessTracker.play();
      case BetterPlayerEventType.pause:
      case BetterPlayerEventType.bufferingStart:
        _wellnessTracker.pause();
      case BetterPlayerEventType.bufferingEnd:
        if (_controller.videoPlayerController?.value.isPlaying == true) {
          _wellnessTracker.play();
        }
      case BetterPlayerEventType.finished:
        _completed = true;
        _wellnessTracker.pause();
        unawaited(_persistWellnessSession(syncImmediately: true));
      default:
        break;
    }
  }

  Future<void> _persistWellnessSession({bool syncImmediately = false}) async {
    final value = _controller.videoPlayerController?.value;
    final isMovie = widget.download.mediaType == 'movie';
    final contentId = isMovie
        ? (widget.download.contentId?.toString() ?? widget.download.id)
        : '${widget.download.contentId ?? 'unknown'}:'
            '${widget.download.seasonNumber ?? 0}:'
            '${widget.download.episodeNumber ?? 0}';
    await WellnessProvider.instance.recordPlayback(
      sessionId: _wellnessSessionId,
      tracker: _wellnessTracker,
      mediaType: isMovie ? WellnessMediaType.movie : WellnessMediaType.episode,
      source: WellnessPlaybackSource.offline,
      contentId: contentId,
      seriesId: isMovie ? null : widget.download.contentId?.toString(),
      title: widget.download.title,
      subtitle: widget.download.subtitle,
      seasonNumber: widget.download.seasonNumber,
      episodeNumber: widget.download.episodeNumber,
      durationMs: value?.duration?.inMilliseconds ?? 0,
      progressEndMs: value?.position.inMilliseconds ?? 0,
      completed: _completed,
      posterPath: widget.download.posterUrl,
      provider: 'Downloaded',
      syncImmediately: syncImmediately,
    );
  }

  void _showAlreadyDownloaded() {
    final quality = widget.download.quality.trim().isEmpty
        ? 'Auto'
        : widget.download.quality.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Already downloaded at $quality.')),
    );
  }

  void _showExternalSubtitles() {
    final id = widget.download.contentId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Subtitle search is unavailable for this older download.')),
      );
      return;
    }
    final isMovie = widget.download.mediaType == 'movie';
    _externalSubtitles.showExternalSubtitlesMenu(
      context: context,
      colors: [
        Theme.of(context).primaryColor,
        Theme.of(context).colorScheme.surface
      ],
      scraperApiUrl: Provider.of<AppDependencyProvider>(context, listen: false)
          .flixquestAPIURL,
      mediaType: isMovie ? MediaType.movie : MediaType.tvShow,
      movieMetadata: isMovie
          ? MovieStreamMetadata(
              backdropPath: null,
              elapsed: 0,
              movieId: id,
              movieName: widget.download.title,
              posterPath: null,
              releaseYear: null,
              isAdult: false,
              releaseDate: null,
            )
          : null,
      tvMetadata: isMovie
          ? null
          : TVStreamMetadata(
              elapsed: 0,
              episodeId: 0,
              episodeName: widget.download.subtitle,
              episodeNumber: widget.download.episodeNumber ?? 0,
              posterPath: null,
              seasonNumber: widget.download.seasonNumber ?? 0,
              seriesName: widget.download.title,
              tvId: id,
              airDate: null,
            ),
      betterPlayerController: _controller,
    );
  }

  @override
  void dispose() {
    if (_initialized) {
      _controller.removeEventsListener(_onPlayerEvent);
      _wellnessTracker.pause();
      unawaited(_persistWellnessSession(syncImmediately: true));
      _controller.dispose();
    }
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: BetterPlayer(controller: _controller, key: _playerKey),
        ),
      ),
    );
  }
}
