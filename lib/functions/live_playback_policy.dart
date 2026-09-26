import 'package:better_player_plus/better_player_plus.dart';

import '../models/live_tv.dart';

/// The manifest determines the live offset; these are only loading ceilings.
const liveBufferingConfiguration = BetterPlayerBufferingConfiguration(
  minBufferMs: 10000,
  maxBufferMs: 30000,
  bufferForPlaybackMs: 1500,
  bufferForPlaybackAfterRebufferMs: 3000,
  backBufferDurationMs: 0,
  retainBackBufferFromKeyframe: false,
  prioritizeTimeOverSizeThresholds: true,
);

/// Detect freezes even when the native player reports no error. Pass a
/// monotonic elapsed time; live timestamps may move backwards with the window.
class LivePlaybackWatchdog {
  Duration? _position;
  Duration _bufferedAhead = Duration.zero;
  Duration? _lastPlaybackAt;
  Duration? _lastActivityAt;

  void reset() {
    _position = null;
    _bufferedAhead = Duration.zero;
    _lastPlaybackAt = null;
    _lastActivityAt = null;
  }

  bool observe({
    required Duration elapsed,
    required Duration position,
    required Duration bufferedAhead,
    required bool shouldPlay,
  }) {
    if (!shouldPlay) {
      reset();
      return false;
    }
    if (_position == null || position != _position) {
      _lastPlaybackAt = elapsed;
      _lastActivityAt = elapsed;
    } else if (bufferedAhead >
        _bufferedAhead + const Duration(milliseconds: 250)) {
      _lastActivityAt = elapsed;
    }
    _position = position;
    _bufferedAhead = bufferedAhead;
    final stalled = elapsed - _lastActivityAt! >= const Duration(seconds: 25) ||
        elapsed - _lastPlaybackAt! >= const Duration(seconds: 60);
    if (stalled) reset();
    return stalled;
  }
}

/// Keeps backup live streams in their advertised order across player errors.
///
/// The currently playing URL is treated as consumed. Each [next] call advances
/// once and never loops back, so a broken provider cannot trap recovery on the
/// same source. A fresh device-side resolution replaces the queue and starts a
/// new pass through the providers.
class LiveStreamFailoverQueue {
  List<LiveStreamVariant> _variants = const <LiveStreamVariant>[];
  int _currentIndex = -1;

  void replace(
    List<LiveStreamVariant> variants, {
    required String currentUrl,
  }) {
    _variants = variants
        .where((variant) => variant.url.trim().isNotEmpty)
        .toList(growable: false);
    _currentIndex = _variants.indexWhere(
      (variant) => variant.url == currentUrl,
    );
  }

  LiveStreamVariant? next() {
    final nextIndex = _currentIndex + 1;
    if (nextIndex < 0 || nextIndex >= _variants.length) return null;
    _currentIndex = nextIndex;
    return _variants[nextIndex];
  }

  void select(LiveStreamVariant selected) {
    final index = _variants.indexWhere(
      (variant) =>
          variant.url == selected.url &&
          variant.title == selected.title &&
          variant.mediaType == selected.mediaType &&
          variant.clearKey == selected.clearKey &&
          _sameHeaders(variant.headers, selected.headers),
    );
    if (index >= 0) _currentIndex = index;
  }

  bool _sameHeaders(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) return false;
    return left.entries.every((entry) => right[entry.key] == entry.value);
  }
}
