import 'dart:async';

import 'support/sealed_scraper.dart';

/// Tests have no signed APK or native library to derive the scraper key from.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useTestScraperCipher();
  await testMain();
}
