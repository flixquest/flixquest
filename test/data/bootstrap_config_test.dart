import 'dart:convert';
import 'dart:io';
import 'package:flixquest/data/models/bootstrap_config.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> bootstrapFixture() => (jsonDecode(
        File('test/support/fixtures/bootstrap_config.json').readAsStringSync())
    as Map<String, dynamic>)['data'] as Map<String, dynamic>;

void main() {
  test('backend bootstrap contract supplies typed settings and custom theme',
      () {
    final config = BootstrapConfig.fromJson(bootstrapFixture());
    expect(config.features.enableStream, isTrue);
    expect(config.updates.latestBuildNumber, 5);
    expect(config.network.flixquestApiInstances,
        ['https://scraper-1.flixquest.app']);
    expect(config.ads.startioInterstitialIntervalSeconds, 600);
    expect(config.occasionalTheme.activeThemeId, 'custom_campaign');
    final theme = config.occasionalTheme.themes.single;
    expect(theme.id, 'custom_campaign');
    expect(theme.effect.type, 'confetti');
    expect(theme.effect.density, 30);
    expect(theme.startsAt, DateTime.utc(2026, 10, 1));
    expect(theme.toDomain().primaryColor.toARGB32(), 0xff7b1fa2);
  });
  test('backend with no enabled themes still supplies feature overrides', () {
    final config = BootstrapConfig.fromJson({
      'features': {'enable_stream': false},
      'occasional_theme': {'enabled': true, 'themes': []},
    });
    expect(config.features.enableStream, isFalse);
    expect(config.occasionalTheme.themes, isEmpty);
  });

  test('server active theme wins automatic selection until the next boundary',
      () {
    final catalog = OccasionalThemeCatalog.fromJson({
      'enabled': true,
      'allow_user_selection': true,
      'active_theme_id': 'valentine',
      'themes': [
        {'id': 'christmas', 'enabled': true, 'priority': 100},
        {'id': 'valentines', 'enabled': true, 'priority': 10},
        {
          'id': 'halloween',
          'enabled': true,
          'priority': 200,
          'starts_at': '2026-10-04T00:00:00Z'
        },
      ],
    }).toDomain(resolvedAt: DateTime.utc(2026, 10, 3));
    expect(
        catalog
            .resolve(
                selectedThemeId: 'automatic', now: DateTime.utc(2026, 10, 3))
            ?.id,
        'valentines');
    expect(
        catalog
            .resolve(
                selectedThemeId: 'christmas', now: DateTime.utc(2026, 10, 3))
            ?.id,
        'christmas');
    expect(
        catalog
            .resolve(
                selectedThemeId: 'automatic', now: DateTime.utc(2026, 10, 4))
            ?.id,
        'halloween');
  });

  test(
      'missing and malformed scalar settings use safe defaults and legacy Live TV fallback',
      () {
    final defaults = BootstrapConfig.fromJson({});
    expect(defaults.features.enableStream, isTrue);
    expect(defaults.features.enableDownload, isTrue);
    expect(defaults.features.enableLiveTv, isTrue);
    expect(defaults.ads.startioBannerEnabled, isFalse);
    final config = BootstrapConfig.fromJson({
      'features': {
        'enable_stream': 'false',
        'enable_download': 0,
        'enable_ott': false
      },
      'updates': {'latest_build_number': '27'},
      'ads': {
        'startio_banner_enabled': 'true',
        'startio_interstitial_interval_seconds': 'invalid'
      },
    });
    expect(config.features.enableStream, isFalse);
    expect(config.features.enableDownload, isFalse);
    expect(config.features.enableLiveTv, isFalse);
    expect(config.updates.latestBuildNumber, 27);
    expect(config.ads.startioBannerEnabled, isTrue);
    expect(config.ads.startioInterstitialIntervalSeconds, 600);
  });
  test('built-in aliases retain preset palettes and effect types', () {
    final aliases = {
      'xmas': 'snow',
      'ethiopian-new-year': 'adey_flowers',
      'enkutatash': 'adey_flowers',
      'new-year': 'fireworks',
      'valentine': 'hearts',
      'valentines_day': 'hearts',
      'eid_al_fitr': 'stars',
      'eid_al_adha': 'stars'
    };
    for (final entry in aliases.entries) {
      final theme = OccasionalTheme.fromJson({
        'id': entry.key,
        'enabled': true,
        'colors': ['invalid'],
        'effect': {'enabled': true, 'type': 'invalid'}
      });
      expect(theme.enabled, isTrue, reason: entry.key);
      expect(theme.effect.type, entry.value, reason: entry.key);
      expect(theme.effect.enabled, isTrue, reason: entry.key);
    }
  });
  test(
      'catalog drops invalid custom palettes and date windows but retains built-in fallback',
      () {
    final catalog = OccasionalThemeCatalog.fromJson({
      'enabled': true,
      'themes': [
        {
          'id': 'bad',
          'enabled': true,
          'colors': ['#123456']
        },
        {
          'id': 'custom',
          'enabled': true,
          'colors': ['#123456', '#123456']
        },
        {'id': 'christmas', 'enabled': true, 'starts_at': 'invalid'},
        {
          'id': 'valentines',
          'enabled': true,
          'starts_at': '2026-10-02',
          'ends_at': '2026-10-01'
        },
        {
          'id': 'halloween',
          'enabled': true,
          'colors': ['invalid']
        },
      ]
    });
    expect(catalog.themes.map((t) => t.id), ['halloween']);
    expect(catalog.themes.single.effect.enabled, isFalse);
  });
  test(
      'theme activation endpoints are inclusive and priorities break ties alphabetically',
      () {
    final catalog = OccasionalThemeCatalog.fromJson({
      'enabled': true,
      'themes': [
        {
          'id': 'halloween',
          'enabled': true,
          'priority': 100,
          'starts_at': '2026-10-01T03:00:00+03:00',
          'ends_at': '2026-10-15T00:00:00Z'
        },
        {
          'id': 'christmas',
          'enabled': true,
          'priority': 100,
          'starts_at': '2026-10-01T00:00:00Z',
          'ends_at': '2026-10-15T00:00:00Z'
        },
        {'id': 'valentines', 'enabled': true, 'priority': 10},
      ]
    }).toDomain();
    expect(
        catalog
            .resolve(
                selectedThemeId: 'automatic', now: DateTime.utc(2026, 10, 1))
            ?.id,
        'christmas');
    expect(
        catalog
            .resolve(
                selectedThemeId: 'automatic', now: DateTime.utc(2026, 10, 15))
            ?.id,
        'christmas');
    expect(
        catalog
            .resolve(
                selectedThemeId: 'automatic',
                now: DateTime.utc(2026, 10, 15)
                    .add(const Duration(milliseconds: 1)))
            ?.id,
        'valentines');
  });
  test(
      'default theme aliases and non-selectable choices respect catalog policy',
      () {
    final catalog = OccasionalThemeCatalog.fromJson({
      'enabled': true,
      'allow_user_selection': true,
      'default_theme_id': 'xmas',
      'themes': [
        {
          'id': 'halloween',
          'enabled': true,
          'priority': 100,
          'user_selectable': false
        },
        {'id': 'christmas', 'enabled': true, 'priority': 10},
      ]
    }).toDomain();
    expect(catalog.resolve(selectedThemeId: 'automatic')?.id, 'christmas');
    expect(catalog.resolve(selectedThemeId: 'halloween')?.id, 'christmas');
  });
  test('all documented effect names survive the DTO and domain boundary', () {
    for (final type in [
      'none',
      'snow',
      'confetti',
      'fireworks',
      'petals',
      'candy_eggs',
      'adey_flowers',
      'hearts',
      'stars',
      'bats',
      'sparkles'
    ]) {
      final theme = OccasionalTheme.fromJson({
        'id': 'christmas',
        'enabled': true,
        'effect': {
          'enabled': false,
          'type': type,
          'density': 200,
          'speed': 9,
          'opacity': 0,
        }
      });
      expect(theme.effect.type, type);
      expect(theme.effect.enabled, isFalse);
      expect(theme.effect.density, 80);
      expect(theme.effect.speed, 3);
      expect(theme.effect.opacity, .1);
    }
  });
  test('legacy and map banner overrides retain placement and dimensions', () {
    for (final banners in [
      [
        {
          'promo': {
            'enabled': false,
            'placements': ['home_all_hero'],
            'width': 320,
            'aspectRatio': 2.5
          }
        }
      ],
      {
        'banners': {
          'promo': {
            'enabled': false,
            'placements': ['home_all_hero'],
            'width': 320,
            'aspectRatio': 2.5
          }
        }
      },
    ]) {
      final config = BootstrapConfig.fromJson({'banners': banners});
      final banner = config.banners.single.toDomain();
      expect(banner.key, 'promo');
      expect(banner.enabled, isFalse);
      expect(banner.appliesTo('home_all_hero'), isTrue);
      expect(banner.appliesTo('home_all_trending'), isFalse);
      expect(banner.width, 320);
      expect(banner.aspectRatio, 2.5);
    }
  });
}
