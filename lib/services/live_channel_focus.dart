import 'package:flutter/foundation.dart';

/// A live channel a link asked to be shown in the channel list.
///
/// The request is a value rather than a call because the television app cannot answer it where the
/// link arrives: the Live TV screen may not exist yet (the app is still starting, or another
/// destination is showing), and it is the shell and that screen, not the link handler, that know how
/// to switch destination and move focus. The link leaves the request here, and whichever of them
/// gets there first does its part.
class LiveChannelFocusRequest {
  const LiveChannelFocusRequest(this.channelId);

  final String channelId;
}

/// The one pending [LiveChannelFocusRequest], if any.
class LiveChannelFocus {
  const LiveChannelFocus._();

  static final ValueNotifier<LiveChannelFocusRequest?> pending =
      ValueNotifier<LiveChannelFocusRequest?>(null);

  /// Asks for [channelId] to be focused. Asking again for the same channel is a fresh request, so
  /// each is a new object rather than an equal value.
  static void request(String channelId) {
    pending.value = LiveChannelFocusRequest(channelId);
  }

  /// Hands the pending request to whoever will act on it, so that it is acted on once.
  static LiveChannelFocusRequest? take() {
    final request = pending.value;
    pending.value = null;
    return request;
  }
}
