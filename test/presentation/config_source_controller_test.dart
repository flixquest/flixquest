import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'package:dio/dio.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/preferences/app_dependency_preferences.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/data/models/bootstrap_config.dart';
import 'package:flixquest/data/repositories/config_repository.dart';
import 'package:flixquest/data/sources/firebase_config_source.dart';
import 'package:flixquest/presentation/config/bootstrap_view_model.dart';
import 'package:flixquest/presentation/config/config_source_controller.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_dio.dart';

class FakeFirebaseConfigSource implements FirebaseConfigSource {
  final hints = StreamController<void>.broadcast(sync: true);
  BootstrapConfig? payload;
  Future<BootstrapConfig?>? pending;
  int fetches = 0;
  @override
  Stream<void> get updates => hints.stream;
  @override
  Future<BootstrapConfig?> refresh() async {
    fetches++;
    return pending == null ? payload : await pending;
  }
}

class FakeRemoteConfigSdk extends Fake implements FirebaseRemoteConfig {
  bool offline = false;
  final values = <String, RemoteConfigValue>{};
  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {}
  @override
  Future<void> setDefaults(Map<String, dynamic> parameters) async {}
  @override
  Future<bool> activate() async => false;
  @override
  Future<bool> fetchAndActivate() async {
    if (offline) throw StateError('offline');
    return false;
  }

  @override
  Map<String, RemoteConfigValue> getAll() => values;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDioAdapter adapter;
  late Dio dio;
  late KvStore store;
  late AppDependencyProvider provider;
  late ConfigRepository repository;
  late FakeFirebaseConfigSource firebase;
  late ConfigSourceController controller;

