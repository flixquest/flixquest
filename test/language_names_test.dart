import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/functions/language_names.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In tests `tr` falls back to the key, so a resolved name is its key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('languageDisplayName', () {
    test('turns ISO 639-1 codes into names', () {
      expect(languageDisplayName('en'), 'english');
      expect(languageDisplayName('ES'), 'spanish');
    });

    test('turns ISO 639-2 codes into names', () {
      expect(languageDisplayName('eng'), 'english');
      expect(languageDisplayName('spa'), 'spanish');
      expect(languageDisplayName('ger'), 'german');
    });

    test('keeps region and script subtags', () {
      expect(languageDisplayName('en-US'), 'english');
      expect(languageDisplayName('pt-BR'), 'portuguese');
      expect(languageDisplayName('zh-Hant'), 'chinese');
    });

    test('accepts names providers already wrote', () {
      expect(languageDisplayName('Spanish'), 'spanish');
      expect(languageDisplayName('english'), 'english');
    });

    test('keeps numbering and hearing-impaired markers', () {
      expect(languageDisplayName('es #2'), 'spanish #2');
      expect(languageDisplayName('en (HI)'), 'english (HI)');
      expect(languageDisplayName('spa #3 [HI]'), 'spanish #3 (HI)');
    });

    test('leaves labels that are not languages alone', () {
      expect(
        languageDisplayName("Director's commentary"),
        "Director's commentary",
      );
      expect(languageDisplayName('und'), 'und');
    });

    test('handles empty input', () {
      expect(languageDisplayName(''), '');
      expect(languageDisplayName(null), '');
      expect(languageDisplayName('  '), '');
    });

    test('every catalog entry resolves to a translated name', () {
      for (final language in appLanguages) {
        expect(languageDisplayName(language.code), isNot(language.code));
      }
    });
  });
}
