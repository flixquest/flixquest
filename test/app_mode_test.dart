import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/app_mode.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/platform/device_presentation.dart';
import 'package:flixquest/tv/platform/device_presentation_detector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  test('new installs keep automatic device detection', () async {
    final settings = SettingsProvider();
    await settings.getCurrentAppMode();

    expect(settings.appMode, AppMode.automatic);
    for (final device in DevicePresentation.values) {
      expect(settings.appMode.resolve(device), device);
    }
    expect(
        sharedPrefsSingleton.containsKey(SettingsPreferences.APP_MODE), false);
  });

  test('manual modes override both OS presentations', () {
    for (final device in DevicePresentation.values) {
      expect(AppMode.television.resolve(device), DevicePresentation.television);
      expect(AppMode.mobile.resolve(device), DevicePresentation.handheld);
    }
  });

  test('saved choices survive provider recreation and can return to automatic',
      () async {
    final settings = SettingsProvider();
    var notifications = 0;
    settings.addListener(() => notifications++);

    for (final mode in <AppMode>[
      AppMode.television,
      AppMode.mobile,
      AppMode.automatic,
    ]) {
      settings.appMode = mode;
      expect(sharedPrefsSingleton.getString(SettingsPreferences.APP_MODE),
          mode.id);
      final relaunched = SettingsProvider();
      await relaunched.getCurrentAppMode();
      expect(relaunched.appMode, mode);
    }
    expect(notifications, 3);
  });

  test('an unrecognized saved mode falls back to automatic', () async {
    await sharedPrefsSingleton.setString(
        SettingsPreferences.APP_MODE, 'unknown');
    final settings = SettingsProvider();
    await settings.getCurrentAppMode();
    expect(settings.appMode, AppMode.automatic);
  });

  test('automatic still uses the native detector and its mobile fallback',
      () async {
    const channel = MethodChannel('test/device_presentation');
    const detector = MethodChannelDevicePresentationDetector(
      channel: channel,
      platformOverride: TargetPlatform.android,
      isWebOverride: false,
      forceTvMode: false,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    for (final isTv in <bool>[false, true]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'isTelevision');
        return isTv;
      });
      expect(
        AppMode.automatic
            .resolve(await resolveDevicePresentation(detector: detector)),
        isTv ? DevicePresentation.television : DevicePresentation.handheld,
      );
    }

    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await detector.detect(), DevicePresentation.handheld);
  });
}
