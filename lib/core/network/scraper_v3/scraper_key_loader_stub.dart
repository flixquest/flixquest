import 'scraper_cipher.dart';

/// Plain `dart run` tools have no signed APK or native library to derive from.
Future<ScraperCipher> loadScraperCipher() =>
    throw UnsupportedError('The scraper key needs the Android app');

void reportPlainFallback(String reason) {}
