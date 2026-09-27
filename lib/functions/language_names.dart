import 'package:easy_localization/easy_localization.dart';

/// One language in the app's catalog: its ISO 639-1 code, the translation key
/// of its name, and the other codes providers report it as (ISO 639-2/B,
/// deprecated two-letter tags, and the like).
class LanguageEntry {
  const LanguageEntry(this.code, this.translationKey, [this.aliases = const <String>[]]);

  final String code;
  final String translationKey;
  final List<String> aliases;
}

/// Every language a subtitle or audio track can be named in. The order is the
/// order the settings screens list them.
const List<LanguageEntry> appLanguages = <LanguageEntry>[
  LanguageEntry('ar', 'arabic', ['ara']),
  LanguageEntry('bg', 'bulgarian', ['bul']),
  LanguageEntry('zh', 'chinese', ['chi', 'zho', 'cmn', 'yue']),
  LanguageEntry('hr', 'croaitian', ['hrv', 'scr']),
  LanguageEntry('cs', 'czech', ['cze', 'ces']),
  LanguageEntry('da', 'danish', ['dan']),
  LanguageEntry('nl', 'dutch', ['dut', 'nld']),
  LanguageEntry('en', 'english', ['eng']),
  LanguageEntry('et', 'estonian', ['est']),
  LanguageEntry('fi', 'finnish', ['fin']),
  LanguageEntry('fr', 'french', ['fre', 'fra']),
  LanguageEntry('de', 'german', ['ger', 'deu']),
  LanguageEntry('el', 'greek', ['gre', 'ell']),
  LanguageEntry('he', 'hebrew', ['heb', 'iw']),
  LanguageEntry('hi', 'hindi', ['hin']),
  LanguageEntry('hu', 'hungarian', ['hun']),
  LanguageEntry('id', 'indonesian', ['ind', 'in']),
  LanguageEntry('it', 'italian', ['ita']),
  LanguageEntry('ja', 'japanese', ['jpn']),
  LanguageEntry('ko', 'korean', ['kor']),
  LanguageEntry('lv', 'latvian', ['lav']),
  LanguageEntry('lt', 'lithuanian', ['lit']),
  LanguageEntry('ms', 'malay', ['msa', 'may']),
  LanguageEntry('no', 'norwegian', ['nor', 'nb', 'nn']),
  LanguageEntry('pl', 'polish', ['pol']),
  LanguageEntry('pt', 'portuguese', ['por']),
  LanguageEntry('ro', 'romanian', ['rum', 'ron']),
  LanguageEntry('ru', 'russian', ['rus']),
  LanguageEntry('sr', 'serbian', ['srp', 'scc']),
  LanguageEntry('sk', 'slovak', ['slo', 'slk']),
  LanguageEntry('sl', 'slovene', ['slv']),
  LanguageEntry('es', 'spanish', ['spa', 'castilian']),
  LanguageEntry('sv', 'swedish', ['swe']),
  LanguageEntry('th', 'thai', ['tha']),
  LanguageEntry('tr', 'turkish', ['tur']),
  LanguageEntry('uk', 'ukrainian', ['ukr']),
];

/// The markers providers append to a track's language: a sequence number and a
/// hearing-impaired flag. Both are kept for display, never used to match.
final RegExp _numberMarker = RegExp(r'\s*#\d+\s*$');
final RegExp _hiMarker = RegExp(
  r'\s*[\(\[]\s*(?:hi|sdh|hearing impaired)\s*[\)\]]\s*$',
  caseSensitive: false,
);
final RegExp _subtagMarker = RegExp(r'[-_]');

/// The full, localized name of the language a track reports itself in:
/// `en`, `EN`, `eng`, `en-US`, `English`, `Inglés` and `es (HI)` all come back
/// as "English" or "Spanish" in the app's current language, with any `#2` or
/// `(HI)` marker preserved. A label that is not a language ("Director's
/// commentary") is returned cleaned up rather than hidden.
String languageDisplayName(String? label) {
  final raw = label?.trim() ?? '';
  if (raw.isEmpty) return '';

  var base = raw;
  final markers = <String>[];
  final hearingImpaired = _hiMarker.firstMatch(base);
  if (hearingImpaired != null) {
    markers.add('(HI)');
    base = base.substring(0, hearingImpaired.start).trim();
  }
  final numbered = _numberMarker.firstMatch(base);
  if (numbered != null) {
    markers.insert(0, numbered.group(0)!.trim());
    base = base.substring(0, numbered.start).trim();
  }
  if (base.isEmpty) return raw;
  final suffix = markers.isEmpty ? '' : ' ${markers.join(' ')}';

  final language = _findLanguage(base);
  if (language == null) return '$base$suffix';
  return '${tr(language.translationKey)}$suffix';
}

LanguageEntry? _findLanguage(String base) {
  final lowered = base.toLowerCase();
  final candidates = <String>[
    lowered,
    ...lowered.split(_subtagMarker).where((part) => part.isNotEmpty),
  ];
  for (final candidate in candidates) {
    for (final language in appLanguages) {
      if (language.code == candidate || language.aliases.contains(candidate)) {
        return language;
      }
    }
  }
  // A provider that already names the language ("Spanish", "Español") matches
  // the translation key, or the name this app shows in its current language.
  for (final language in appLanguages) {
    if (language.translationKey == lowered) return language;
    if (tr(language.translationKey).toLowerCase() == lowered) return language;
  }
  return null;
}
