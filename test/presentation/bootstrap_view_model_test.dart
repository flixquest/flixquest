import 'package:dio/dio.dart';
import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/repositories/config_repository.dart';
import 'package:flixquest/models/banner_ad.dart';
import 'package:flixquest/presentation/config/bootstrap_view_model.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/fake_dio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bootstrap feeds the shared mobile and TV dependency provider',
      () async {
    dotenv.testLoad(
        fileInput:
            'TMDB_API_KEY=local\nMIXPANEL_API_KEY=test\nFLIXQUEST_API_URL=https://fallback.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    final transport = FakeDioAdapter()
      ..enqueueJson({
        'success': true,
        'data': {
          'features': {
            'enable_stream': false,
            'enable_download': false,
            'enable_live_tv': false
          },
          'branding': {'app_logo_url': 'https://branding.test/logo.svg'},
          'updates': {
            'forced_update': true,
            'latest_version': '5.0',
            'latest_build_number': 50,
            'min_build_number': 40,
            'app_download_url': 'https://download.test',
            'change_log': 'New'
          },
          'network': {
            'flixquest_api_instances': [
              'https://scraper-a.test',
              'https://scraper-b.test'
            ],
            'flixquest_api_url_v2': 'https://fallback-new.test',
            'tmdb_api_key': 'override',
            'tmdb_proxy': 'https://proxy.test'
          },
          'ads': {
            'banner_ad_network': 'startio',
            'hosted_banner_mode': 'priority',
            'unity_test_mode': true,
            'startio_banner_enabled': true,
            'startio_interstitial_enabled': true,
            'startio_interstitial_interval_seconds': 3,
            'startio_tv_interstitial_mode': 'automatic'
          },
          'banners': [
            {
              'promo': {
                'enabled': false,
                'placements': ['home_all_hero'],
                'width': 320,
                'height': 50
              }
            }
          ],
          'occasional_theme': {
            'enabled': true,
            'themes': [
              {
                'id': 'enkutatash',
                'enabled': true,
                'effect': {'enabled': true}
              }
            ]
          },
        }
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = transport;
    final provider = AppDependencyProvider();
    final vm = BootstrapViewModel(
        ConfigRepository(dio, KvStore(sharedPrefsSingleton)), provider);
    await vm.refresh();
    expect(provider.displayWatchNowButton, isFalse);
    expect(provider.displayDownloadButton, isFalse);
    expect(provider.displayLiveTV, isFalse);
    expect(provider.flixQuestLogo, 'https://branding.test/logo.svg');
    expect(provider.flixquestAPIInstances,
        ['https://scraper-a.test', 'https://scraper-b.test']);
    expect(provider.configuredFlixquestAPIURL, 'https://fallback-new.test');
    expect(provider.tmdbProxy, 'https://proxy.test');
    expect(TMDB_API_KEY, 'override');
    expect(provider.isForcedUpdate, isTrue);
    expect(provider.minimumBuildNumber, 40);
    expect(provider.hostedBannerMode, HostedBannerMode.priority);
    expect(provider.startIoBannerEnabled, isTrue);
    expect(
        provider.startIoAds.interstitialInterval, const Duration(seconds: 60));
    expect(provider.startIoAds.tvInterstitialMode.name, 'automatic');
    expect(provider.startIoAds.testMode, isTrue);
    expect(provider.bannerConfigFor('promo').enabled, isFalse);
    expect(provider.activeOccasionalTheme?.id, 'enkutatash');
    expect(provider.shouldShowOccasionalEffects, isTrue);
    vm.dispose();
    provider.dispose();
    dio.close();
    TMDB_API_KEY = '';
  });
  test(
      'offline bootstrap restores user selection and effects across provider restart',
      () async {
    dotenv.testLoad(
        fileInput:
            'TMDB_API_KEY=local\nMIXPANEL_API_KEY=test\nFLIXQUEST_API_URL=https://fallback.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    final adapter = FakeDioAdapter()
      ..enqueueJson({
        'success': true,
        'data': {
          'occasional_theme': {
            'enabled': true,
            'allow_user_selection': true,
            'effects_enabled': true,
            'active_theme_id': 'halloween',
            'themes': [
              {
                'id': 'halloween',
                'enabled': true,
                'priority': 100,
                'effect': {'enabled': true}
              },
              {
                'id': 'christmas',
                'enabled': true,
                'priority': 1,
                'effect': {'enabled': true}
              },
            ]
          },
        }
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final store = KvStore(sharedPrefsSingleton);
    final first = AppDependencyProvider();
    await first.getOccasionalTheme();
    final vm = BootstrapViewModel(ConfigRepository(dio, store), first);
    await vm.refresh();
    first.selectOccasionalTheme('christmas');
    first.occasionalEffectsEnabled = false;
    await Future<void>.delayed(Duration.zero);
    vm.dispose();
    first.dispose();
    final restored = AppDependencyProvider();
    await restored.getOccasionalTheme();
    final next = BootstrapViewModel(
        ConfigRepository(dio, KvStore(sharedPrefsSingleton)), restored);
    await next.hydrate();
    expect(restored.activeOccasionalTheme?.id, 'christmas');
    expect(restored.selectedOccasionalThemeId, 'christmas');
    expect(restored.shouldShowOccasionalEffects, isFalse);
    adapter.enqueueError();
    await next.refresh();
    expect(restored.activeOccasionalTheme?.id, 'christmas');
    restored.selectOccasionalTheme('automatic');
    expect(restored.activeOccasionalTheme?.id, 'halloween');
    next.dispose();
    restored.dispose();
    dio.close();
  });
  test('offline empty-cache hydration keeps phone and TV features available',
      () async {
    dotenv.testLoad(
        fileInput:
            'TMDB_API_KEY=local\nMIXPANEL_API_KEY=test\nFLIXQUEST_API_URL=https://fallback.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    final dio = Dio();
    final provider = AppDependencyProvider();
    final vm = BootstrapViewModel(
        ConfigRepository(dio, KvStore(sharedPrefsSingleton)), provider);
    await vm.hydrate();
    expect(provider.displayWatchNowButton, isTrue);
    expect(provider.displayDownloadButton, isTrue);
    expect(provider.displayLiveTV, isTrue);
    expect(provider.isForcedUpdate, isFalse);
    expect(provider.activeOccasionalTheme, isNull);
    expect(provider.configuredFlixquestAPIURL, 'https://fallback.test');
    vm.dispose();
    provider.dispose();
    dio.close();
  });
}
