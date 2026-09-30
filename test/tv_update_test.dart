import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/screens/common/update_screen.dart';
import 'package:flixquest/tv/widgets/tv_update_gate.dart';
import 'package:flixquest/tv/widgets/tv_update_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_download_manager/flutter_download_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDependencyProvider config;
  const url = 'https://example.com/tv-update-test.apk';
  const directory = '/tmp/flixquest-tv-update-tests';

  void release({bool forced = false, int build = 2, String link = url}) {
    config.setUpdateConfiguration(
        forced: forced,
        latestVersion: '4.$build.0',
        latestBuild: build,
        minimumBuild: 0,
        downloadUrl: link,
        changeLog: 'Better TV navigation\nMore reliable playback');
  }

  Widget app(Widget child, {bool gate = false}) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AppDependencyProvider>.value(value: config),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
              theme: ThemeData.dark(),
              home: child,
              builder: (_, navigator) =>
                  gate ? TvUpdateGate(child: navigator!) : navigator!));

  Future<void> select(WidgetTester tester, String label) async {
    Focus.of(tester.element(find.text(label).last)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
  }

  setUpAll(() {
    dotenv.testLoad(
        fileInput:
            'TMDB_API_KEY=test\nMIXPANEL_API_KEY=test\nFLIXQUEST_API_URL=https://example.com');
  });
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
            (_) async => directory);
    config = AppDependencyProvider();
    release();
    // Keep transfers queued: tests exercise the real manager's state transitions
    // without downloading or launching an Android installer on the host.
    DownloadManager(maxConcurrentTasks: 0);
  });
  tearDown(() async {
    final manager = DownloadManager();
    if (manager.getDownload(url) != null) await manager.removeDownload(url);
    manager.maxConcurrentTasks = 2;
  });

  testWidgets('TV notice cannot be dismissed and opens the TV updater',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(const Scaffold(
        body: Column(children: [
      UpdateBottom(television: true),
      Text('TV home'),
    ]))));
    await tester.pumpAndSettle();
    expect(find.text('Update available • FlixQuest 4.2.0'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
    await select(tester, 'Update');
    expect(tester.widget<UpdateScreen>(find.byType(UpdateScreen)).television,
        isTrue);
    expect(find.text('Download update'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(UpdateScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mandatory update covers an open route and Back cannot reveal it',
      (tester) async {
    await sharedPrefsSingleton.setString('ignore_version', '2');
    await tester.pumpWidget(app(
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                const Scaffold(body: Text('Player')))),
                    child: const Text('Watch')))),
        gate: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch'));
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsOneWidget);
    release(forced: true);
    await tester.pumpAndSettle();
    expect(find.text('Watch'), findsNothing);
    expect(find.text('Player'), findsNothing);
    expect(find.text('Update required'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Return to update'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Watch'), findsNothing);
    expect(find.text('Download update'), findsOneWidget);
    release(forced: true, build: 1);
    await tester.pumpAndSettle();
    expect(find.text('Watch'), findsOneWidget);
    expect(find.byType(UpdateScreen), findsNothing);
  });

  testWidgets('TV changelog is remote navigable and returns to update',
      (tester) async {
    await tester
        .pumpWidget(app(const UpdateScreen(isForced: true, television: true)));
    await tester.pumpAndSettle();
    await select(tester, 'What’s new');
    expect(find.text('Better TV navigation\nMore reliable playback'),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(TvChangelogView),
            matching: find.byType(TvUpdateAction)),
        findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Release notes');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Download update'), findsOneWidget);
  });

  testWidgets('long release notes scroll as plain text using the remote',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(TvChangelogView(
        changeLog: List.generate(
                50, (i) => 'Improvement $i: better playback and TV browsing.')
            .join('\n'))));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV download supports pause, resume, failure retry and delete',
      (tester) async {
    final manager = DownloadManager();
    await tester.runAsync(
        () => manager.addDownload(url, '$directory/tv-update-test.apk'));
    await tester
        .pumpWidget(app(const UpdateScreen(isForced: false, television: true)));
    await tester.pumpAndSettle();
    await select(tester, 'Pause');
    expect(manager.getDownload(url)!.status.value, DownloadStatus.paused);
    await select(tester, 'Resume');
    expect(manager.getDownload(url)!.status.value, DownloadStatus.downloading);
    manager.getDownload(url)!.status.value = DownloadStatus.failed;
    await tester.pumpAndSettle();
    expect(find.text('Retry download'), findsOneWidget);
    await tester.runAsync(() async {
      final previous = manager.getDownload(url);
      await tester.tap(find.text('Retry download'));
      for (var i = 0;
          i < 100 && identical(previous, manager.getDownload(url));
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(manager.getDownload(url)!.status.value, DownloadStatus.queued);
    manager.getDownload(url)!.status.value = DownloadStatus.completed;
    manager.getDownload(url)!.progress.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('Install'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Delete download'));
      for (var i = 0; i < 100 && manager.getDownload(url) != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Download update'), findsOneWidget);
    expect(manager.getDownload(url), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'TV update preparation failure offers retry without bypassing force',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => throw PlatformException(code: 'unavailable'));
    await tester
        .pumpWidget(app(const UpdateScreen(isForced: true, television: true)));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Download update'), findsNothing);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory);
    await select(tester, 'Retry');
    expect(find.text('Download update'), findsOneWidget);
    expect(find.text('Update required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing download link retains a usable forced screen',
      (tester) async {
    release(forced: true, link: '');
    await tester
        .pumpWidget(app(const UpdateScreen(isForced: true, television: true)));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('download link is not available'), findsOneWidget);
    expect(find.text('Exit app'), findsOneWidget);
    expect(find.text('Download update'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
