import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/mobile/app/mobile_update_gate.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/update_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/tv_localization.dart';

void main() {
  setUp(() {
    TMDB_API_KEY = 'test';
  });
  initializeTvTranslations();
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDependencyProvider config;

  void release({bool forced = false, int build = 2}) {
    config.setUpdateConfiguration(
        forced: forced,
        latestVersion: '4.$build.0',
        latestBuild: build,
        minimumBuild: 0,
        downloadUrl: 'https://example.com/mobile-update-test.apk',
        changeLog: 'Fixes');
  }

  setUpAll(() {});
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
    PackageInfo.setMockInitialValues(
        appName: 'FlixQuest',
        packageName: 'com.test.fq',
        version: '4.0.0',
        buildNumber: '1',
        buildSignature: '');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/tmp/flixquest-mobile-update-tests');
    config = AppDependencyProvider();
    release();
  });

  testWidgets(
      'a mandatory update learned mid-session covers an open page, '
      'and Back cannot reveal it', (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppDependencyProvider>.value(value: config),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        builder: (_, navigator) => MobileUpdateGate(child: navigator!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Player')))),
              child: const Text('Watch'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch'));
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsOneWidget);

    // As when a session that started offline finally fetches the config.
    release(forced: true);
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsNothing);
    expect(find.byType(UpdateScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsNothing);
    expect(find.text('You must update the app inorder to continue using it'),
        findsOneWidget);

    // Installed build already current: the app comes back.
    release(forced: true, build: 1);
    await tester.pumpAndSettle();
    expect(find.text('Watch'), findsOneWidget);
    expect(find.byType(UpdateScreen), findsNothing);
  });
}
