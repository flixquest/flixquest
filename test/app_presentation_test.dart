import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/app_mode.dart';
import 'package:flixquest/preferences/setting_preferences.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/services/device_presentation_service.dart';
import 'package:flixquest/tv/navigation/tv_back_key_guard.dart';
import 'package:flixquest/tv/platform/device_presentation.dart';
import 'package:flixquest/widgets/app_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  tearDown(() => DevicePresentationService.instance.isTelevision = false);

  Future<GlobalKey<NavigatorState>> pumpApp(
    WidgetTester tester,
    SettingsProvider settings,
    DevicePresentation detected,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      AppPresentation(
        settings: settings,
        detectedPresentation: detected,
        navigatorKey: navigatorKey,
        builder: (context, presentation) {
          final app = MaterialApp(
            navigatorKey: navigatorKey,
            home: Scaffold(
              key: ValueKey<DevicePresentation>(presentation),
              body: Text(presentation == DevicePresentation.television
                  ? 'TV home'
                  : 'Mobile home'),
            ),
          );
          return TvBackKeyGuard(
            enabled: presentation == DevicePresentation.television,
            child: app,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    return navigatorKey;
  }

  for (final detected in DevicePresentation.values) {
    testWidgets('switching from $detected clears old routes and restores Auto',
        (tester) async {
      final settings = SettingsProvider();
      final navigatorKey = await pumpApp(tester, settings, detected);
      final detectedTv = detected == DevicePresentation.television;
      expect(find.text(detectedTv ? 'TV home' : 'Mobile home'), findsOneWidget);

      navigatorKey.currentState!.push<void>(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Old details')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Old details'), findsOneWidget);

      settings.appMode = detectedTv ? AppMode.mobile : AppMode.television;
      await tester.pumpAndSettle();
      expect(find.text('Old details'), findsNothing);
      expect(find.text(detectedTv ? 'Mobile home' : 'TV home'), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), false);
      expect(DevicePresentationService.instance.isTelevision, !detectedTv);
      expect(tester.widget<TvBackKeyGuard>(find.byType(TvBackKeyGuard)).enabled,
          !detectedTv);

      settings.appMode = AppMode.automatic;
      await tester.pumpAndSettle();
      expect(find.text(detectedTv ? 'TV home' : 'Mobile home'), findsOneWidget);
      expect(DevicePresentationService.instance.isTelevision, detectedTv);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the saved mode is applied before the first home screen',
      (tester) async {
    await sharedPrefsSingleton.setString(SettingsPreferences.APP_MODE, 'tv');
    final settings = SettingsProvider();
    await settings.getCurrentAppMode();
    await pumpApp(tester, settings, DevicePresentation.handheld);

    expect(find.text('TV home'), findsOneWidget);
    expect(find.text('Mobile home'), findsNothing);
    expect(DevicePresentationService.instance.isTelevision, true);
  });
}
