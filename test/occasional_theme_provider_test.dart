import 'package:flixquest/constants/api_constants.dart';
import 'package:flixquest/constants/app_constants.dart';
import 'package:flixquest/models/occasional_theme.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/singleton/sharedpreferences_singleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TMDB_API_KEY = 'test';
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();
  });

  test('seasonal themes default on and can be persistently disabled', () async {
    final provider = AppDependencyProvider();
    await provider.getOccasionalTheme();
    provider.occasionalThemeCatalog = OccasionalThemeCatalog.fromJsonString('''
      {
        "schema_version": 2,
        "enabled": true,
        "themes": [
          {"id": "christmas", "enabled": true}
        ]
      }
    ''');

    expect(provider.occasionalThemeEnabled, isTrue);
    expect(provider.activeOccasionalTheme?.id, 'christmas');

    provider.occasionalThemeEnabled = false;
    expect(provider.activeOccasionalTheme, isNull);
    await Future<void>.delayed(Duration.zero);

    final restoredProvider = AppDependencyProvider();
    await restoredProvider.getOccasionalTheme();
    expect(restoredProvider.occasionalThemeEnabled, isFalse);
    expect(restoredProvider.activeOccasionalTheme, isNull);

    provider.dispose();
    restoredProvider.dispose();
  });

  test('invalid remote JSON preserves the last hardcoded occasion', () {
    final provider = AppDependencyProvider();
    provider.occasionalThemeCatalog = OccasionalThemeCatalog.fromJsonString('''
      {
        "schema_version": 2,
        "enabled": true,
        "themes": [
          {"id": "halloween", "enabled": true}
        ]
      }
    ''');

    expect(provider.activeOccasionalTheme?.id, 'halloween');
    expect(provider.applyRemoteOccasionalTheme('not-json'), isFalse);
    expect(provider.activeOccasionalTheme?.id, 'halloween');
    expect(
      provider.applyRemoteOccasionalTheme('''
        {
          "schema_version": 2,
          "enabled": true,
          "themes": [
            {"id": "unknown_event", "enabled": true, "colors": ["#123456"]}
          ]
        }
      '''),
      isFalse,
    );
    expect(provider.activeOccasionalTheme?.id, 'halloween');

    expect(
      provider.applyRemoteOccasionalTheme('''
        {
          "schema_version": 2,
          "enabled": true,
          "themes": [
            {
              "id": "unknown_event",
              "enabled": true,
              "colors": ["#123456", "#FEDCBA"]
            }
          ]
        }
      '''),
      isTrue,
    );
    expect(provider.activeOccasionalTheme?.id, 'unknown_event');

    provider.dispose();
  });
}
