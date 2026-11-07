import 'package:envied/envied.dart';

part 'scraper_secrets.g.dart';

/// Inputs to the scraper key, generated from `.env`, which is never bundled as an
/// asset. Run `dart run tool/scraper_key.dart init` to add them to it.
@Envied(path: '.env', requireEnvFile: true)
abstract class ScraperSecrets {
  @EnviedField(varName: 'SCRAPER_PROD_KID', obfuscate: true)
  static final String prodKid = _ScraperSecrets.prodKid;

  @EnviedField(varName: 'SCRAPER_PROD_FRAGMENT', obfuscate: true)
  static final String prodFragment = _ScraperSecrets.prodFragment;

  @EnviedField(varName: 'SCRAPER_DEV_KID', obfuscate: true)
  static final String devKid = _ScraperSecrets.devKid;

  @EnviedField(varName: 'SCRAPER_DEV_FRAGMENT', obfuscate: true)
  static final String devFragment = _ScraperSecrets.devFragment;
}
