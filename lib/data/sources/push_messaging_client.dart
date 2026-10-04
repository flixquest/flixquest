import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

abstract interface class PushMessagingClient {
  Future<String?> getToken();
  Stream<String> get tokenRefresh;
  Stream<Map<String, dynamic>> get foregroundMessages;
  Stream<Map<String, dynamic>> get openedMessages;
  Future<Map<String, dynamic>?> initialMessage();
}

class SdkPushMessagingClient implements PushMessagingClient {
  FirebaseMessaging get _sdk => FirebaseMessaging.instance;
  @override
  Future<String?> getToken() async {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        await _sdk.getAPNSToken() == null) {
      return null;
    }
    return _sdk.getToken();
  }

  @override
  Stream<String> get tokenRefresh => _sdk.onTokenRefresh;
  Map<String, dynamic> _data(RemoteMessage message) => {
        ...message.data,
        if (!message.data.containsKey('announcement_id') &&
            !message.data.containsKey('id') &&
            message.messageId != null)
          'id': 'fcm:${message.messageId}',
      };
  @override
  Stream<Map<String, dynamic>> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_data);
  @override
  Stream<Map<String, dynamic>> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_data);
  @override
  Future<Map<String, dynamic>?> initialMessage() async {
    final message = await _sdk.getInitialMessage();
    return message == null ? null : _data(message);
  }
}
