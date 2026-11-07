import 'package:flixquest/constants/api_constants.dart';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/app_mode.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/settings.dart';
import 'package:flixquest/services/tmdb_connectivity.dart';
import 'package:flixquest/mobile/widgets/settings_kit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
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

Future<void> _pumpSettings(
    WidgetTester tester, SettingsProvider settings) async {
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
}

void main() {
  setUp(() {
    TMDB_API_KEY = 'test';
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  testWidgets('mobile settings save TV, Mobile, and Automatic choices',
      (tester) async {
    final settings = SettingsProvider();
    await _pumpSettings(tester, settings);

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

  testWidgets(
      'mobile proxy control only turns an automatically detected proxy off',
      (tester) async {
    final original = TmdbConnectivity.instance;
    final client = MockClient((request) async =>
        request.url.host == 'proxy.example'
            ? http.Response('{"images": {}}', 200)
            : http.Response('<html>Blocked</html>', 451));
    final connectivity =
        TmdbConnectivity(client: client, hasNetwork: () async => true);
    TmdbConnectivity.instance = connectivity;
    final settings = SettingsProvider();
    addTearDown(() {
      settings.dispose();
      connectivity.dispose();
      TmdbConnectivity.instance = original;
      client.close();
    });
    await _pumpSettings(tester, settings);
    Finder proxyRow() => find.byWidgetPredicate((widget) =>
        widget is SwitchRow && widget.label == 'Use proxy for TMDB fetch');
    var row = tester.widget<SwitchRow>(proxyRow());
    expect(row.value, isFalse);
    expect(row.onChanged, isNull);

    await connectivity.check('https://proxy.example');
    await tester.pumpAndSettle();
    row = tester.widget<SwitchRow>(proxyRow());
    expect(row.value, isTrue);
    expect(row.onChanged, isNotNull);
    await tester.ensureVisible(proxyRow());
    await tester
        .tap(find.descendant(of: proxyRow(), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    row = tester.widget<SwitchRow>(proxyRow());
    expect(settings.enableProxy, isFalse);
    expect(row.onChanged, isNull);
    await connectivity.check('https://proxy.example', networkChanged: true);
    expect(settings.enableProxy, isFalse);
    expect(tester.takeException(), isNull);
  });
}
