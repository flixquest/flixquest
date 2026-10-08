import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';

import '../../../models/adsterra_playback_ads_config.dart';
import '../../../models/vast_preroll_config.dart';
import '../../../services/vast/vast.dart';
import '../../../services/vast/vast_ad_session.dart';
import '../../../services/vast/vast_client.dart';
import '../../../widgets/adsterra_playback_ad_screen.dart';
import '../../../widgets/vast_ad_overlay.dart';

/// One player's VAST video ad, from the tag request to its last tracking
/// ping. The movie and episode player and Live TV share it.
///
/// While the player opens, [load] asks the networks for an ad. The player
/// hands [dataSource] to `setupDataSourceWithPreRoll` and calls [start]; it
/// forwards play, pause and the sequence's `preRollEnded` reason, and shows
/// [overlay] in place of its controls while the ad plays.
class PlayerPrerollAd {
  PlayerPrerollAd({required this.television, VastClient? client})
      : _client = client;

  /// Android TV: renditions up to 1080p, the remote-driven overlay and no
  /// advertiser link.
  final bool television;
  VastClient? _client;
  VastAdSession? _session;
  BetterPlayerController? _controller;
  Timer? _positionTimer;

  /// The ad playing now, or null.
  VastAdSession? get session => _session;

  /// The first ad from the networks `vast_preroll_network` lists.
  Future<VastPreroll?> load(VastPrerollConfig config,
      {bool Function()? cancelled}) async {
    final sources = config.sourcesFor(television: television);
    if (sources.isEmpty) return null;
    try {
      final client = _client ??= VastClient();
      return await client.loadPreroll(
        sources,
        maxHeight: television ? 1080 : 720,
        maxBitrate: television ? 8000 : 2500,
        cancelled: cancelled,
      );
    } catch (error) {
      debugPrint('[VAST] pre-roll unavailable: $error');
      return null;
    }
  }

  static BetterPlayerDataSource dataSource(VastMediaFile media) {
    final type = media.type.toLowerCase();
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      media.url.toString(),
      videoFormat:
          type.contains('mpegurl') ? BetterPlayerVideoFormat.hls : null,
    );
  }

  /// Tracks [preroll] while [controller] plays it as its pre-roll.
  void start(VastPreroll preroll, BetterPlayerController controller) {
    final session = VastAdSession(
      ad: preroll.ad,
      media: preroll.media,
      ping: _client!.send,
      startTimeout: preroll.source.startTimeout,
    );
    // Failure or Skip: the native sequence moves to the content at its start
    // position, exactly as when the ad ends on its own.
    session.onAbandon = () => unawaited(controller.skipPreRoll());
    _controller = controller;
    _session = session;
    session.begin();
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _samplePosition(),
    );
  }

  void _samplePosition() {
    final session = _session;
    final controller = _controller;
    if (session == null || controller == null || !controller.isPreRollActive) {
      return;
    }
    final value = controller.videoPlayerController?.value;
    if (value == null || !value.initialized) {
      session.onPosition(
          position: Duration.zero, playing: false, buffering: true);
      return;
    }
    session.onPosition(
      position: value.position,
      duration: value.duration,
      playing: value.isPlaying,
      buffering: value.isBuffering,
    );
  }

  void onPlay() => _session?.onResumed();

  void onPause() => _session?.onPaused();

  /// Ends the ad's bookkeeping. [reason] is the sequence's `completed`,
  /// `skipped` or `error`, or `closed` when the player leaves the ad.
  void finish(String reason) {
    final session = _session;
    if (session == null) return;
    _session = null;
    _positionTimer?.cancel();
    _positionTimer = null;
    reason == 'closed' ? session.onClosed() : session.onEnded(reason);
    // The overlay listens until the frame that removes it.
    WidgetsBinding.instance.addPostFrameCallback((_) => session.dispose());
  }

  /// The controls while the ad plays; null when no ad is playing.
  Widget? overlay(BuildContext context, {VoidCallback? onExit}) {
    final session = _session;
    if (session == null) return null;
    return VastAdOverlay(
      session: session,
      television: television,
      onVisitAdvertiser:
          television ? null : (url) => unawaited(_openAdvertiser(context, url)),
      onExit: onExit,
    );
  }

  /// The ad pauses while its advertiser page is open and resumes after.
  Future<void> _openAdvertiser(BuildContext context, Uri url) async {
    final controller = _controller;
    if (controller == null) return;
    final wasPlaying = controller.isPlaying() ?? false;
    await controller.pause();
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/vast/click-through'),
      builder: (_) => AdsterraPlaybackAdScreen(
        placement: PlaybackAdPlacement(
          smartlinkUrl: url,
          loadTimeout: const Duration(seconds: 10),
          maxDuration: const Duration(minutes: 2),
        ),
        stage: PlaybackAdStage.streamFound,
        holdClose: false,
      ),
    ));
    if (context.mounted && wasPlaying && _session?.isEnded == false) {
      await controller.play();
    }
  }

  /// The player is closing: a running ad sends `closeLinear`, and the last
  /// tracking pings get time to leave before the client closes.
  void dispose() {
    final session = _session;
    _session = null;
    _positionTimer?.cancel();
    if (session != null) {
      session.onClosed();
      session.dispose();
    }
    final client = _client;
    if (client != null) {
      unawaited(
          Future<void>.delayed(const Duration(seconds: 15), client.close));
    }
  }
}
