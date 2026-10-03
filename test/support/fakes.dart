import 'dart:convert';

import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/core/storage/secure_token_store.dart';
import 'package:flixquest/core/time/server_clock.dart';

class FakeSecureTokenStore extends SecureTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> clear() async => token = null;
}

class FakeKvStore implements KvStore {
  final Map<String, Object> _values = {};

  @override
  String get namespace => 'test.';
  @override
  String? getString(String key) => _values[key] as String?;
  @override
  int? getInt(String key) => _values[key] as int?;
  @override
  double? getDouble(String key) => _values[key] as double?;
  @override
  bool? getBool(String key) => _values[key] as bool?;
  @override
  List<String>? getStringList(String key) =>
      (_values[key] as List<String>?)?.toList();
  @override
  Object? getJson(String key) {
    final value = getString(key);
    if (value == null) return null;
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;
  @override
  Future<void> setDouble(String key, double value) async =>
      _values[key] = value;
  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;
  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value.toList();
  @override
  Future<void> setJson(String key, Object? value) =>
      setString(key, jsonEncode(value));
  @override
  Future<void> remove(String key) async => _values.remove(key);
  @override
  Future<void> removePrefix(String prefix) async =>
      _values.removeWhere((key, _) => key.startsWith(prefix));
}

class FakeServerClock extends ServerClock {
  factory FakeServerClock({int deviceTimeMs = 1700000000000, KvStore? store}) =>
      FakeServerClock._(store ?? FakeKvStore(), _FakeClockTime(deviceTimeMs));

  FakeServerClock._(super.store, _FakeClockTime time)
      : _time = time,
        super(now: () => time.now);

  final _FakeClockTime _time;
  DateTime get deviceNow => _time.now;
  void advance(Duration duration) => _time.now = _time.now.add(duration);
}

class _FakeClockTime {
  _FakeClockTime(int milliseconds)
      : now = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  DateTime now;
}
