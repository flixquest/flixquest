import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/models/occasional_theme.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/services/ambient_theme_service.dart';
import 'package:flixquest/singleton/sharedpreferences_singleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TMDB_API_KEY = 'test';
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();
  });

  test('ambient mode is opt-in and persists', () async {
    final provider = AppDependencyProvider();
    await provider.getAmbientMode();
    expect(provider.ambientModeEnabled, isFalse);

    provider.ambientModeEnabled = true;
    await Future<void>.delayed(Duration.zero);

    final restored = AppDependencyProvider();
    await restored.getAmbientMode();
    expect(restored.ambientModeEnabled, isTrue);
    provider.dispose();
    restored.dispose();
  });

  test('nested ambient scopes restore their parent and seasonal theme wins',
      () {
    final provider = AppDependencyProvider()..ambientModeEnabled = true;
    final movie = provider.pushAmbientScope();
    provider.updateAmbientScope(movie, Colors.red);
    expect(provider.activeAmbientColor, Colors.red);

    final episode = provider.pushAmbientScope();
    expect(provider.activeAmbientColor, Colors.red);
    provider.updateAmbientScope(episode, Colors.blue);
    expect(provider.activeAmbientColor, Colors.blue);
    provider.popAmbientScope(episode);
    expect(provider.activeAmbientColor, Colors.red);

    provider.occasionalThemeCatalog = OccasionalThemeCatalog.fromJsonString('''
      {"enabled": true, "themes": [{"id": "christmas", "enabled": true}]}
    ''');
    expect(provider.activeOccasionalTheme, isNotNull);
    expect(provider.activeAmbientColor, isNull);

    provider.occasionalThemeEnabled = false;
    expect(provider.activeAmbientColor, Colors.red);
    provider.popAmbientScope(movie);
    expect(provider.activeAmbientColor, isNull);
    provider.dispose();
  });

  test('dominant color ignores neutral pixels and selects saturated artwork',
      () {
    const width = 10;
    const height = 10;
    final pixels = List<int>.filled(width * height * 4, 255);
    for (var i = 0; i < width * height; i++) {
      final offset = i * 4;
      if (i < 70) {
        pixels[offset] = 210;
        pixels[offset + 1] = 25;
        pixels[offset + 2] = 35;
      } else {
        pixels[offset] = 30;
        pixels[offset + 1] = 30;
        pixels[offset + 2] = 30;
      }
    }

    final color = DominantImageColor.fromRgba(
      pixels,
      width: width,
      height: height,
    );
    expect(color, isNotNull);
    expect(color!.r, greaterThan(color.g * 3));
    expect(color.r, greaterThan(color.b * 3));
  });

  test('player scopes suppress and safely restore seasonal effects', () {
    final provider = AppDependencyProvider();
    provider.occasionalThemeCatalog = OccasionalThemeCatalog.fromJsonString('''
      {
        "enabled": true,
        "effects_enabled": true,
        "themes": [{
          "id": "christmas",
          "enabled": true,
          "effect": {"enabled": true, "type": "snow"}
        }]
      }
    ''');
    expect(provider.shouldShowOccasionalEffects, isTrue);

    final player = provider.suppressOccasionalEffects();
    final nestedPlayer = provider.suppressOccasionalEffects();
    expect(provider.shouldShowOccasionalEffects, isFalse);

    provider.releaseOccasionalEffectsSuppression(player);
    expect(provider.shouldShowOccasionalEffects, isFalse);
    provider.releaseOccasionalEffectsSuppression(nestedPlayer);
    expect(provider.shouldShowOccasionalEffects, isTrue);

    // Releasing a scope twice must not affect a future player scope.
    provider.releaseOccasionalEffectsSuppression(nestedPlayer);
    expect(provider.shouldShowOccasionalEffects, isTrue);
    provider.dispose();
  });
}
