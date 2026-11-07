import 'package:envied/envied.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

part 'app_secrets.g.dart';

/// The `.env` values the app uses, compiled in with obfuscation. `.env` itself
/// must never be listed under assets, where it would ship as a readable file.
///
/// After editing `.env`, regenerate:
/// `dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs`
@Envied(path: '.env', requireEnvFile: true, obfuscate: true)
abstract class AppSecrets {
  @EnviedField(varName: 'TMDB_API_KEY', defaultValue: '')
  static final String tmdbApiKey = _AppSecrets.tmdbApiKey;

  @EnviedField(varName: 'MIXPANEL_API_KEY', defaultValue: '')
  static final String mixpanelApiKey = _AppSecrets.mixpanelApiKey;

  @EnviedField(varName: 'FLIXQUEST_API_URL', defaultValue: '')
  static final String flixquestApiUrl = _AppSecrets.flixquestApiUrl;

  @EnviedField(varName: 'LARAVEL_API_URL', defaultValue: '')
  static final String laravelApiUrl = _AppSecrets.laravelApiUrl;

  @EnviedField(varName: 'ONESIGNAL_APP_ID', defaultValue: '')
  static final String oneSignalAppId = _AppSecrets.oneSignalAppId;

  /// Fills `dotenv.env`, which the app reads these values from. Despite its name,
  /// `testLoad` is flutter_dotenv's only way to load without reading an asset.
  static void install() => dotenv.testLoad(mergeWith: <String, String>{
        'TMDB_API_KEY': tmdbApiKey,
        'MIXPANEL_API_KEY': mixpanelApiKey,
        'FLIXQUEST_API_URL': flixquestApiUrl,
        'LARAVEL_API_URL': laravelApiUrl,
        'ONESIGNAL_APP_ID': oneSignalAppId,
      });
}
