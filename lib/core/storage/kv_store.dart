import 'dart:convert';

import 'package:flixquest/singleton/sharedpreferences_singleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Migration preferences use a separate namespace from legacy Firebase state.
class KvStore {
  KvStore(this._preferences, {this.namespace = 'flixquest.laravel.v1.'}) {
    if (namespace.isEmpty) throw ArgumentError('A namespace is required.');
  }

  static Future<KvStore> create() async =>
      KvStore(await SharedPreferencesSingleton.getInstance());

  final SharedPreferences _preferences;
  final String namespace;

  String? getString(String key) => _preferences.getString('$namespace$key');
  int? getInt(String key) => _preferences.getInt('$namespace$key');
  double? getDouble(String key) => _preferences.getDouble('$namespace$key');
  bool? getBool(String key) => _preferences.getBool('$namespace$key');
  List<String>? getStringList(String key) =>
      _preferences.getStringList('$namespace$key');

  Future<void> setString(String key, String value) =>
      _check(_preferences.setString('$namespace$key', value));
  Future<void> setInt(String key, int value) =>
      _check(_preferences.setInt('$namespace$key', value));
  Future<void> setDouble(String key, double value) =>
      _check(_preferences.setDouble('$namespace$key', value));
  Future<void> setBool(String key, bool value) =>
      _check(_preferences.setBool('$namespace$key', value));
  Future<void> setStringList(String key, List<String> value) =>
      _check(_preferences.setStringList('$namespace$key', value));
  Future<void> remove(String key) =>
      _check(_preferences.remove('$namespace$key'));

  Object? getJson(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> setJson(String key, Object? value) =>
      setString(key, jsonEncode(value));

  Future<void> removePrefix(String prefix) async {
    final keys = _preferences
        .getKeys()
        .where(
          (key) => key.startsWith('$namespace$prefix'),
        )
        .toList();
    for (final key in keys) {
      await _check(_preferences.remove(key));
    }
  }

  Future<void> _check(Future<bool> operation) async {
    if (!await operation) throw StateError('Could not persist preferences.');
  }
}
