import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/app_remote_config.dart';
import 'package:flixquest/services/start_io_ads_service.dart';
import 'package:flixquest/singleton/sharedpreferences_singleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixquest/widgets/hosted_ads_banner.dart';
import 'package:flixquest/widgets/start_io_banner_widget.dart';

class FakeFirebaseRemoteConfig implements FirebaseRemoteConfig {
  final Map<String, dynamic> _values = {};
  Map<String, dynamic> defaults = {};

  void setMockString(String key, String value) {
    _values[key] = value;
  }

  void setMockBool(String key, bool value) {
    _values[key] = value;
  }

  void setMockInt(String key, int value) {
    _values[key] = value;
  }

  @override
  String getString(String key) =>
      (_values[key] as String?) ?? (defaults[key] as String?) ?? '';

  @override
  bool getBool(String key) =>
      (_values[key] as bool?) ?? (defaults[key] as bool?) ?? false;

  @override
  int getInt(String key) =>
      (_values[key] as int?) ?? (defaults[key] as int?) ?? 0;

  @override
  RemoteConfigValue getValue(String key) {
    final value = _values[key] ?? defaults[key];
    if (value != null) {
      final source = _values.containsKey(key)
          ? ValueSource.valueRemote
          : ValueSource.valueDefault;
      return RemoteConfigValue(
        utf8.encode(value.toString()),
        source,
      );
    }
    return RemoteConfigValue(
      const [],
      ValueSource.valueDefault,
    );
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    defaults = Map<String, dynamic>.from(defaultParameters);
  }

