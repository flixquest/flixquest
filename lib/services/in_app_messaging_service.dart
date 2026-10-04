import 'dart:async';
import '../data/sources/push_messaging_client.dart';
import '../presentation/notifications/in_app_message_controller.dart';
import 'package:flutter/material.dart';
import '../models/in_app_message_payload.dart';
import '../ui_components/in_app_message_dialog.dart';

class InAppMessagingService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> Function(Map<String, dynamic>)? configHintHandler;

  static StreamSubscription<Map<String, dynamic>>? _foreground;
  static StreamSubscription<Map<String, dynamic>>? _opened;
  static InAppMessageController? _messages;
  static int _generation = 0;

  static void initialize({
    Future<void> Function(Map<String, dynamic>)? onConfigHint,
    InAppMessageController? messages,
    PushMessagingClient? messaging,
  }) {
    dispose();
    configHintHandler = onConfigHint;
    _messages = messages;
    final generation = _generation;
    final client = messaging ?? SdkPushMessagingClient();
    try {
      _foreground = client.foregroundMessages.listen(_handleIncomingMessage, onError: (_) {});
      _opened = client.openedMessages.listen(_handleIncomingMessage, onError: (_) {});
      unawaited(_initialMessage(client, generation));
    } catch (_) { /* Announcements remain available when push is unavailable. */ }
  }

  static Future<void> _initialMessage(PushMessagingClient client, int generation) async {
    try {
      final data = await client.initialMessage();
      if (generation == _generation && data != null) _handleIncomingMessage(data);
    } catch (_) { /* Cold-start push delivery is optional. */ }
  }

  static void _handleIncomingMessage(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    final hint = configHintHandler;
    if (hint != null) unawaited(_hint(hint, data));
    final messages = _messages;
    if (messages != null) {
      unawaited(messages.receive(data));
      return;
    }
    final isExplicitInApp = data['type'] == 'in_app_message';
    final hasTitleOrBody = data.containsKey('title') || data.containsKey('body') || data.containsKey('notification_title');
    if (isExplicitInApp || hasTitleOrBody) showMessage(InAppMessagePayload.fromMap(data));
  }

  static Future<void> _hint(Future<void> Function(Map<String, dynamic>) handler, Map<String, dynamic> data) async {
    try { await handler(data); } catch (_) { /* A config refresh must not interrupt push delivery. */ }
  }

  static Future<bool> present(InAppMessagePayload payload, Future<void> Function() acknowledge) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return false;
    final showing = InAppMessageDialog.show(context, payload);
    await acknowledge();
    await showing;
    return true;
  }

  static void dispose() {
    _generation++;
    unawaited(_foreground?.cancel());
    unawaited(_opened?.cancel());
    _foreground = null;
    _opened = null;
    _messages = null;
    configHintHandler = null;
  }

  /// Helper to manually trigger an in-app message (for testing or internal events)
  static void showMessage(InAppMessagePayload payload) {
    final messages = _messages;
    if (messages != null) {
      unawaited(messages.offer(payload));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        InAppMessageDialog.show(context, payload);
      }
    });
  }
}
