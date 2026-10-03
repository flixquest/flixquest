import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'clearing an account prefix preserves other owners and legacy preferences',
      () async {
    SharedPreferences.setMockInitialValues({'legacy_theme': 'dark'});
    final preferences = await SharedPreferences.getInstance();
    final store = KvStore(preferences);
    await store.setInt('user:7:cursor', 42);
    await store.setInt('user:8:cursor', 99);
    await store.setJson('user:7:profile', {'name': 'Amina'});
    expect(store.getJson('user:7:profile'), {'name': 'Amina'});
    await store.removePrefix('user:7:');
    expect(store.getInt('user:7:cursor'), isNull);
    expect(store.getInt('user:8:cursor'), 99);
    expect(preferences.getString('legacy_theme'), 'dark');
  });

  test('typed settings round trip without escaping the migration namespace',
      () async {
    SharedPreferences.setMockInitialValues({'other.enabled': true});
    final preferences = await SharedPreferences.getInstance();
    final store = KvStore(preferences);
    await store.setString('url', 'https://backend.example');
    await store.setDouble('scale', 1.25);
    await store.setBool('enabled', false);
    await store.setStringList('owners', ['user:7', 'user:8']);
    expect(store.getString('url'), 'https://backend.example');
    expect(store.getDouble('scale'), 1.25);
    expect(store.getBool('enabled'), isFalse);
    expect(store.getStringList('owners'), ['user:7', 'user:8']);
    await store.remove('url');
    expect(store.getString('url'), isNull);
    await store.removePrefix('');
    expect(store.getBool('enabled'), isNull);
    expect(preferences.getBool('other.enabled'), isTrue);
  });

  test('corrupt stored JSON is treated as missing data', () async {
    SharedPreferences.setMockInitialValues({});
    final store = KvStore(await SharedPreferences.getInstance());
    await store.setString('profile', '{broken');
    expect(store.getJson('profile'), isNull);
    expect(store.getJson('missing'), isNull);
  });
}