  ConfigSourceController createController() => ConfigSourceController(
      repository, BootstrapViewModel(repository, provider), store, firebase);
  void respond(String? source, {String logo = 'Laravel', bool stream = false}) {
    adapter.enqueueJson({
      'success': true,
      'data': {
        if (source != null) 'config_source': source,
        'branding': {'app_logo_url': logo},
        'features': {'enable_stream': stream},
      },
    }, headers: {
      'etag': ['"$source-$logo"'],
    });
  }

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
    repository = ConfigRepository(dio, store);
    provider = AppDependencyProvider();
    firebase = FakeFirebaseConfigSource()
      ..payload = firebaseConfigSnapshot(
          {'app_logo_url': 'Firebase', 'enable_stream': true});
    controller = createController();
  });
  tearDown(() async {
    controller.dispose();
    provider.dispose();
    await firebase.hints.close();
    dio.close();
  });

  test('Laravel chooses Firebase without applying Laravel payload fields',
      () async {
    respond('firebase');
    await controller.boot();
    expect(provider.flixQuestLogo, 'Firebase');
    expect(provider.displayWatchNowButton, isTrue);
    expect(firebase.fetches, 1);
  });
  test(
      'one running build switches in both directions and keeps source caches separate',
      () async {
    respond('laravel');
    await controller.boot();
    expect(provider.flixQuestLogo, 'Laravel');
    expect(provider.displayWatchNowButton, isFalse);
    expect(firebase.fetches, 0);
    respond('firebase');
    await controller.onResume();
    expect(provider.flixQuestLogo, 'Firebase');
    expect(provider.displayWatchNowButton, isTrue);
    respond('laravel', logo: 'Laravel 2');
    await controller.onResume();
    expect(provider.flixQuestLogo, 'Laravel 2');
    expect(provider.displayWatchNowButton, isFalse);
    firebase.payload = null;
    respond('firebase');
    await controller.onResume();
    expect(provider.flixQuestLogo, 'Firebase');
    expect(adapter.requests.length, 4);
    expect(dio.options.baseUrl, 'https://backend.test/api/v1/');
  });

  for (final source in ['laravel', 'firebase']) {
    test('offline restart restores the $source choice and matching payload',
        () async {
      respond(source);
      await controller.boot();
      controller.dispose();
      provider.dispose();
      provider = AppDependencyProvider();
      repository = ConfigRepository(dio, KvStore(sharedPrefsSingleton));
      controller = createController();
      firebase.payload = null;
      await controller.hydrate();
      expect(provider.flixQuestLogo,
          source == 'firebase' ? 'Firebase' : 'Laravel');
      adapter.enqueueError();
      await controller.boot();
      expect(provider.flixQuestLogo,
          source == 'firebase' ? 'Firebase' : 'Laravel');
      expect(provider.displayWatchNowButton, source == 'firebase');
    });
    test('304 validates the cached $source choice on every resume', () async {
      respond(source);
      await controller.boot();
      for (var i = 0; i < 2; i++) {
        adapter.enqueueJson(null, statusCode: 304);
        await controller.onResume();
      }
      expect(adapter.requests.length, 3);
      expect(
          adapter.requests.last.headers['If-None-Match'], '"$source-Laravel"');
      expect(provider.flixQuestLogo,
          source == 'firebase' ? 'Firebase' : 'Laravel');
      expect(firebase.fetches, source == 'firebase' ? 3 : 0);
    });
  }

  test('first offline boot ignores legacy and unselected Firebase preferences',
      () async {
    await store.setJson('config.firebase.snapshot', firebase.payload!.toJson());
    await sharedPrefsSingleton.setString(
        AppDependencies.FLIXQUEST_LOGO_URL, 'Unselected');
    adapter.enqueueError();
    await controller.hydrate();
    await controller.boot();
    expect(provider.flixQuestLogo, 'default');
    expect(provider.displayWatchNowButton, isTrue);
    expect(provider.displayDownloadButton, isTrue);
    expect(provider.displayLiveTV, isTrue);
    expect(firebase.fetches, 0);
  });

  for (final invalid in [null, 'unknown']) {
    test('invalid selector $invalid retains the valid choice and validator',
        () async {
      respond('firebase');
      await controller.boot();
      respond(invalid, logo: 'Invalid candidate');
      await controller.onResume();
      expect(provider.flixQuestLogo, 'Firebase');
      expect((await repository.loadCached(requireSource: true)).configSource,
          'firebase');
      adapter.enqueueJson(null, statusCode: 304);
      await controller.onResume();
      expect(
          adapter.requests.last.headers['If-None-Match'], '"firebase-Laravel"');
    });
  }

  test(
      'missing selector and orphan 304 cannot choose a provider on first launch',
      () async {
    respond(null);
    await controller.boot();
    expect(provider.flixQuestLogo, 'default');
    adapter.enqueueJson(null, statusCode: 304);
    adapter.enqueueError();
    await controller.onResume();
    expect(provider.flixQuestLogo, 'default');
    expect(firebase.fetches, 0);
    expect(adapter.requests.length, 3);
    expect(adapter.requests.last.headers.containsKey('If-None-Match'), isFalse);
  });

  test(
      'late Firebase response cannot overwrite a newer Laravel choice or its cache',
      () async {
    final oldFetch = Completer<BootstrapConfig?>();
    firebase.pending = oldFetch.future;
    respond('firebase');
    final oldRefresh = controller.boot();
    await pumpEventQueue();
    expect(firebase.fetches, 1);
    respond('laravel', logo: 'New Laravel');
    await controller.onResume();
    expect(provider.flixQuestLogo, 'New Laravel');
    oldFetch.complete(firebase.payload);
    await oldRefresh;
    expect(provider.flixQuestLogo, 'New Laravel');
    expect(store.getJson('config.firebase.snapshot'), isNull);
  });

  test(
      'Firebase realtime hints consult Laravel before applying Firebase changes',
      () async {
    respond('firebase');
    await controller.boot();
    firebase.payload =
        firebaseConfigSnapshot({'app_logo_url': 'Firebase update'});
    respond('laravel', logo: 'Operator chose Laravel');
    firebase.hints.add(null);
    await pumpEventQueue();
    expect(provider.flixQuestLogo, 'Operator chose Laravel');
    expect(adapter.requests.length, 2);
    expect(firebase.fetches, 1);
  });

  test(
      'concurrent boot and resumes coalesce; a config hint schedules revalidation',
      () async {
    respond('laravel');
    await Future.wait(
        [controller.boot(), controller.onResume(), controller.onResume()]);
    expect(adapter.requests.length, 1);
    respond('laravel');
    respond('firebase');
    await Future.wait([
      controller.onResume(),
      controller.onPushData({'refresh_config': '1'})
    ]);
    expect(adapter.requests.length, 3);
    expect(provider.flixQuestLogo, 'Firebase');
    await controller.onPushData({'type': 'announcement'});
    expect(adapter.requests.length, 3);
  });

  test('disposal prevents late Firebase updates and all subsequent refreshes',
      () async {
    final pending = Completer<BootstrapConfig?>();
    firebase.pending = pending.future;
    respond('firebase');
    final refresh = controller.boot();
    await pumpEventQueue();
    controller.dispose();
    pending.complete(firebase.payload);
    await refresh;
    await controller.onResume();
    await controller.onPushData({'type': 'config_updated'});
    expect(provider.flixQuestLogo, 'default');
    expect(store.getJson('config.firebase.snapshot'), isNull);
    expect(adapter.requests.length, 1);
  });

  test(
      'published Firebase flat values match the Laravel theme and settings contract',
      () {
    final data = (jsonDecode(File('test/support/fixtures/bootstrap_config.json')
            .readAsStringSync()) as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
    final expected =
        BootstrapConfig.fromJson(data).copyWith(configSource: 'firebase');
    final flat = <String, dynamic>{
      for (final name in ['features', 'branding', 'updates', 'network', 'ads'])
        ...Map<String, dynamic>.from(data[name] as Map),
      'banners': data['banners'],
      'occasional_theme': data['occasional_theme'],
    };
    final published = {
      for (final entry in flat.entries)
        entry.key: entry.value is Map || entry.value is List
            ? jsonEncode(entry.value)
            : entry.value.toString(),
    };
    expect(firebaseConfigSnapshot(published), expected);
  });

  test(
      'Firebase retains enable_ott fallback and safe defaults for unpublished keys',
      () {
    final config = firebaseConfigSnapshot(
        {'enable_ott': 'false', 'cinemax_logo': 'Legacy logo'});
    expect(config.features.enableLiveTv, isFalse);
    expect(config.features.enableStream, isTrue);
    expect(config.branding.cinemaxLogo, 'Legacy logo');
    expect(config.ads.startioBannerEnabled, isFalse);
    expect(config.ads.unityGameIdAndroid, '5445375');
    expect(
        firebaseConfigSnapshot(
                {'enable_live_tv': 'true', 'enable_ott': 'false'})
            .features
            .enableLiveTv,
        isTrue);
  });

  test(
      'switching snapshots replaces network and phone/TV banners while preserving user theme preferences',
      () async {
    final theme = {
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
      ],
    };
    firebase.payload = firebaseConfigSnapshot({
      'occasional_theme': jsonEncode(theme),
      'tmdb_api_key': 'Firebase key',
      'tmdb_proxy': 'https://firebase-proxy.test',
      'flixquest_api_instances':
          '{"instances":["https://firebase-scraper.test"]}',
      'banners':
          '{"banners":[{"hosted":{"enabled":false,"placements":["home","home_tv"]}}]}',
      'hosted_banner_mode': 'off',
    });
    respond('firebase');
    await controller.boot();
    provider.selectOccasionalTheme('christmas');
    provider.occasionalEffectsEnabled = false;
    expect(provider.activeOccasionalTheme?.id, 'christmas');
    expect(TMDB_API_KEY, 'Firebase key');
    expect(provider.tmdbProxy, 'https://firebase-proxy.test');
    expect(provider.flixquestAPIInstances, ['https://firebase-scraper.test']);
    adapter.enqueueJson({
      'success': true,
      'data': {'config_source': 'laravel', 'occasional_theme': theme}
    });
    await controller.onResume();
    expect(TMDB_API_KEY, 'test');
    expect(provider.tmdbProxy, '');
    expect(provider.flixquestAPIInstances, isEmpty);
    expect(provider.selectedOccasionalThemeId, 'christmas');
    expect(provider.activeOccasionalTheme?.id, 'christmas');
    expect(provider.shouldShowOccasionalEffects, isFalse);
    expect(provider.bannerConfigFor('hosted').enabled, isTrue);
    respond('firebase');
    await controller.onResume();
    expect(provider.bannerConfigFor('hosted').enabled, isFalse);
    expect(provider.bannerConfigFor('hosted').placements, ['home', 'home_tv']);
    expect(provider.activeOccasionalTheme?.id, 'christmas');
    expect(provider.shouldShowOccasionalEffects, isFalse);
  });

  test(
      'unavailable Firebase settings retain its matching cache instead of applying Laravel fields',
      () async {
    respond('firebase');
    await controller.boot();
    firebase.payload = null;
    respond('firebase', logo: 'Wrong provider');
    await controller.onResume();
    expect(provider.flixQuestLogo, 'Firebase');
    expect(provider.displayWatchNowButton, isTrue);
  });

  test('a successful empty Firebase template applies bundled defaults',
      () async {
    final sdk = FakeRemoteConfigSdk();
    final source = SdkFirebaseConfigSource(remote: sdk);
    expect(await source.refresh(),
        const BootstrapConfig(configSource: 'firebase'));
  });

  test('offline Firebase uses activated SDK values and ignores SDK defaults',
      () async {
    final sdk = FakeRemoteConfigSdk()..offline = true;
    final source = SdkFirebaseConfigSource(remote: sdk);
    expect(await source.refresh(), isNull);
    sdk.values['enable_live_tv'] = RemoteConfigValue(
        Uint8List.fromList(utf8.encode('true')), ValueSource.valueDefault);
    sdk.values['enable_ott'] = RemoteConfigValue(
        Uint8List.fromList(utf8.encode('false')), ValueSource.valueRemote);
    final config = await source.refresh();
    expect(config?.features.enableLiveTv, isFalse);
    expect(config?.features.enableStream, isTrue);
    sdk.values['occasional_theme'] = RemoteConfigValue(
        Uint8List.fromList(utf8.encode('malformed')), ValueSource.valueRemote);
    expect(await source.refresh(), isNull);
  });
  test('an unavailable theme choice survives source changes and a cold restart',
      () async {
    firebase.payload = firebaseConfigSnapshot({
      'occasional_theme': jsonEncode({
        'enabled': true,
        'allow_user_selection': true,
        'themes': [
          {'id': 'christmas', 'enabled': true}
        ],
      }),
    });
    respond('firebase');
    await controller.boot();
    provider.selectOccasionalTheme('christmas');
    provider.occasionalEffectsEnabled = false;
    respond('laravel');
    await controller.onResume();
    expect(provider.selectedOccasionalThemeId, 'christmas');
    expect(provider.activeOccasionalTheme, isNull);
    expect(
        sharedPrefsSingleton
            .getString(AppDependencies.OCCASIONAL_THEME_SELECTION),
        'christmas');
    controller.dispose();
    provider.dispose();
    provider = AppDependencyProvider();
    await provider.getOccasionalTheme(preserveSelection: true);
    repository = ConfigRepository(dio, KvStore(sharedPrefsSingleton));
    controller = createController();
    await controller.hydrate();
    respond('firebase');
    await controller.onResume();
    expect(provider.activeOccasionalTheme?.id, 'christmas');
    expect(provider.occasionalEffectsEnabled, isFalse);
  });
}
