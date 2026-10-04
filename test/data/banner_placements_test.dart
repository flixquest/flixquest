import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/data/ads/placements.dart';

void main() {
  test('client manifest matches the backend delivery contract', () {
    final backend = jsonDecode(
        File('test/support/fixtures/banner_placements.json')
            .readAsStringSync()) as List;
    expect(bannerPlacements.toList(), backend);
    expect(bannerPlacements, hasLength(36));
  });
  test('literal and dynamically constructed banner placements are supported',
      () {
    final tags = <String>{};
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match
          in RegExp(r'(?:placement|adPlacement):([^,]+),').allMatches(source)) {
        for (final literal in RegExp(r"'([^']+)'").allMatches(match[1]!)) {
          final tag = literal[1]!;
          if (tag.contains(r'$')) {
            expect(tag, r'${adBase}_$slot',
                reason:
                    'New dynamic placements need explicit manifest coverage.');
            continue;
          }
          tags.add(file.path.contains('/tv/') ? '${tag}_tv' : tag);
        }
      }
    }
    final home = File('lib/mobile/screens/home_screen.dart').readAsStringSync();
    final bases = RegExp(r"HomeFilter\.\w+ => '(home_[^']+)'")
        .allMatches(home)
        .map((m) => m[1]!);
    final slots =
        RegExp(r"adSlot\('([^']+)'").allMatches(home).map((m) => m[1]!);
    for (final base in bases) {
      for (final slot in slots) {
        tags.add('${base}_$slot');
      }
    }
    final live =
        File('lib/screens/common/live_tv_screen.dart').readAsStringSync();
    tags.addAll(RegExp(r"'(live_tv_(?:top|list_[^']+))'")
        .allMatches(live)
        .map((m) => m[1]!));
    expect(
        tags,
        containsAll([
          'home_all_hero',
          'home_series_genres',
          'live_tv_list_c',
          'title_detail_tv',
          'live_tv_strip_tv',
          'streaming_movies',
          'streaming_tv',
          'genre_movies',
          'genre_tv'
        ]));
    expect(tags.difference(bannerPlacements), isEmpty,
        reason: 'Every shipped ad tag must be accepted by Laravel.');
  });
}
