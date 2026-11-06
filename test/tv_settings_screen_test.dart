import 'dart:async';
import 'dart:io';

import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/functions/player_buffering_configuration.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/services/tmdb_connectivity.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/screens/tv_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/tv_localization.dart';

class _CachePaths extends PathProviderPlatform {
  _CachePaths({required this.cache, required this.temp});

  final Future<String?> Function() cache;
  final String temp;
  int cacheRequests = 0;

  @override
  Future<String?> getApplicationCachePath() {
    cacheRequests++;
    return cache();
  }

  @override
  Future<String?> getTemporaryPath() async => temp;
}

Future<void> _pumpSettings(
    WidgetTester tester, SettingsProvider settings) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TvSettingsScreen(
            metrics: TvShellMetrics.fromConstraints(
              const BoxConstraints.tightFor(width: 960, height: 540),
            ),
            focusController: TvScreenFocusController()..requestFocus(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _focusLabel(WidgetTester tester, String label,
    {LogicalKeyboardKey direction = LogicalKeyboardKey.arrowDown}) async {
  for (var step = 0; step < 45; step++) {
    final focused = FocusManager.instance.primaryFocus?.debugLabel ?? '';
    if (focused == label || focused.startsWith('$label,')) return;
    await tester.sendKeyEvent(direction);
    await tester.pumpAndSettle();
  }
  fail('Could not focus $label; focused '
      '${FocusManager.instance.primaryFocus?.debugLabel}');
}

Future<void> _select(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pumpAndSettle();
}

void main() {
  initializeTvTranslations();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
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

  testWidgets('TV remote cannot manually enable the TMDB proxy',
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
    await _focusLabel(tester, 'TMDB proxy');
    await _select(tester);
    expect(settings.enableProxy, isFalse);
    expect(find.text('Off · Automatic'), findsOneWidget);
    await connectivity.check('https://proxy.example');
    await tester.pumpAndSettle();
    expect(settings.enableProxy, isTrue);
    expect(find.text('On · Turn off'), findsOneWidget);
    await _select(tester);
    expect(settings.enableProxy, isFalse);
    await _select(tester);
    await connectivity.check('https://proxy.example', networkChanged: true);
    expect(settings.enableProxy, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote choices persist and TV buffer reflects its effective cap',
      (tester) async {
    final settings = SettingsProvider();
    await _pumpSettings(tester, settings);

    final headings = [
      'APPEARANCE',
      'CONTENT & SOURCES',
      'PLAYBACK',
      'SUBTITLES',
      'STORAGE',
      'ABOUT FLIXQUEST',
    ];
    for (var index = 1; index < headings.length; index++) {
      expect(tester.getTopLeft(find.text(headings[index])).dy,
          greaterThan(tester.getTopLeft(find.text(headings[index - 1])).dy));
    }

    await _focusLabel(tester, 'Default video resolution');
    await _select(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Auto');
    for (var step = 0; step < 3; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    await _select(tester);
    expect(settings.defaultVideoResolution, 720);
    expect(
        sharedPrefsSingleton.getInt(SettingsPreferences.DEFAULT_VIDEO_QUALITY),
        720);
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        startsWith('Default video resolution,'));

    await _focusLabel(tester, 'Seek interval');
    await _select(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '10s');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _select(tester);
    expect(settings.defaultSeekDuration, 15);
    expect(
        sharedPrefsSingleton.getInt(SettingsPreferences.SEEK_PREFERENCE), 15);

    await _focusLabel(tester, 'Buffer duration');
    expect(find.text('60s'), findsOneWidget);
    await _select(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '60s');
    expect(find.text('90s'), findsNothing);
    expect(find.text('120s'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(settings.defaultMaxBufferDuration, 120000);
    expect(
        sharedPrefsSingleton.getInt(SettingsPreferences.MAX_BUFFER_PREFERENCE),
        isNull);
    await _select(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _select(tester);
    expect(settings.defaultMaxBufferDuration, 45000);
    expect(
        sharedPrefsSingleton.getInt(SettingsPreferences.MAX_BUFFER_PREFERENCE),
        45000);
    expect(
        buildPlayerBufferingConfiguration(
          maximumDurationMs: settings.defaultMaxBufferDuration,
          television: true,
        ).maxBufferMs,
        45000);

    await _focusLabel(tester, 'Show next episode');
    await _select(tester);
    expect(settings.enableNextEpisodeButton, isTrue);
    expect(
        sharedPrefsSingleton
            .getBool(SettingsPreferences.ENABLE_NEXT_EPISODE_BUTTON),
        isTrue);
    await _select(tester);
    expect(settings.enableNextEpisodeButton, isFalse);

    await _focusLabel(tester, 'Show IntroDB skip buttons');
    await _select(tester);
    expect(settings.enableIntroDbSkipButtons, isFalse);
    expect(
        sharedPrefsSingleton
            .getBool(SettingsPreferences.ENABLE_INTRODB_SKIP_BUTTONS),
        isFalse);
    await _select(tester);
    expect(settings.enableIntroDbSkipButtons, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'subtitle languages scroll with the remote and reopen on selection',
      (tester) async {
    final settings = SettingsProvider();
    await _pumpSettings(tester, settings);
    await _focusLabel(tester, 'Default subtitle language');
    await _select(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'English, Selected');
    await _focusLabel(tester, 'Spanish');
    final spanish = tester.getRect(find.text('Spanish'));
    expect(spanish.top, greaterThan(28));
    expect(spanish.bottom, lessThan(512));
    await _select(tester);
    expect(settings.defaultSubtitleLanguage, 'es');
    expect(sharedPrefsSingleton.getString(SettingsPreferences.DEFAULT_SUBTITLE),
        'es');
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        startsWith('Default subtitle language,'));

    await _select(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Spanish, Selected');
    await _focusLabel(tester, 'Ukrainian');
    await _select(tester);
    expect(settings.defaultSubtitleLanguage, 'uk');
    await _select(tester);
    await _focusLabel(tester, 'Any', direction: LogicalKeyboardKey.arrowUp);
    await _select(tester);
    expect(settings.defaultSubtitleLanguage, '');
    expect(sharedPrefsSingleton.getString(SettingsPreferences.DEFAULT_SUBTITLE),
        '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the remote switches the player time display and keeps the choice',
      (tester) async {
    final settings = SettingsProvider();
    await _pumpSettings(tester, settings);

    await _focusLabel(tester, 'Player time display');
    expect(find.text('Elapsed / Remaining'), findsOneWidget);

    await _select(tester);
    expect(settings.playerTimeDisplay, 2);
    expect(
        sharedPrefsSingleton.getInt(SettingsPreferences.PLAYER_STYLE_INDEX), 2);
    expect(find.text('Elapsed / Total'), findsOneWidget);
    expect(find.text('Elapsed / Remaining'), findsNothing);

    await _select(tester);
    expect(settings.playerTimeDisplay, 1);
    expect(
        sharedPrefsSingleton.getInt(SettingsPreferences.PLAYER_STYLE_INDEX), 1);
    expect(find.text('Elapsed / Remaining'), findsOneWidget);
  });

  testWidgets('clear cache removes both directories and ignores repeat presses',
      (tester) async {
    final root = Directory.systemTemp.createTempSync('flixquest-tv-cache-');
    addTearDown(() => root.deleteSync(recursive: true));
    final cache = Directory('${root.path}/cache')..createSync();
    final temp = Directory('${root.path}/temp')..createSync();
    File('${cache.path}/image').writeAsStringSync('cache');
    File('${temp.path}/subtitle').writeAsStringSync('temporary');
    final path = Completer<String?>();
    final platform = _CachePaths(cache: () => path.future, temp: temp.path);
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = platform;
    addTearDown(() => PathProviderPlatform.instance = original);

    final settings = SettingsProvider()..defaultSubtitleLanguage = 'es';
    await _pumpSettings(tester, settings);
    await _focusLabel(tester, 'Clear cache');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text('Clearing…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(platform.cacheRequests, 1);
    path.complete(cache.path);
    await tester.pumpAndSettle();
    expect(cache.existsSync(), isFalse);
    expect(temp.existsSync(), isFalse);
    expect(find.text('Cache cleared'), findsOneWidget);
    expect(sharedPrefsSingleton.getString(SettingsPreferences.DEFAULT_SUBTITLE),
        'es');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        startsWith('Clear cache,'));
    await _select(tester);
    expect(find.text('No cache to clear'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cache failure still clears temporary files and reports failure',
      (tester) async {
    final root = Directory.systemTemp.createTempSync('flixquest-tv-cache-');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    File('${root.path}/subtitle').writeAsStringSync('temporary');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _CachePaths(
      cache: () async => throw const FileSystemException('Unavailable'),
      temp: root.path,
    );
    addTearDown(() => PathProviderPlatform.instance = original);
    await _pumpSettings(tester, SettingsProvider());
    await _focusLabel(tester, 'Clear cache');
    await _select(tester);
    expect(root.existsSync(), isFalse);
    expect(find.text('Cache clearing incomplete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
