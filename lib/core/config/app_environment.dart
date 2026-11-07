import 'package:flutter/foundation.dart';

class AppEnvironment {
  const AppEnvironment({this.debugLogging = kDebugMode});
  factory AppEnvironment.fromRuntime() => const AppEnvironment();
  final bool debugLogging;
  Duration get connectTimeout => const Duration(seconds: 10);
  Duration get receiveTimeout => const Duration(seconds: 20);
}
