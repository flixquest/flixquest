import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/app_mode.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
    dotenv.testLoad(fileInput: '''
      TMDB_API_KEY=test
      MIXPANEL_API_KEY=test
      FLIXQUEST_API_URL=https://example.com
    ''');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  testWidgets('mobile settings save TV, Mobile, and Automatic choices',
      (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ],
        child: EasyLocalization(
          supportedLocales: const <Locale>[Locale('en')],
          path: 'assets/translations',
          assetLoader: const _Translations(),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const Settings(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final entry in <AppMode, String>{
      AppMode.television: 'TV',
      AppMode.mobile: 'Mobile',
      AppMode.automatic: 'Automatic',
    }.entries) {
      await tester.tap(find.text('App mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.value).hitTestable().last);
      await tester.pumpAndSettle();
      expect(settings.appMode, entry.key);
      expect(sharedPrefsSingleton.getString(SettingsPreferences.APP_MODE),
          entry.key.id);
    }
    expect(tester.takeException(), isNull);
  });
}
