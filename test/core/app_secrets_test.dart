import 'dart:io';

import 'package:flixquest/core/config/app_secrets.dart';
import 'package:flixquest/core/config/scraper_secrets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('install gives dotenv every key the app reads', () {
    dotenv.clean();
    AppSecrets.install();

    expect(dotenv.isInitialized, isTrue);
    expect(dotenv.env['TMDB_API_KEY'], AppSecrets.tmdbApiKey);
    expect(dotenv.env['MIXPANEL_API_KEY'], AppSecrets.mixpanelApiKey);
    expect(dotenv.env['FLIXQUEST_API_URL'], AppSecrets.flixquestApiUrl);
    expect(dotenv.env['LARAVEL_API_URL'], AppSecrets.laravelApiUrl);
    expect(dotenv.env['ONESIGNAL_APP_ID'], AppSecrets.oneSignalAppId);
  });

  test('install keeps required keys present even when empty', () {
    dotenv.testLoad(mergeWith: const {'FLIXQUEST_API_URL': ''});
    expect(dotenv.env.containsKey('FLIXQUEST_API_URL'), isTrue);
  });

  // A plain build_runner build keeps old values when these files change.
  group('compiled values match the env files', () {
    Map<String, String> read(String path) => <String, String>{
          for (final line in File(path).readAsLinesSync())
            if (line.contains('=') && !line.trimLeft().startsWith('#'))
              line.substring(0, line.indexOf('=')).trim(): line
                  .substring(line.indexOf('=') + 1)
                  .trim()
                  .replaceAll(RegExp('^["\']|["\']\$'), ''),
        };

    const regenerate = 'Stale values. Run: dart run build_runner clean && '
        'dart run build_runner build --delete-conflicting-outputs';

    test('.env', () {
      final env = read('.env');
      final compiled = <String, String>{
        'TMDB_API_KEY': AppSecrets.tmdbApiKey,
        'MIXPANEL_API_KEY': AppSecrets.mixpanelApiKey,
        'FLIXQUEST_API_URL': AppSecrets.flixquestApiUrl,
        'LARAVEL_API_URL': AppSecrets.laravelApiUrl,
        'ONESIGNAL_APP_ID': AppSecrets.oneSignalAppId,
      };
      for (final entry in compiled.entries) {
        // Compared as a boolean so a failure can't print a secret.
        expect(entry.value == (env[entry.key] ?? ''), isTrue,
            reason: '${entry.key}: $regenerate');
      }
    }, skip: File('.env').existsSync() ? false : 'No .env on this machine');

    test('.env.scraper', () {
      final env = read('.env.scraper');
      final compiled = <String, String>{
        'SCRAPER_PROD_KID': ScraperSecrets.prodKid,
        'SCRAPER_PROD_FRAGMENT': ScraperSecrets.prodFragment,
        'SCRAPER_DEV_KID': ScraperSecrets.devKid,
        'SCRAPER_DEV_FRAGMENT': ScraperSecrets.devFragment,
      };
      for (final entry in compiled.entries) {
        expect(entry.value == env[entry.key], isTrue,
            reason: '${entry.key}: $regenerate');
      }
    },
        skip: File('.env.scraper').existsSync()
            ? false
            : 'No .env.scraper on this machine');
  });

  test('no env file is bundled as a readable asset', () {
    final assets = File('pubspec.yaml')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.startsWith('- .env'));
    expect(assets, isEmpty);
  });
}
