import 'package:flixquest/services/app_navigation.dart';
import 'package:flutter/widgets.dart';

/// What to do about a link, once there is a navigator to do it with.
typedef LinkAction = void Function(NavigatorState navigator);

/// Holds a link until the app can answer it, and answers each one once.
///
/// Links arrive on their own schedule and the app's does not match it: a tap on a home screen widget
/// or a shared address can be what starts the app, arriving before there is a single widget to open
/// anything on, and the same tap can be reported twice — as the intent the app launched from and
/// again on the stream that reports them. Both the waiting and the not-repeating are the same problem
/// for every kind of link, so they are solved here rather than once per source.
class DeepLinkDispatcher {
  const DeepLinkDispatcher._();

  /// How long a link counts as the same arrival rather than a fresh request. Only an immediate repeat
  /// is dropped: opening the same link again a minute later is someone asking for it again, and used
  /// to do nothing at all.
  static const Duration _repeatWindow = Duration(seconds: 3);

  static bool _deliveryScheduled = false;
  static String? _pendingKey;
  static LinkAction? _pendingAction;
  static String? _lastKey;
  static DateTime? _lastAt;

  /// Answers the link named by [key] with [open], now or as soon as that is possible.
  ///
  /// [key] is what makes two arrivals the same arrival — the link itself, normally. Only the most
  /// recent link is held: if two turn up before the app is ready, the later one is what was asked for.
  static void submit({required String key, required LinkAction open}) {
    if (_isRepeat(key)) return;
    final navigator = AppNavigation.navigatorKey.currentState;
    if (navigator == null) {
      _pendingKey = key;
      _pendingAction = open;
      _scheduleDelivery();
      return;
    }
    _pendingKey = null;
    _pendingAction = null;
    _lastKey = key;
    _lastAt = DateTime.now();
    open(navigator);
  }

  /// Delivers whatever was waiting. Called once the app has a navigator, and again each time it comes
  /// back to the foreground, since a link can arrive while it is not there to receive one.
  static void onAppReady() {
    final key = _pendingKey;
    final action = _pendingAction;
    if (key == null || action == null) return;
    if (AppNavigation.navigatorKey.currentState == null) {
      _scheduleDelivery();
      return;
    }
    _pendingKey = null;
    _pendingAction = null;
    submit(key: key, open: action);
  }

  static void _scheduleDelivery() {
    if (_deliveryScheduled) return;
    _deliveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deliveryScheduled = false;
      onAppReady();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static bool _isRepeat(String key) {
    final at = _lastAt;
    return _lastKey == key &&
        at != null &&
        DateTime.now().difference(at) < _repeatWindow;
  }
}
