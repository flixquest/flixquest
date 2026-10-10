import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class FakeFirebaseRemoteConfig implements FirebaseRemoteConfig {
  final Map<String, dynamic> _values = {};
  Map<String, dynamic> defaults = {};

  void setMockString(String key, String value) {
    _values[key] = value;
  }

  void setMockBool(String key, bool value) {
    _values[key] = value;
  }

  void setMockInt(String key, int value) {
    _values[key] = value;
  }

  @override
  String getString(String key) =>
      (_values[key] as String?) ?? (defaults[key] as String?) ?? '';

  @override
  bool getBool(String key) =>
      (_values[key] as bool?) ?? (defaults[key] as bool?) ?? false;

  @override
  int getInt(String key) =>
      (_values[key] as int?) ?? (defaults[key] as int?) ?? 0;

  @override
  RemoteConfigValue getValue(String key) {
    final value = _values[key] ?? defaults[key];
    if (value != null) {
      final source = _values.containsKey(key)
          ? ValueSource.valueRemote
          : ValueSource.valueDefault;
      return RemoteConfigValue(
        utf8.encode(value.toString()),
        source,
      );
    }
    return RemoteConfigValue(
      const [],
      ValueSource.valueDefault,
    );
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    defaults = Map<String, dynamic>.from(defaultParameters);
  }

  @override
  Future<void> setConfigSettings(
      RemoteConfigSettings remoteConfigSettings) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
