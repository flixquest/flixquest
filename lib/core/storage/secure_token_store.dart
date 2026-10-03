import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sanctum tokens belong in platform secure storage, never preferences or logs.
class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const tokenKey = 'flixquest.laravel.v1.sanctum_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: tokenKey);

  Future<void> write(String token) {
    if (token.trim().isEmpty) throw ArgumentError('Token must not be empty.');
    return _storage.write(key: tokenKey, value: token);
  }

  Future<void> clear() => _storage.delete(key: tokenKey);
}
