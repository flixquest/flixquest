import 'package:flixquest/services/app_session_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restores valid handheld and television destinations', () async {
    SharedPreferences.setMockInitialValues({
      AppSessionStateStore.handheldDestinationKey: 'search',
      AppSessionStateStore.televisionDestinationKey: 'library',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = AppSessionStateStore(preferences);

    expect(store.handheldDestination, 'search');
    expect(store.televisionDestination, 'library');
  });

  test('ignores stale destination values', () async {
    SharedPreferences.setMockInitialValues({
      AppSessionStateStore.handheldDestinationKey: 'removed-screen',
      AppSessionStateStore.televisionDestinationKey: 'removed-screen',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = AppSessionStateStore(preferences);

    expect(store.handheldDestination, isNull);
    expect(store.televisionDestination, isNull);
  });

  test('only persists known destinations', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = AppSessionStateStore(preferences);

    await store.rememberHandheldDestination('mine');
    await store.rememberHandheldDestination('profile');
    await store.rememberTelevisionDestination('settings');
    await store.rememberHandheldDestination('invalid');
    await store.rememberTelevisionDestination('invalid');

    expect(store.handheldDestination, 'mine');
    expect(store.televisionDestination, 'settings');
  });

  test('carries the old phone tabs over to where they live now', () async {
    const expected = <String, String>{
      'movies': 'home',
      'series': 'home',
      'discover': 'home',
      'downloads': 'mine',
      'profile': 'mine',
      'bookmarks': 'mine',
    };
    for (final MapEntry(key: old, value: now) in expected.entries) {
      SharedPreferences.setMockInitialValues({
        AppSessionStateStore.handheldDestinationKey: old,
      });
      final store = AppSessionStateStore(await SharedPreferences.getInstance());
      expect(store.handheldDestination, now, reason: old);
    }
  });

  test('restores each of the four tabs', () async {
    for (final id in AppSessionStateStore.handheldDestinations) {
      SharedPreferences.setMockInitialValues({});
      final store = AppSessionStateStore(await SharedPreferences.getInstance());
      await store.rememberHandheldDestination(id);
      expect(store.handheldDestination, id);
    }
  });
}
