import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/tv/app/tv_design.dart';
import 'package:flixquest/tv/focus/tv_focus_memory.dart';
import 'package:flixquest/tv/focus/tv_screen_focus_controller.dart';
import 'package:flixquest/tv/screens/tv_settings_screen.dart';
import 'package:flixquest/tv/widgets/tv_content_grid.dart';
import 'package:flixquest/tv/widgets/tv_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const metrics = TvShellMetrics(
    compact: true,
    safeInset: 22,
    railWidth: 88,
    railGap: 22,
    contentPadding: 18,
    navItemHeight: 46,
    navItemGap: 3,
    mediaCardWidth: 220,
  );

  setUpAll(() {
    dotenv.testLoad(
      fileInput: '''
        TMDB_API_KEY=test
        MIXPANEL_API_KEY=test
        FLIXQUEST_API_URL=https://example.com
      ''',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  testWidgets('content grid enters predictably and contains edge navigation',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TvContentGridController()..requestFocus();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 620,
              height: 500,
              child: TvFocusMemoryScope(
                memory: TvFocusMemory(),
                child: TvContentGrid<int>(
                  controller: controller,
                  scopeId: 'test-grid',
                  items: List<int>.generate(5, (index) => index),
                  itemId: (item) => '$item',
                  semanticLabel: (item) => 'Item $item',
                  targetItemWidth: 250,
                  itemBuilder: (_, item, width) => SizedBox(
                    width: width,
                    child: Text('Item $item'),
                  ),
                  onItemActivated: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'test-grid:0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'test-grid:1');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'test-grid:1');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'test-grid:3');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'test-grid:3');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'channel grid keeps a complete card visible and distinguishes held OK',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var plays = 0;
    var menus = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
      child: SizedBox(
          width: 700,
          height: 300,
          child: TvContentGrid<int>(
            scopeId: 'channels',
            items: List.generate(30, (i) => i),
            itemId: (i) => '$i',
            semanticLabel: (i) => 'Channel $i',
            targetItemWidth: 210,
            horizontalSpacing: 12,
            itemExtent: 126,
            autofocus: true,
            itemBuilder: (_, i, width) =>
                SizedBox(width: width, child: Text('Channel $i')),
            onItemActivated: (_) => plays++,
            onItemMenu: (_) => menus++,
          )),
    ))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(plays, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(menus, 1);
    expect(plays, 1);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final focused = FocusManager.instance.primaryFocus!;
    expect(focused.debugLabel, 'channels:18');
    final bounds = (focused.context!.findRenderObject() as RenderBox);
    final top = bounds.localToGlobal(Offset.zero).dy;
    expect(top, greaterThanOrEqualTo(120));
    expect(top + bounds.size.height, lessThanOrEqualTo(420));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings entry and dialog back restore the originating tile',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final focusController = TvScreenFocusController()..requestFocus();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TvSettingsScreen(
              metrics: metrics,
              focusController: focusController,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV setting theme mode',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Choose how FlixQuest looks on this TV.'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Choose how FlixQuest looks on this TV.'), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV setting theme mode',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('subtitle settings are D-pad navigable and persist choices',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsProvider();
    final focusController = TvScreenFocusController()..requestFocus();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TvSettingsScreen(
              metrics: metrics,
              focusController: focusController,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (var index = 0; index < 6; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Subtitle settings, 17px, Regular, White',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Subtitle settings'), findsNWidgets(2));
    expect(find.text('Font size'), findsOneWidget);
    final dialogBounds = tester.getRect(find.byType(TvDialog));
    for (final label in [
      'Font size',
      '17px',
      'Background color',
      'Black 45%'
    ]) {
      final bounds = tester.getRect(find.text(label));
      expect(bounds.left, greaterThan(dialogBounds.left));
      expect(bounds.right, lessThan(dialogBounds.right));
    }

    expect(find.text('Text color'), findsOneWidget);
    expect(find.text('Background color'), findsOneWidget);
    expect(find.text('Text weight'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Font size, 17px',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Subtitle font size'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '17px');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, '20px');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(settings.subtitleFontSize, 20);
    expect(find.text('Subtitle font size'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Subtitle settings'), findsOneWidget);
    expect(find.text('20px, Regular, White'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Subtitle settings, 17px, Regular, White',
    );
    expect(tester.takeException(), isNull);
  });
}
