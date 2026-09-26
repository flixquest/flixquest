import 'package:flixquest/catalog/home_feed_controller.dart';
import 'package:flixquest/mobile/app/mobile_tabs.dart';
import 'package:flixquest/models/default_home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('each old choice carries over once', () async {
    const expected = <int?, DefaultHome>{
      null: DefaultHome.home,
      0: DefaultHome.home,
      1: DefaultHome.homeSeries,
      2: DefaultHome.search,
      3: DefaultHome.mine,
      4: DefaultHome.mine,
      99: DefaultHome.home,
    };
    for (final MapEntry(key: legacy, value: now) in expected.entries) {
      final prefs = await _prefs(<String, Object>{
        if (legacy != null) DefaultHome.legacyStorageKey: legacy,
      });
      expect(DefaultHome.load(prefs), now, reason: 'old value $legacy');
      expect(prefs.getString(DefaultHome.storageKey), now.id);
    }
  });

  test('a choice made since wins over the old one', () async {
    final prefs = await _prefs(<String, Object>{
      DefaultHome.legacyStorageKey: 1,
      DefaultHome.storageKey: 'mine',
    });
    expect(DefaultHome.load(prefs), DefaultHome.mine);

    await DefaultHome.homeMovies.save(prefs);
    expect(DefaultHome.load(prefs), DefaultHome.homeMovies);
  });

  test('each choice opens its tab and filter', () {
    expect(MobileTab.forDefault(DefaultHome.home), MobileTab.home);
    expect(MobileTab.forDefault(DefaultHome.homeMovies), MobileTab.home);
    expect(MobileTab.forDefault(DefaultHome.homeSeries), MobileTab.home);
    expect(MobileTab.forDefault(DefaultHome.search), MobileTab.search);
    expect(MobileTab.forDefault(DefaultHome.mine), MobileTab.mine);

    expect(homeFilterForDefault(DefaultHome.home), HomeFilter.all);
    expect(homeFilterForDefault(DefaultHome.homeMovies), HomeFilter.movies);
    expect(homeFilterForDefault(DefaultHome.homeSeries), HomeFilter.series);
  });
}
