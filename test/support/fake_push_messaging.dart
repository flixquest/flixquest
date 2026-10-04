import 'dart:async';
import 'package:flixquest/data/sources/push_messaging_client.dart';

class FakePushMessaging implements PushMessagingClient {
  final tokens = StreamController<String>.broadcast(sync: true);
  final foreground =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final opened = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  String? token = 'device-token';
  Future<String?>? pendingToken;
  Map<String, dynamic>? initial;
  Future<Map<String, dynamic>?>? pendingInitial;
  int tokenReads = 0;
  @override
  Future<String?> getToken() async {
    tokenReads++;
    return pendingToken == null ? token : await pendingToken;
  }

  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Stream<Map<String, dynamic>> get foregroundMessages => foreground.stream;
  @override
  Stream<Map<String, dynamic>> get openedMessages => opened.stream;
  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      pendingInitial == null ? initial : await pendingInitial;
  Future<void> dispose() async {
    await tokens.close();
    await foreground.close();
    await opened.close();
  }
}
