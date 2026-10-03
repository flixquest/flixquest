import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../models/in_app_message_payload.dart';
import '../ui_components/in_app_message_dialog.dart';

class InAppMessagingService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> Function(Map<String, dynamic>)? configHintHandler;

  static void initialize({Future<void> Function(Map<String, dynamic>)? onConfigHint}) {
    configHintHandler = onConfigHint;
    // Listen for foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleIncomingMessage(message);
    });

    // Listen for when app is opened via FCM message click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleIncomingMessage(message);
    });
  }

  static void _handleIncomingMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;
    unawaited(configHintHandler?.call(data));

    // Check if this payload is intended for in-app messaging display
    final isExplicitInApp = data['type'] == 'in_app_message';
    final hasTitleOrBody = data.containsKey('title') || data.containsKey('body') || data.containsKey('notification_title');

    if (isExplicitInApp || hasTitleOrBody) {
      final payload = InAppMessagePayload.fromMap(data);

      // Give a tiny frame delay to ensure navigator context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          InAppMessageDialog.show(context, payload);
        }
      });
    }
  }

  /// Helper to manually trigger an in-app message (for testing or internal events)
  static void showMessage(InAppMessagePayload payload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        InAppMessageDialog.show(context, payload);
      }
    });
  }
}
