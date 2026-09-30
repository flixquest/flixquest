import 'dart:convert';
import 'dart:io';

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
}
