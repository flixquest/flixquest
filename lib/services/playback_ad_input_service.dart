import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

typedef PlaybackContinueTap = Future<bool> Function(
    WebViewController controller, Uri document);

/// Sends one Android touch to the tag page's Continue control. The native
/// bridge checks the document and button again before dispatching input.
Future<bool> tapPlaybackContinue(
    WebViewController controller, Uri document) async {
  final platform = controller.platform;
  if (platform is! AndroidWebViewController) return false;
  return await const MethodChannel('dev.beamlak.flixquest/playback_ad_input')
          .invokeMethod<bool>('tapContinue', {
        'webViewId': platform.webViewIdentifier,
        'document': document.toString(),
      }) ??
      false;
}
