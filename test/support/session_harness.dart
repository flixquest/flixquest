import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/network/interceptors/auth_interceptor.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/core/storage/secure_token_store.dart';
import 'package:flixquest/data/repositories/auth_repository.dart';
import 'package:flixquest/data/sources/google_identity_client.dart';
import 'package:flixquest/data/sources/laravel_api.dart';
import 'package:flixquest/presentation/session/session_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_dio.dart';

Map<String, dynamic> authFixture(
    {int id = 7, String token = '7|sanitized-test-token'}) {
  final data =
      jsonDecode(File('test/support/fixtures/auth.json').readAsStringSync())
          as Map<String, dynamic>;
  (data['user'] as Map)['id'] = id;
  data['token'] = token;
  return data;
}

class MemoryTokens extends SecureTokenStore {
  String? value;
  int clears = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

class FakeGoogleIdentity implements GoogleIdentityClient {
  String? accessToken;
  int signOuts = 0;
  @override
  Future<String?> authenticate() async => accessToken;
  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class SessionHarness {
  SessionHarness._(this.dio, this.adapter, this.tokens, this.preferences,
      this.cache, this.google, this.session);
  final Dio dio;
  final FakeDioAdapter adapter;
  final MemoryTokens tokens;
  final KvStore preferences;
  final HttpCache cache;
  final FakeGoogleIdentity google;
  final SessionViewModel session;
  static Future<SessionHarness> create(
      {Future<void> Function(String)? deleteLocalData,
      MemoryTokens? tokenStore}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = KvStore(await SharedPreferences.getInstance());
    final adapter = FakeDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    final tokens = tokenStore ?? MemoryTokens();
    final cache = HttpCache(MemCacheStore());
    final google = FakeGoogleIdentity();
    final session = SessionViewModel(
        repository: AuthRepository(LaravelApi(dio)),
        tokens: tokens,
        preferences: prefs,
        cache: cache,
        google: google,
        deleteLocalData: deleteLocalData);
    dio.interceptors.add(AuthInterceptor(session, dio.options.baseUrl));
    return SessionHarness._(
        dio, adapter, tokens, prefs, cache, google, session);
  }

  Future<void> dispose() async {
    session.dispose();
    dio.close();
    await cache.close();
  }
}
