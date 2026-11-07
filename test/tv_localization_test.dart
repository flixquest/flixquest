import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/screens/tv_settings_screen.dart';
import 'package:flixquest/tv/widgets/tv_dialog.dart';
import 'package:flixquest/tv/widgets/tv_list_row.dart';
import 'package:flixquest/tv/widgets/tv_search_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileLoader extends AssetLoader {
  const _FileLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

const _locales = [
  Locale('en'),
  Locale('ar'),
  Locale('es'),
  Locale('hi'),
  Locale('it'),
  Locale('fr'),
];

Future<void> _pumpLocalized(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(EasyLocalization(
    supportedLocales: _locales,
    startLocale: _locales.first,
    fallbackLocale: _locales.first,
    saveLocale: false,
    path: 'assets/translations',
    assetLoader: const _FileLoader(),
    child: Builder(builder: (context) {
      return MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: Scaffold(body: child),
      );
    }),
  ));
  await tester.pumpAndSettle();
}

Future<void> _setLocale(
    WidgetTester tester, Finder content, Locale locale) async {
  await tester.element(content).setLocale(locale);
  await tester.pumpAndSettle();
}

Widget _settingsWidget(SettingsProvider settings,
        {TvScreenFocusController? focusController}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
      ],
      child: TvSettingsScreen(
        metrics: TvShellMetrics.fromConstraints(
            const BoxConstraints.tightFor(width: 960, height: 540)),
        focusController: focusController,
      ),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  testWidgets('TV settings update in every locale and preserve saved values',
      (tester) async {
    final settings = SettingsProvider();
    final screen = find.byType(TvSettingsScreen);
    await _pumpLocalized(tester, _settingsWidget(settings));

    for (final locale in _locales) {
      await _setLocale(tester, screen, locale);
      final context = tester.element(screen);
      for (final key in [
        'settings',
        'tv_appearance',
        'tv_content_sources',
        'tv_storage',
      ]) {
        expect(find.text(tr(key)), findsOneWidget, reason: '$locale: $key');
      }
      expect(Directionality.of(context),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(tester.takeException(), isNull, reason: locale.toString());
    }

    await _setLocale(tester, screen, const Locale('es'));
    final themeLabel = tr('theme_mode');
    await tester.ensureVisible(find.text(themeLabel));
    await tester.tap(find.text(themeLabel));
    await tester.pumpAndSettle();
    // Select a translated option with the remote; storage keeps its stable ID.
    final light = tr('ins_theme_light');
    await tester.tap(find.text(light));
    await tester.pumpAndSettle();
    expect(settings.appTheme, 'light');
    expect(
        sharedPrefsSingleton.getString(SettingsPreferences.THEME_MODE_STATUS),
        'light');
    expect(find.text(light), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV remote changes and saves app language and restores focus',
      (tester) async {
    final settings = SettingsProvider();
    final screen = find.byType(TvSettingsScreen);
    final focusController = TvScreenFocusController()..requestFocus();
    await _pumpLocalized(
        tester, _settingsWidget(settings, focusController: focusController));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final languageFocus = FocusManager.instance.primaryFocus;
    expect(languageFocus?.debugLabel, 'App language, English');

    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await press(LogicalKeyboardKey.select);
    await press(LogicalKeyboardKey.escape);
    expect(settings.appLanguage, 'en');
    expect(
        sharedPrefsSingleton.getString(SettingsPreferences.APP_LANGUAGE_CODE),
        isNull);
    expect(FocusManager.instance.primaryFocus, same(languageFocus));

    const codes = ['en', 'ar', 'es', 'hi', 'it', 'fr'];
    for (final target in ['es', 'ar', 'hi', 'fr', 'it', 'en']) {
      final previous = settings.appLanguage;
      await press(LogicalKeyboardKey.select);
      final rows = tester.widgetList<TvListRow>(find.descendant(
        of: find.byType(TvDialog),
        matching: find.byType(TvListRow),
      ));
      expect(rows.map((row) => row.key),
          codes.map((code) => ValueKey<String>('app-language-$code')));
      expect(rows.where((row) => row.autofocus).single.key,
          ValueKey<String>('app-language-$previous'));
      final steps = codes.indexOf(target) - codes.indexOf(previous);
      for (var step = 0; step < steps.abs(); step++) {
        await press(steps > 0
            ? LogicalKeyboardKey.arrowDown
            : LogicalKeyboardKey.arrowUp);
      }
      await press(LogicalKeyboardKey.select);
      expect(find.byType(TvDialog), findsNothing);
      expect(settings.appLanguage, target);
      expect(
          sharedPrefsSingleton.getString(SettingsPreferences.APP_LANGUAGE_CODE),
          target);
      final context = tester.element(screen);
      expect(context.locale, Locale(target));
      expect(find.text(tr('settings')), findsOneWidget);
      expect(Directionality.of(context),
          target == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(FocusManager.instance.primaryFocus, same(languageFocus));
      expect(tester.takeException(), isNull);
      final reloaded = SettingsProvider();
      await reloaded.getAppLanguage();
      expect(reloaded.appLanguage, target);
      reloaded.dispose();
    }
  });

  testWidgets('translated keyboard actions keep their input behavior',
      (tester) async {
    var input = '';
    final keyboard = find.byType(TvSearchKeyboard);
    await _pumpLocalized(
      tester,
      Center(
        child: TvSearchKeyboard(
          onType: (value) => input += value,
          onDelete: () => input = input.substring(0, input.length - 1),
          onClear: () => input = '',
        ),
      ),
    );
    for (final locale in _locales) {
      await _setLocale(tester, keyboard, locale);
      await tester.tap(find.text('a'));
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == tr('tv_space')));
      expect(input, 'a ');
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == tr('tv_delete')));
      expect(input, 'a');
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == tr('clear')));
      expect(input, isEmpty);
      expect(tester.takeException(), isNull);
    }
    // Keyboard character IDs still support remote activation after translating.
    final state = tester.state<TvSearchKeyboardState>(keyboard);
    input = 'abc';
    state.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(input, 'abca');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
