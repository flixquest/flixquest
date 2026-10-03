import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Deployment configuration. Base URLs always end in `/api/v1/` for Dio.
class AppEnvironment {
  const AppEnvironment._(this.laravelApiUrl, this.debugLogging);

  factory AppEnvironment.fromRuntime() => AppEnvironment.resolve(
        defineUrl: const String.fromEnvironment('LARAVEL_API_URL'),
        env: dotenv.isInitialized ? dotenv.env : const {},
        isDebug: kDebugMode,
      );

  factory AppEnvironment.resolve({
    String defineUrl = '',
    Map<String, String> env = const {},
    bool isDebug = false,
  }) {
    final configured = defineUrl.trim().isNotEmpty
        ? defineUrl.trim()
        : (env['LARAVEL_API_URL'] ?? '').trim();
    if (configured.isEmpty && !isDebug) {
      throw StateError(
          'LARAVEL_API_URL must be configured for release builds.');
    }
    final raw = configured.isEmpty ? 'http://10.0.2.2:8000' : configured;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(raw, 'LARAVEL_API_URL', 'Invalid API base URL');
    }
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (!path.endsWith('/api/v1')) {
      path = '$path/api/v1';
    }
    return AppEnvironment._(
      uri.replace(path: '$path/').toString(),
      isDebug,
    );
  }

  final String laravelApiUrl;
  final bool debugLogging;
  Duration get connectTimeout => const Duration(seconds: 10);
  Duration get receiveTimeout => const Duration(seconds: 20);
}
