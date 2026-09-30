import 'package:shared_preferences/shared_preferences.dart';

/// Where the phone app opens: a bottom-bar tab, and for Home, its filter.
enum DefaultHome {
  home('home'),
  homeMovies('home_movies'),
  homeSeries('home_series'),
  search('search'),
  mine('mine');

  const DefaultHome(this.id);

  final String id;

  static const storageKey = 'defaultHome.v2';

  /// The setting before Movies and Series became Home filters, stored as the
  /// index of the tab: 0 Movies, 1 TV shows, 2 Discover, 3 Profile and, by the
  /// old shell's index lookup, 4 Downloads.
  static const legacyStorageKey = 'defaultStatus';

  static DefaultHome? fromId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }

  /// The old tab index as a new choice. Movies was everyone's default rather
  /// than a choice anyone made, so it becomes plain Home; Discover's filters
  /// now live in Search.
  static DefaultHome fromLegacy(int? index) => switch (index) {
        1 => DefaultHome.homeSeries,
        2 => DefaultHome.search,
        3 || 4 => DefaultHome.mine,
        _ => DefaultHome.home,
      };

  /// The stored choice, carrying an old one over the first time.
  static DefaultHome load(SharedPreferences preferences) {
    final stored = fromId(preferences.getString(storageKey));
    if (stored != null) return stored;
    final migrated = fromLegacy(preferences.getInt(legacyStorageKey));
    preferences.setString(storageKey, migrated.id);
    return migrated;
  }

  Future<void> save(SharedPreferences preferences) =>
      preferences.setString(storageKey, id);
}
