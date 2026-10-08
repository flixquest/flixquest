import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/vast_preroll_config.dart';
import 'vast.dart';

/// The pre-roll the player shows and the network that served it.
typedef VastPreroll = ({
  VastAd ad,
  VastMediaFile media,
  VastPrerollSource source,
});

/// Resolves a VAST tag to one playable linear ad and sends its tracking.
///
/// Every failure reports the matching VAST error code to the error URLs
/// collected so far and returns null, so the caller simply plays the content.
class VastClient {
  VastClient({http.Client? httpClient, Future<String> Function()? userAgent})
      : _http = httpClient ?? http.Client(),
        _userAgent = userAgent ?? _deviceUserAgent;

  final http.Client _http;
  final Future<String> Function() _userAgent;

  Future<VastAd?> load(
    Uri tag, {
    required Duration timeout,
    int maxWrappers = 5,
  }) async {
    final deadline = DateTime.now().add(timeout);
    final wrappers = <VastAdNode>[];
    var next = tag;
    var depth = 0;
    while (true) {
      final remaining = deadline.difference(DateTime.now());
      final VastDocument document;
      try {
        if (remaining <= Duration.zero) throw TimeoutException('VAST budget');
        document = VastDocument.parse(await _get(next, remaining));
      } on TimeoutException {
        _log('tag timed out depth=$depth');
        _reportWrappers(wrappers,
            depth == 0 ? VastError.wrapperGeneral : VastError.wrapperTimeout);
        return null;
      } on VastException catch (error) {
        _log('invalid response depth=$depth ($error)');
        _reportWrappers(wrappers, error.code);
        return null;
      } catch (error) {
        _log('request failed depth=$depth ($error)');
        _reportWrappers(wrappers, VastError.wrapperGeneral);
        return null;
      }

      // Try ads in order: a later standalone ad is the fallback for one that
      // cannot be played.
      VastAdNode? inline;
      VastAdNode? wrapper;
      for (final ad in document.ads) {
        if (ad.isWrapper) {
          wrapper ??= ad;
          continue;
        }
        final media = ad.toAd(const []).pickMediaFile(maxHeight: 4320);
        if (media != null) {
          inline = ad;
          break;
        }
        _send(ad.errors, errorCode: VastError.noSupportedMedia);
      }
      if (inline != null) {
        final ad = inline.toAd(wrappers);
        _log('ad ${ad.id ?? '?'} from ${ad.adSystem ?? '?'} '
            'duration=${ad.duration.inSeconds}s '
            'skipAfter=${ad.skipAfter?.inSeconds}s wrappers=${wrappers.length}');
        return ad;
      }
      if (wrapper == null) {
        _log(document.ads.isEmpty ? 'no fill' : 'no playable linear ad');
        _send(document.errors, errorCode: VastError.noAdsAfterWrapper);
        _reportWrappers(
            wrappers,
            document.ads.isEmpty
                ? VastError.noAdsAfterWrapper
                : VastError.noSupportedMedia);
        return null;
      }
      if (depth >= maxWrappers) {
        _log('wrapper limit $maxWrappers reached');
        _reportWrappers([...wrappers, wrapper], VastError.wrapperLimit);
        return null;
      }
      wrappers.add(wrapper);
      next = wrapper.wrapperTagUri!;
      depth++;
    }
  }

  /// Asks each network in [sources] in order and returns the first ad with a
  /// rendition within the caps. A network is asked only after the one before
  /// it returned no ad, so each adds at most its own request budget to the
  /// wait. [cancelled] stops the chain, for example when the player closes.
  Future<VastPreroll?> loadPreroll(
    List<VastPrerollSource> sources, {
    required int maxHeight,
    int? maxBitrate,
    bool Function()? cancelled,
  }) async {
    for (final source in sources) {
      if (cancelled?.call() ?? false) return null;
      try {
        final ad = await load(source.tagUrl,
            timeout: source.requestTimeout, maxWrappers: source.maxWrappers);
        final media =
            ad?.pickMediaFile(maxHeight: maxHeight, maxBitrate: maxBitrate);
        if (ad != null && media != null) {
          _log('pre-roll from ${source.network.name}');
          return (ad: ad, media: media, source: source);
        }
        _log('no ad from ${source.network.name}');
      } catch (error) {
        _log('${source.network.name} unavailable ($error)');
      }
    }
    return null;
  }

  Future<String> _get(Uri url, Duration timeout) async {
    final response = await _http.get(
      expandVastMacros(url),
      headers: {
        HttpHeaders.userAgentHeader: await _userAgent(),
        HttpHeaders.acceptHeader: 'application/xml, text/xml, */*',
      },
    ).timeout(timeout);
    if (response.statusCode != 200) {
      throw VastException(
          VastError.wrapperGeneral, 'HTTP ${response.statusCode}');
    }
    return response.body;
  }

  void _reportWrappers(List<VastAdNode> wrappers, int code) {
    _send([for (final wrapper in wrappers) ...wrapper.errors], errorCode: code);
  }

  /// Fire-and-forget tracking pixels. Failures are never surfaced: tracking
  /// must not affect playback.
  void send(
    Iterable<Uri> urls, {
    int? errorCode,
    Duration? adPlayhead,
    Uri? assetUri,
  }) =>
      _send(urls,
          errorCode: errorCode, adPlayhead: adPlayhead, assetUri: assetUri);

  void _send(
    Iterable<Uri> urls, {
    int? errorCode,
    Duration? adPlayhead,
    Uri? assetUri,
  }) {
    for (final url in urls) {
      unawaited(() async {
        try {
          await _http.get(
            expandVastMacros(url,
                errorCode: errorCode,
                adPlayhead: adPlayhead,
                assetUri: assetUri),
            headers: {HttpHeaders.userAgentHeader: await _userAgent()},
          ).timeout(const Duration(seconds: 10));
        } catch (_) {
          // A lost pixel is the ad server's loss, never the viewer's.
        }
      }());
    }
  }

  void close() => _http.close();

  static void _log(String message) => debugPrint('[VAST] $message');

  static String? _cachedUserAgent;

  /// The system WebView's own user agent: the ad's click-through opens in that
  /// WebView, so the ad request, its tracking and the click share one browser
  /// identity, as with Google's IMA SDK. Falls back to an app identifier with
  /// the OS and model tokens ad servers use for device targeting.
  static Future<String> _deviceUserAgent() async {
    final cached = _cachedUserAgent;
    if (cached != null) return cached;
    try {
      final webView = await WebViewController().getUserAgent();
      if (webView != null && webView.trim().isNotEmpty) {
        return _cachedUserAgent = webView.trim();
      }
    } catch (_) {
      // No WebView available; use the app identifier below.
    }
    var platform = Platform.operatingSystem;
    var app = 'FlixQuest';
    try {
      final package = await PackageInfo.fromPlatform();
      app = 'FlixQuest/${package.version}';
      final device = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await device.androidInfo;
        platform = 'Linux; Android ${info.version.release}; ${info.model}';
      } else if (Platform.isIOS) {
        final info = await device.iosInfo;
        final version = info.systemVersion.replaceAll('.', '_');
        platform = '${info.model}; CPU OS $version like Mac OS X';
      }
    } catch (_) {
      // Keep the generic tokens.
    }
    return _cachedUserAgent = 'Mozilla/5.0 ($platform) $app';
  }
}
