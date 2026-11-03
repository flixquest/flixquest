import 'package:flixquest/services/subtitle_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubtitleTranslationService Indonesian pronoun rules', () {
    test('converts KAMU and ANDA to KAU with case sensitivity', () {
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('KAMU dan ANDA'),
        'KAU dan KAU',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('Kamu dan Anda'),
        'Kau dan Kau',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('kamu dan anda'),
        'kau dan kau',
      );
    });

    test('converts SAYA to AKU with case sensitivity', () {
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('SAYA mengerti'),
        'AKU mengerti',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('Saya mengerti'),
        'Aku mengerti',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('apakah ini milik saya?'),
        'apakah ini milik aku?',
      );
    });

    test('converts KAMULAH and ANDALAH to KAULAH with case sensitivity', () {
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('KAMULAH pemenangnya'),
        'KAULAH pemenangnya',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('Kamulah pemenangnya'),
        'Kaulah pemenangnya',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('kamulah pemenangnya'),
        'kaulah pemenangnya',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('ANDALAH sang juara'),
        'KAULAH sang juara',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('Andalah sang juara'),
        'Kaulah sang juara',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('andalah sang juara'),
        'kaulah sang juara',
      );
    });

    test('preserves words that contain pronoun substrings (word boundary protection)', () {
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('Dia sangat pandai dan menyayangi burung dengan sayap'),
        'Dia sangat pandai dan menyayangi burung dengan sayap',
      );
      expect(
        SubtitleTranslationService.applyIndonesianPronounRules('Seandainya kamu mandiri seperti saya'),
        'Seandainya kau mandiri seperti aku',
      );
    });
  });

  group('SubtitleTranslationService format handling and world language support', () {
    test('preserves SRT cues, numbers, and timestamps', () async {
      const srt = '''1
00:00:01,000 --> 00:00:03,000
Hello world.

2
00:00:04,500 --> 00:00:06,000
Goodbye.
''';

      final result = await SubtitleTranslationService.instance.translateSubtitleContent(
        srt,
        targetLanguage: 'en',
      );

      expect(result, contains('00:00:01,000 --> 00:00:03,000'));
      expect(result, contains('00:00:04,500 --> 00:00:06,000'));
    });

    test('supports translating to other world languages (e.g. Spanish, French)', () async {
      final esResult = await SubtitleTranslationService.instance.translateText(
        'Hello, welcome!',
        targetLanguage: 'es',
      );
      expect(esResult.toLowerCase(), contains('hola'));

      final frResult = await SubtitleTranslationService.instance.translateText(
        'Thank you very much',
        targetLanguage: 'fr',
      );
      expect(frResult.toLowerCase(), contains('merci'));
    });
  });
}
