import 'dart:convert';

import 'package:http/http.dart' as http;

import 'scraper_cipher.dart';
import 'scraper_key_loader_stub.dart'
    if (dart.library.ui) 'scraper_key_loader.dart';

class ScraperV3Exception implements Exception {
  const ScraperV3Exception(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScraperV3RawResponse {
  const ScraperV3RawResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

/// A reply with its original status and its JSON text, decrypted when sealed.
class ScraperV3Response {
  const ScraperV3Response(this.statusCode, this.body);

  final int statusCode;
  final String body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

typedef ScraperV3Transport = Future<ScraperV3RawResponse> Function(
  Uri uri,
  Map<String, Object?> body,
  Duration timeout,
);

/// Calls the scraper's encrypted `/api/v3` routes.
///
/// Playback URLs, subtitle files and catalogues stay on v2: the player has to
/// fetch those with plain GETs.
class ScraperV3Client {
  ScraperV3Client(this._transport);

  factory ScraperV3Client.http(http.Client client) =>
      ScraperV3Client((uri, requestBody, timeout) async {
        final response = await client
            .post(
              uri,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(timeout);
        return ScraperV3RawResponse(
          response.statusCode,
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
      });

  static const _prefix = '/api/v3';

  /// Replaced in tests, which have no signed APK or native library.
  static Future<ScraperCipher> Function() cipherLoader = loadScraperCipher;

  /// Told when a call falls back to plain. Replaced in tests.
  static void Function(String reason) fallbackReporter = reportPlainFallback;

  /// Clears the loaded key and clock correction, for tests.
  static void reset() {
    _cipher = null;
    _clockOffsetSeconds = 0;
  }

  static Future<ScraperCipher>? _cipher;

  /// Correction for a device clock outside the server's window, learned from
  /// the server's reply. Shared because the device clock is too.
  static int _clockOffsetSeconds = 0;

  final ScraperV3Transport _transport;

  static Future<ScraperCipher> _loadCipher() {
    // Future.sync also catches a loader that throws before returning a future.
    return _cipher ??= Future.sync(cipherLoader).catchError((Object error) {
      // A failed load must not be remembered for the rest of the session.
      _cipher = null;
      throw ScraperV3Exception('Secure scraper session unavailable: $error');
    });
  }

  static int get _deviceSeconds =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// [baseUrl] may include the `/api/v2` suffix older settings stored.
  static Uri endpoint(String baseUrl, String route) {
    final root = baseUrl
        .trim()
        .replaceFirst(RegExp(r'/+$'), '')
        .replaceFirst(RegExp(r'/api/v\d+$'), '');
    if (root.isEmpty) {
      throw const ScraperV3Exception('Scraper API URL is not configured');
    }
    return Uri.parse('$root$_prefix$route');
  }

  /// Tries encrypted first on every call, and remembers no downgrade, so setting
  /// the server back to `sealed` restores encryption straight away.
  ///
  /// The app only sends plain when it has no working key or the server says it
  /// can't read the request. A server in `sealed` mode refuses plain requests, so
  /// the server's `SCRAPER_V3_MODE` decides whether this fail-safe can work.
  Future<ScraperV3Response> post(
    String baseUrl,
    String route,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = endpoint(baseUrl, route);
    final path = '$_prefix$route';

    final ScraperCipher cipher;
    try {
      cipher = await _loadCipher();
    } on ScraperV3Exception {
      fallbackReporter('key_unavailable');
      return _sendPlain(uri, params, timeout);
    }

    var response = await _exchange(cipher, uri, path, params, timeout);
    final serverTime = response == null ? null : _clockCorrection(response);
    if (serverTime != null) {
      _clockOffsetSeconds = serverTime - _deviceSeconds;
      response = await _exchange(cipher, uri, path, params, timeout);
    }
    if (response == null) {
      fallbackReporter('seal_failed');
      return _sendPlain(uri, params, timeout);
    }
    if (_serverAllowsPlain(response)) {
      fallbackReporter('key_rejected');
      return _sendPlain(uri, params, timeout);
    }
    return response;
  }

  Future<ScraperV3Response> _sendPlain(
    Uri uri,
    Map<String, Object?> params,
    Duration timeout,
  ) async {
    final raw = await _transport(
      uri,
      <String, Object?>{'plain': true, 'params': params},
      timeout,
    );
    return ScraperV3Response(raw.statusCode, raw.body);
  }

  /// Null when the request could not be sealed.
  Future<ScraperV3Response?> _exchange(
    ScraperCipher cipher,
    Uri uri,
    String path,
    Map<String, Object?> params,
    Duration timeout,
  ) async {
    final SealedScraperRequest sealed;
    try {
      sealed = await cipher.seal(
        path,
        params,
        timestampSeconds: _deviceSeconds + _clockOffsetSeconds,
      );
    } catch (_) {
      return null;
    }
    final raw = await _transport(uri, sealed.envelope, timeout);

    final envelope = _envelopeOf(raw.body);
    if (envelope == null) {
      // A server in open mode replies in plain JSON. Anything else on a 2xx,
      // such as a captive portal's HTML page, did not come from a v3 route.
      if (raw.statusCode >= 200 &&
          raw.statusCode < 300 &&
          _jsonObjectOf(raw.body) == null) {
        throw const ScraperV3Exception('The scraper sent an unreadable reply');
      }
      return ScraperV3Response(raw.statusCode, raw.body);
    }
    try {
      return ScraperV3Response(
        raw.statusCode,
        await cipher.open(path, sealed.nonce, envelope),
      );
    } catch (_) {
      throw const ScraperV3Exception('The scraper reply failed verification');
    }
  }

  static Map<String, dynamic>? _jsonObjectOf(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static bool _serverAllowsPlain(ScraperV3Response response) =>
      response.statusCode == 401 &&
      _jsonObjectOf(response.body)?['fallback'] == 'plain';

  static Map<String, dynamic>? _envelopeOf(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> &&
              decoded['iv'] is String &&
              decoded['ct'] is String
          ? decoded
          : null;
    } on FormatException {
      return null;
    }
  }

  static int? _clockCorrection(ScraperV3Response response) {
    if (response.statusCode != 401) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] == 'clock_skew') {
        final serverTime = decoded['serverTime'];
        return serverTime is int ? serverTime : null;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
