import 'dart:convert';
import 'dart:io';

import 'package:flixquest/translations/codegen_loader.g.dart';
import 'package:flixquest/translations/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const localSubtitleKeys = {
    'upload_subtitles',
    'select_subtitle_file',
    'upload_subtitle_file',
    'supported_formats_srt_vtt',
    'add_more',
    'local_file',
    'subtitle_file_count',
    'subtitle_files_count',
    'subtitle_added',
    'subtitle_already_added',
    'failed_upload_subtitle',
    'no_file_selected',
  };

  test('every supported locale exposes the same translation keys', () {
    final localeFiles = Directory('assets/translations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));

    expect(localeFiles, isNotEmpty);

    final catalogs = <String, Set<String>>{};
    for (final file in localeFiles) {
      final catalog =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      catalogs[file.path] = catalog.keys.toSet();
    }

    final reference = catalogs.entries.first;
    expect(reference.value, containsAll(localSubtitleKeys));
    for (final catalog in catalogs.entries.skip(1)) {
      expect(
        catalog.value,
        reference.value,
        reason: '${catalog.key} must match ${reference.key}',
      );
      expect(catalog.value, containsAll(localSubtitleKeys));
    }
  });

  test('share messages use FlixQuest links instead of TMDB links', () {
    final localeFiles = Directory('assets/translations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'));

    for (final file in localeFiles) {
      final catalog =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in <String>[
        'share_movie',
        'share_tv',
        'share_episode',
        'watch_channel_live',
      ]) {
        final message = catalog[key] as String;
        expect(message, contains('{url}'), reason: '${file.path}: $key');
        expect(message, isNot(contains('themoviedb.org')),
            reason: '${file.path}: $key');
      }
      expect(catalog['share_text'], contains('https://flix.quest'),
          reason: '${file.path}: share_text');
    }
  });

  test('the delete-account notice asks for the word the form accepts', () {
    for (final file
        in Directory('assets/translations').listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final catalog =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(catalog['delete_notice'], contains('DELETE'), reason: file.path);
      expect(catalog['delete_notice'], isNot(contains('CONFIRM')),
          reason: file.path);
      for (final key in <String>['type_delete', 'must_type_delete']) {
        expect(catalog[key], contains('DELETE'), reason: '${file.path}: $key');
      }
    }
  });

  test(
      'TV translation templates preserve their named arguments in every locale',
      () {
    final english =
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>;
    final placeholders = RegExp(r'\{([a-zA-Z][a-zA-Z0-9_]*)\}');
    Set<String> names(dynamic value) {
      final text = value is Map ? value.values.join(' ') : '$value';
      return placeholders.allMatches(text).map((match) => match[1]!).toSet();
    }

    for (final file
        in Directory('assets/translations').listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final catalog =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in english.keys
          .where((key) => key.startsWith('tv_') || key.startsWith('player_'))) {
        expect(names(catalog[key]), names(english[key]),
            reason: '${file.path}: $key');
        expect(catalog[key], isNotNull, reason: '${file.path}: $key');
      }
    }
  });

  test('TV screens and player labels reference existing translation keys', () {
    final catalog =
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>;
    final keyPattern = RegExp(r"(?:tr|plural)\('([a-z_0-9]+)'");
    final sources = <File>[
      ...Directory('lib/tv').listSync(recursive: true).whereType<File>(),
      File('lib/screens/common/player/player_strings.dart'),
      File('lib/screens/common/update_screen.dart'),
      File('lib/catalog/catalog_controller.dart'),
    ];
    for (final source in sources.where((file) => file.path.endsWith('.dart'))) {
      for (final match in keyPattern.allMatches(source.readAsStringSync())) {
        expect(catalog, contains(match[1]), reason: source.path);
      }
    }
  });

  test('generated locale keys resolve the default player label', () {
    for (final entry in CodegenLoader.mapLocales.entries) {
      expect(entry.value[LocaleKeys.player_default], isNotEmpty,
          reason: entry.key);
    }
  });

  test('generated catalogs match their translation assets', () {
    for (final entry in CodegenLoader.mapLocales.entries) {
      final catalog = jsonDecode(
          File('assets/translations/${entry.key}.json').readAsStringSync());
      expect(entry.value, catalog, reason: entry.key);
    }
  });
}
