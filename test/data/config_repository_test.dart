import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/repositories/config_repository.dart';
import 'package:flixquest/preferences/app_dependency_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/fake_dio.dart';

Map<String, dynamic> fixture() => jsonDecode(
        File('test/support/fixtures/bootstrap_config.json').readAsStringSync())
    as Map<String, dynamic>;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDioAdapter adapter;
  late Dio dio;
  late KvStore store;
  setUp(() async {
    dotenv.testLoad(
        fileInput:
            'TMDB_API_KEY=test\nMIXPANEL_API_KEY=test\nFLIXQUEST_API_URL=https://fallback.test');
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    store = KvStore(sharedPrefsSingleton);
    adapter = FakeDioAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
  });
  tearDown(() => dio.close());
  test(
      'bootstrap is public and persists config and legacy values for a cold restart',
      () async {
    adapter.enqueueJson(fixture(), headers: {
      'etag': ['"contract-v1"']
    });
    final config = await ConfigRepository(dio, store).refresh();
    expect(config.updates.latestVersion, '4.2.0');
    expect(adapter.requests.single.uri.path, '/api/v1/config/bootstrap');
    expect(adapter.requests.single.extra['authRequired'], isFalse);
    expect(store.getString('config.bootstrap.etag'), '"contract-v1"');
    expect(sharedPrefsSingleton.getString(AppDependencies.LATEST_APP_VERSION),
        '4.2.0');
    expect(
        sharedPrefsSingleton
            .getStringList(AppDependencies.FLIXQUEST_API_INSTANCES),
        ['https://scraper-1.flixquest.app']);
    expect(
        jsonDecode(sharedPrefsSingleton
            .getString(AppDependencies.OCCASIONAL_THEME)!)['active_theme_id'],
        'custom_campaign');
    expect(
        (await ConfigRepository(dio, KvStore(sharedPrefsSingleton))
                .loadCached())
            .updates
            .latestBuildNumber,
        5);
  });
  test(
      '304 after a cold restart retains the persisted payload and validates its age',
      () async {
    var now = DateTime.utc(2026, 10, 3);
    adapter.enqueueJson(fixture(), headers: {
      'etag': ['"v1"']
    });
    await ConfigRepository(dio, store, now: () => now).refresh();
    now = now.add(const Duration(hours: 2));
    adapter.enqueueJson(null, statusCode: 304, headers: {
      'etag': ['"v1"']
    });
    final restarted =
        ConfigRepository(dio, KvStore(sharedPrefsSingleton), now: () => now);
    final config = await restarted.refresh();
    expect(adapter.requests.last.headers['If-None-Match'], '"v1"');
    expect(config.occasionalTheme.themes.single.effect.enabled, isTrue);
    expect(restarted.lastValidatedAt, now);
  });
  test('offline restart retains cached feature choices and themes', () async {
    final body = fixture();
    (body['data']['features'] as Map)['enable_download'] = false;
    adapter.enqueueJson(body, headers: {
      'etag': ['"v1"']
    });
    await ConfigRepository(dio, store).refresh();
    final originalTime = ConfigRepository(dio, store).lastValidatedAt;
    adapter.enqueueError();
    final restarted = ConfigRepository(dio, KvStore(sharedPrefsSingleton));
    final config = await restarted.refresh();
    expect(config.features.enableDownload, isFalse);
    expect(config.occasionalTheme.activeThemeId, 'custom_campaign');
    expect(restarted.lastValidatedAt, originalTime);
  });
  test('offline empty cache enables playback downloads and live TV', () async {
    adapter.enqueueError();
    final config = await ConfigRepository(dio, store).refresh();
    expect(config.features.enableStream, isTrue);
    expect(config.features.enableDownload, isTrue);
    expect(config.features.enableLiveTv, isTrue);
    expect(config.updates.forcedUpdate, isFalse);
    expect(config.network.flixquestApiUrlV2, 'https://fallback.test');
  });
  test('first offline cutover restores legacy logo network updates and catalog',
      () async {
    await sharedPrefsSingleton.setString(
        AppDependencies.FLIXQUEST_LOGO_URL, 'https://legacy.test/logo.png');
    await sharedPrefsSingleton.setString(AppDependencies.OCCASIONAL_THEME,
        '{"enabled":true,"themes":[{"id":"xmas","enabled":true}]}');
    await sharedPrefsSingleton.setInt(AppDependencies.LATEST_BUILD_NUMBER, 17);
    final config = await ConfigRepository(dio, store).loadCached();
    expect(config.branding.appLogoUrl, 'https://legacy.test/logo.png');
    expect(config.occasionalTheme.themes.single.id, 'xmas');
    expect(config.updates.latestBuildNumber, 17);
  });
  for (final invalid in [
    {'success': false, 'data': {}},
    {'success': true, 'data': 'invalid'},
  ]) {
    test('invalid bootstrap preserves the last valid payload: $invalid',
        () async {
      adapter.enqueueJson(fixture(), headers: {
        'etag': ['"good"']
      });
      await ConfigRepository(dio, store).refresh();
      adapter.enqueueJson(invalid, headers: {
        'etag': ['"bad"']
      });
      final config = await ConfigRepository(dio, store).refresh();
      expect(config.updates.latestBuildNumber, 5);
      expect(config.occasionalTheme.themes.single.id, 'custom_campaign');
      expect(store.getString('config.bootstrap.etag'), '"good"');
    });
  }
  test('a corrupt snapshot never replays an orphaned ETag', () async {
    await store.setString('config.bootstrap.snapshot', 'not-json');
    await store.setString('config.bootstrap.etag', '"orphan"');
    adapter.enqueueJson(fixture());
    final config = await ConfigRepository(dio, store).refresh();
    expect(
        adapter.requests.single.headers.containsKey('If-None-Match'), isFalse);
    expect(config.updates.latestBuildNumber, 5);
    expect(store.getString('config.bootstrap.etag'), isNull);
  });
  test('a 304 without a payload retries unconditionally', () async {
    adapter.enqueueJson(null, statusCode: 304);
    adapter.enqueueJson(fixture());
    final config = await ConfigRepository(dio, store).refresh();
    expect(config.updates.latestBuildNumber, 5);
    expect(adapter.requests.last.headers.containsKey('If-None-Match'), isFalse);
  });
  test('operator config changes replace settings and the validator together',
      () async {
    adapter.enqueueJson(fixture(), headers: {
      'etag': ['"v1"']
    });
    await ConfigRepository(dio, store).refresh();
    final updated = fixture();
    (updated['data']['features'] as Map)['enable_stream'] = false;
    adapter.enqueueJson(updated, headers: {
      'etag': ['"v2"']
    });
    final config = await ConfigRepository(dio, store).refresh();
    expect(config.features.enableStream, isFalse);
    expect(store.getString('config.bootstrap.etag'), '"v2"');
    expect(
        (await ConfigRepository(dio, store).loadCached()).features.enableStream,
        isFalse);
  });

  test(
      'invalid seasonal update preserves the catalog while applying feature changes',
      () async {
    adapter.enqueueJson(fixture(), headers: {
      'etag': ['"v1"']
    });
    await ConfigRepository(dio, store).refresh();
    final next = fixture();
    next['data']['features']['enable_stream'] = false;
    next['data']['occasional_theme'] = {
      'enabled': true,
      'themes': [
        {'id': 'bad', 'enabled': true}
      ]
    };
    adapter.enqueueJson(next, headers: {
      'etag': ['"v2"']
    });
    final config = await ConfigRepository(dio, store).refresh();
    expect(config.features.enableStream, isFalse);
    expect(config.occasionalTheme.themes.single.id, 'custom_campaign');
    expect(store.getString('config.bootstrap.etag'), '"v2"');
    expect(
        (await ConfigRepository(dio, store).loadCached()).features.enableStream,
        isFalse);
  });
}
