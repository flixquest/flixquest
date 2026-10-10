import 'dart:async';

import 'package:flutter/foundation.dart';

import 'vast.dart';

typedef VastPing = void Function(
  Iterable<Uri> urls, {
  int? errorCode,
  Duration? adPlayhead,
  Uri? assetUri,
});

/// What the ad overlay shows.
@immutable
class VastAdState {
  const VastAdState({
    this.position = Duration.zero,
    required this.duration,
    this.started = false,
    this.buffering = true,
    this.ended = false,
    this.skipAfter,
  });

  final Duration position;
  final Duration duration;

  /// The first frame played and the impression was sent.
  final bool started;
  final bool buffering;
  final bool ended;

  /// Null when the ad cannot be skipped.
  final Duration? skipAfter;

  Duration get remaining {
    final left = duration - position;
    return left.isNegative ? Duration.zero : left;
  }

  bool get skippable => skipAfter != null && skipAfter! < duration;

  bool get canSkip => skippable && started && position >= skipAfter!;

  /// Whole seconds until Skip appears, never below 1 while it is pending.
  int get skipCountdown {
    if (!skippable) return 0;
    final left = skipAfter! - position;
    return left <= Duration.zero ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  double get progress => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  VastAdState copyWith({
    Duration? position,
    Duration? duration,
    bool? started,
    bool? buffering,
    bool? ended,
  }) =>
      VastAdState(
        position: position ?? this.position,
        duration: duration ?? this.duration,
        started: started ?? this.started,
        buffering: buffering ?? this.buffering,
        ended: ended ?? this.ended,
        skipAfter: skipAfter,
      );
}

/// Tracks one linear ad playing as the player's pre-roll.
///
/// The player feeds it positions and lifecycle events; it sends the VAST
/// impression and tracking events exactly once each and decides when the ad
/// has failed. It never touches the content timeline.
class VastAdSession extends ValueNotifier<VastAdState> {
  VastAdSession({
    required this.ad,
    required this.media,
    required VastPing ping,
    required this.startTimeout,
    this.stallTimeout = const Duration(seconds: 10),
    DateTime Function()? now,
  })  : _ping = ping,
        _now = now ?? DateTime.now,
        super(VastAdState(duration: ad.duration, skipAfter: ad.skipAfter));

  final VastAd ad;
  final VastMediaFile media;
  final Duration startTimeout;
  final Duration stallTimeout;
  final VastPing _ping;
  final DateTime Function() _now;

  /// Asks the player to leave the ad (failure or skip). Set by the player.
  VoidCallback? onAbandon;

  final Set<String> _sent = <String>{};
  final Set<VastProgressEvent> _progressSent = <VastProgressEvent>{};
  Timer? _startTimer;
  DateTime? _lastAdvanceAt;
  Duration _lastPosition = Duration.zero;
  bool _paused = false;
  bool _skipRequested = false;
  int? _failure;

  bool get isEnded => value.ended;

  /// Call when the ad media has been handed to the player.
  void begin() {
    _startTimer?.cancel();
    _startTimer = Timer(startTimeout, () {
      if (!value.started && !value.ended) {
        _log('media did not start within ${startTimeout.inSeconds}s');
        _fail(VastError.mediaTimeout);
      }
    });
  }

  /// Player position sample while the pre-roll is current.
  void onPosition({
    required Duration position,
    Duration? duration,
    required bool playing,
    required bool buffering,
  }) {
    if (value.ended) return;
    final total = duration != null && duration > Duration.zero
        ? duration
        : value.duration;
    final now = _now();
    if (position > _lastPosition) {
      _lastPosition = position;
      _lastAdvanceAt = now;
    }
    if (!value.started && playing && position > Duration.zero) {
      _startTimer?.cancel();
      _lastAdvanceAt = now;
      _send('impression', ad.impressions);
      _track('creativeView');
      _track('start');
      _log('started media=${media.width}x${media.height} '
          '${media.bitrate ?? '?'}kbps');
    }
    final started = value.started || (playing && position > Duration.zero);
    if (started) {
      final fraction = total.inMilliseconds <= 0
          ? 0.0
          : position.inMilliseconds / total.inMilliseconds;
      if (fraction >= 0.25) _track('firstQuartile');
      if (fraction >= 0.5) _track('midpoint');
      if (fraction >= 0.75) _track('thirdQuartile');
      for (final event in ad.progress) {
        if (!_progressSent.contains(event) &&
            position >= event.offset.resolve(total)) {
          _progressSent.add(event);
          _ping([event.url], adPlayhead: position, assetUri: media.url);
        }
      }
      // A player that wants to play but makes no progress has stalled.
      final lastAdvance = _lastAdvanceAt;
      if (playing &&
          !_paused &&
          lastAdvance != null &&
          now.difference(lastAdvance) > stallTimeout) {
        _log('stalled at ${position.inSeconds}s');
        _fail(VastError.mediaTimeout);
        return;
      }
    }
    value = value.copyWith(
      position: position,
      duration: total,
      started: started,
      buffering: buffering || !started,
    );
  }

  void onPaused() {
    if (!value.started || value.ended || _paused) return;
    _paused = true;
    _track('pause', repeat: true);
  }

  void onResumed() {
    if (!value.started || value.ended || !_paused) return;
    _paused = false;
    _lastAdvanceAt = _now();
    _track('resume', repeat: true);
  }

  /// The viewer chose Skip. Returns false while skipping is not allowed.
  bool requestSkip() {
    if (!value.canSkip || value.ended) return false;
    _skipRequested = true;
    onAbandon?.call();
    return true;
  }

  /// Sends click tracking and returns where the advertiser page is.
  Uri? click() {
    if (value.ended) return null;
    _ping(ad.clickTracking, adPlayhead: value.position, assetUri: media.url);
    return ad.clickThrough;
  }

  /// The player's sequence left the pre-roll: `completed`, `skipped` or
  /// `error` (the native player could not play the media).
  void onEnded(String reason) {
    if (value.ended) return;
    _startTimer?.cancel();
    final failure = _failure;
    if (failure != null) {
      _send('error', ad.errors, errorCode: failure);
    } else if (reason == 'error') {
      _send('error', ad.errors,
          errorCode:
              value.started ? VastError.mediaDisplay : VastError.linearGeneral);
    } else if (reason == 'skipped' || _skipRequested) {
      _track('skip');
    } else if (reason == 'completed' && value.started) {
      _track('firstQuartile');
      _track('midpoint');
      _track('thirdQuartile');
      _track('complete');
    }
    _log('ended reason=$reason started=${value.started} '
        'at ${value.position.inSeconds}s');
    value = value.copyWith(ended: true, buffering: false);
  }

  /// The player is closing while the ad is still on screen.
  void onClosed() {
    if (value.ended) return;
    if (value.started) _track('closeLinear');
    onEnded('closed');
  }

  void _fail(int code) {
    if (value.ended || _failure != null) return;
    _failure = code;
    onAbandon?.call();
  }

  void _track(String event, {bool repeat = false}) {
    final urls = ad.tracking[event];
    if (urls == null || urls.isEmpty) {
      _sent.add(event);
      return;
    }
    _send(event, urls, repeat: repeat);
  }

  void _send(String key, List<Uri> urls,
      {int? errorCode, bool repeat = false}) {
    if (!repeat && !_sent.add(key)) return;
    _ping(urls,
        errorCode: errorCode, adPlayhead: value.position, assetUri: media.url);
  }

  static void _log(String message) => debugPrint('[VAST] $message');

  @override
  void dispose() {
    _startTimer?.cancel();
    onAbandon = null;
    super.dispose();
  }
}