  @override
  Future<void> setConfigSettings(
      RemoteConfigSettings remoteConfigSettings) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(
      fileInput: '''
TMDB_API_KEY=test_tmdb_key
FLIXQUEST_API_URL=https://test.flixquest.api/
UNITY_GAME_ID_ANDROID=5445375
UNITY_BANNER_PLACEMENT_ID=Banner_Android
UNITY_TEST_MODE=false
''',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.startapp.flutter'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  group('Start.io ads and legacy Remote Config compatibility', () {
    late FakeFirebaseRemoteConfig fakeRemoteConfig;
    late AppDependencyProvider provider;

    setUp(() {
      fakeRemoteConfig = FakeFirebaseRemoteConfig();
      provider = AppDependencyProvider();
    });

    test('registers legacy keys and Start.io format switches', () async {
      await AppRemoteConfig.configure(fakeRemoteConfig);

      expect(fakeRemoteConfig.defaults[AppRemoteConfig.bannerAdNetworkKey],
          'native');
      expect(fakeRemoteConfig.defaults[AppRemoteConfig.unityGameIdAndroidKey],
          '5445375');
      expect(
          fakeRemoteConfig.defaults[AppRemoteConfig.unityBannerPlacementIdKey],
          'Banner_Android');
      expect(
          fakeRemoteConfig.defaults[AppRemoteConfig.unityTestModeKey], false);
      expect(
        fakeRemoteConfig.defaults[AppRemoteConfig.startIoBannerEnabledKey],
        false,
      );
      expect(
        fakeRemoteConfig
            .defaults[AppRemoteConfig.startIoInterstitialEnabledKey],
        false,
      );
    });

    test('Defaults apply native banner network to provider', () async {
      await AppRemoteConfig.configure(fakeRemoteConfig);
      AppRemoteConfig.apply(fakeRemoteConfig, provider);

      expect(provider.bannerAdNetwork, 'native');
      expect(provider.isStartIoBannerActive, isFalse);
      expect(provider.startIoInterstitialEnabled, isFalse);
      expect(provider.unityGameIdAndroid, '5445375');
      expect(provider.unityBannerPlacementId, 'Banner_Android');
      expect(provider.unityTestMode, isFalse);
    });

    test('legacy unity network value selects Start.io', () async {
      await AppRemoteConfig.configure(fakeRemoteConfig);
      fakeRemoteConfig.setMockString(
          AppRemoteConfig.bannerAdNetworkKey, 'unity');
      fakeRemoteConfig.setMockString(
          AppRemoteConfig.unityGameIdAndroidKey, '9999999');
      fakeRemoteConfig.setMockString(
          AppRemoteConfig.unityBannerPlacementIdKey, 'Custom_Banner');
      fakeRemoteConfig.setMockBool(AppRemoteConfig.unityTestModeKey, true);
      fakeRemoteConfig.setMockBool(
          AppRemoteConfig.startIoBannerEnabledKey, true);

      AppRemoteConfig.apply(fakeRemoteConfig, provider);

      expect(provider.bannerAdNetwork, 'unity');
      expect(provider.isStartIoBannerActive, isTrue);
      expect(provider.unityGameIdAndroid, '9999999');
      expect(provider.unityBannerPlacementId, 'Custom_Banner');
      expect(provider.unityTestMode, isTrue);
    });

    test('Remote Config toggles active network to none', () async {
      await AppRemoteConfig.configure(fakeRemoteConfig);
      fakeRemoteConfig.setMockBool(
          AppRemoteConfig.startIoBannerEnabledKey, true);
      fakeRemoteConfig.setMockString(
          AppRemoteConfig.bannerAdNetworkKey, 'none');

      AppRemoteConfig.apply(fakeRemoteConfig, provider);

      expect(provider.bannerAdNetwork, 'none');
      expect(provider.isStartIoBannerActive, isFalse);
    });

    test('Provider notifies listeners on ad network change', () {
      provider.setStartIoAdsConfig(
        bannerEnabled: true,
        interstitialEnabled: false,
      );
      int listenerCalls = 0;
      provider.addListener(() {
        listenerCalls++;
      });

      provider.setBannerAdNetwork('unity');
      expect(listenerCalls, 1);
      expect(provider.isStartIoBannerActive, isTrue);

      // Redundant assignment should not notify
      provider.setBannerAdNetwork('unity');
      expect(listenerCalls, 1);

      provider.setBannerAdNetwork('native');
      expect(listenerCalls, 2);
      expect(provider.isStartIoBannerActive, isTrue);
    });

    test('each Start.io format can be toggled independently', () async {
      await AppRemoteConfig.configure(fakeRemoteConfig);
      fakeRemoteConfig.setMockBool(
        AppRemoteConfig.startIoBannerEnabledKey,
        false,
      );
      fakeRemoteConfig.setMockBool(
        AppRemoteConfig.startIoInterstitialEnabledKey,
        false,
      );

      AppRemoteConfig.apply(fakeRemoteConfig, provider);

      expect(provider.isStartIoBannerActive, isFalse);
      expect(provider.startIoInterstitialEnabled, isFalse);
    });

    test('only remotely enabled Start.io formats become active', () async {
      await AppRemoteConfig.configure(fakeRemoteConfig);
      fakeRemoteConfig.setMockBool(
          AppRemoteConfig.startIoBannerEnabledKey, true);

      AppRemoteConfig.apply(fakeRemoteConfig, provider);

      expect(provider.isStartIoBannerActive, isTrue);
      expect(provider.startIoInterstitialEnabled, isFalse);

      fakeRemoteConfig.setMockBool(
        AppRemoteConfig.startIoInterstitialEnabledKey,
        true,
      );
      fakeRemoteConfig.setMockBool(
          AppRemoteConfig.startIoBannerEnabledKey, false);
      AppRemoteConfig.apply(fakeRemoteConfig, provider);

      expect(provider.isStartIoBannerActive, isFalse);
      expect(provider.startIoInterstitialEnabled, isTrue);
    });

    test('pacing defaults: 10 minute interval, TV video first', () async {
      await AppRemoteConfig.configure(fakeRemoteConfig);
      AppRemoteConfig.apply(fakeRemoteConfig, provider);

      final ads = provider.startIoAds;
      expect(ads.interstitialInterval, const Duration(minutes: 10));
      expect(ads.tvInterstitialMode, StartIoInterstitialMode.video);
      expect(StartIoAdsService.instance.config, ads);
    });

    test('pacing values come from Remote Config, with safe floors', () async {
      await AppRemoteConfig.configure(fakeRemoteConfig);
      fakeRemoteConfig
        ..setMockInt(AppRemoteConfig.startIoInterstitialIntervalKey, 5)
        ..setMockString(
          AppRemoteConfig.startIoTvInterstitialModeKey,
          'automatic',
        );

      AppRemoteConfig.apply(fakeRemoteConfig, provider);

      final ads = provider.startIoAds;
      // A near-zero interval would show an ad on every play.
      expect(ads.interstitialInterval, const Duration(seconds: 60));
      expect(ads.tvInterstitialMode, StartIoInterstitialMode.automatic);
    });
  });

  group('RemoteHostedAdsBanner network toggle widget tests', () {
    late AppDependencyProvider provider;

    setUp(() {
      provider = AppDependencyProvider();
    });

    testWidgets('legacy unity value renders a Start.io banner surface',
        (WidgetTester tester) async {
      provider.setStartIoAdsConfig(
        bannerEnabled: true,
        interstitialEnabled: false,
      );
      provider.setBannerAdNetwork('unity');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppDependencyProvider>.value(
            value: provider,
            child: Scaffold(
              body: RemoteHostedAdsBanner(
                placement: 'test_placement',
                loadAds: () async => [],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('legacy native value renders a Start.io banner surface',
        (WidgetTester tester) async {
      provider.setStartIoAdsConfig(
        bannerEnabled: true,
        interstitialEnabled: false,
      );
      provider.setBannerAdNetwork('native');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppDependencyProvider>.value(
            value: provider,
            child: Scaffold(
              body: RemoteHostedAdsBanner(
                placement: 'test_placement',
                loadAds: () async => [],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(StartIoBannerWidget), findsOneWidget);
    });

    testWidgets('Renders nothing when network is none',
        (WidgetTester tester) async {
      provider.setBannerAdNetwork('none');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppDependencyProvider>.value(
            value: provider,
            child: Scaffold(
              body: RemoteHostedAdsBanner(
                placement: 'test_placement',
                loadAds: () async => [],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(StartIoBannerWidget), findsNothing);
    });

    testWidgets('Renders nothing on Android TV', (WidgetTester tester) async {
      StartIoAdsService.instance.setTelevision(true);
      addTearDown(() => StartIoAdsService.instance.setTelevision(false));
      provider.setStartIoAdsConfig(
        bannerEnabled: true,
        interstitialEnabled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppDependencyProvider>.value(
            value: provider,
            child: Scaffold(
              body: RemoteHostedAdsBanner(
                placement: 'test_placement',
                loadAds: () async => [],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(StartIoBannerWidget), findsNothing);
    });
  });
}
