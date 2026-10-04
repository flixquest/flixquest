import 'package:flutter/foundation.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/core/storage/secure_token_store.dart';
import '../../data/models/app_user.dart';
import '../../data/models/auth_requests.dart';
import '../../data/models/auth_session.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/sources/google_identity_client.dart';
import 'session_state.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(
      {required this.repository,
      required this.tokens,
      required this.preferences,
      required this.cache,
      GoogleIdentityClient? google,
      Future<void> Function(String owner)? deleteLocalData,
      Future<void> Function(AppUser user)? mergeGuestData,
      void Function(String? owner)? onOwnerChanged})
      : google = google ?? PlatformGoogleIdentityClient(),
        _deleteLocalData = deleteLocalData ?? ((_) async {}),
        _mergeGuestData = mergeGuestData,
        _onOwnerChanged = onOwnerChanged;
  final AuthRepository repository;
  final SecureTokenStore tokens;
  final KvStore preferences;
  final HttpCache cache;
  final GoogleIdentityClient google;
  final Future<void> Function(String)? _deleteLocalData;
  final Future<void> Function(AppUser)? _mergeGuestData;
  final void Function(String?)? _onOwnerChanged;
  final ValueNotifier<String?> ownerId = ValueNotifier(null);
  final ValueNotifier<String?> gateIdentity = ValueNotifier(null);
  SessionState _state = const SessionState.initializing();
  SessionState get state => _state;
  AppUser? get user =>
      state.maybeWhen(authenticated: (user) => user, orElse: () => null);
  String? _token;
  String? get token => _token;
  int _revision = 0;
  Future<void> _storage = Future<void>.value();
  bool _disposed = false;
  Future<void> _serialize(Future<void> Function() action) {
    final work = _storage.then((_) => action());
    _storage = work.catchError((Object _) {});
    return work;
  }

  void _publish(SessionState state) {
    if (_disposed) return;
    _state = state;
    _onOwnerChanged?.call(user == null ? null : 'user:${user!.id}');
    ownerId.value = user == null ? null : 'user:${user!.id}';
    gateIdentity.value = state.maybeWhen(
        guest: (browsing) => browsing ? 'guest' : null,
        authenticated: (user) => 'user:${user.id}',
        orElse: () => null);
    notifyListeners();
  }

  Future<void> restore() async {
    final revision = ++_revision;
    _publish(const SessionState.initializing());
    try {
      final restoredToken = await tokens.read();
      if (revision != _revision) return;
      _token = restoredToken;
      if (_token == null) {
        _publish(SessionState.guest(
            browsing: preferences.getBool('session.guest') ?? false));
        return;
      }
      final result = await repository.profile();
      if (revision != _revision) {
        // The interceptor may have expired this boot token before profile returns.
        if (result is Err<AppUser> &&
            result.failure is UnauthorizedFailure &&
            _state is ExpiredSession &&
            _token == null) {
          _publish(const SessionState.guest());
        }
        return;
      }
      await result.when(
          ok: (user) async => _serialize(() => _persistUser(user, revision)),
          err: (failure) async {
            if (failure is UnauthorizedFailure || failure is ForbiddenFailure) {
              await _clear(const SessionState.guest());
            } else {
              final saved = preferences.getJson('session.user');
              if (saved is Map<String, dynamic> &&
                  (failure is NetworkFailure || failure is TimeoutFailure)) {
                final user = AppUser.fromJson(saved);
                if (preferences.getString('session.owner') ==
                    'user:${user.id}') {
                  _publish(SessionState.authenticated(user));
                  return;
                }
              }
              // Retain the token for a later successful restore; grant no account access.
              _publish(const SessionState.guest());
            }
          });
    } catch (_) {
      if (revision == _revision) _publish(const SessionState.guest());
    }
  }

  Future<void> _persistUser(AppUser user, int revision) async {
    if (revision != _revision) return;
    await preferences.setJson('session.user', user.toJson());
    await preferences.setString('session.owner', 'user:${user.id}');
    if (revision == _revision) _publish(SessionState.authenticated(user));
  }

  Future<Result<AuthSession>> _authenticate(
      Future<Result<AuthSession>> Function() work,
      {bool mergeGuest = false}) async {
    final revision = ++_revision;
    final result = await work();
    return result.when(
        err: (failure) => Result.err(failure),
        ok: (session) async {
          if (revision != _revision) {
            return const Result.err(Failure.conflict(
                message: 'Session changed. Please try again.'));
          }
          try {
            await _serialize(() async {
              if (revision != _revision) return;
              await tokens.write(session.token);
              if (revision != _revision) return;
              _token = session.token;
              await preferences.setBool('session.guest', false);
              await cache.clearScope('user');
              await _persistUser(session.user, revision);
            });
            if (revision != _revision) {
              return const Result.err(Failure.conflict(
                  message: 'Session changed. Please try again.'));
            }
            if (mergeGuest && _mergeGuestData != null) {
              await _mergeGuestData!(session.user);
            }
            return Result.ok(session);
          } catch (_) {
            if (revision == _revision) await _clear(const SessionState.guest());
            return const Result.err(Failure.cache(
                message: 'Unable to save this session. Please try again.'));
          }
        });
  }

  Future<Result<AuthSession>> signIn(LoginRequest request) =>
      _authenticate(() => repository.signIn(request), mergeGuest: true);
  Future<Result<AuthSession>> signUp(RegisterRequest request) =>
      _authenticate(() => repository.signUp(request), mergeGuest: true);
  Future<Result<AuthSession?>> signInWithGoogle() async {
    final revision = _revision;
    final accessToken = await google.authenticate();
    if (revision != _revision) {
      return const Result.err(
          Failure.unknown(message: 'Session changed. Please try again.'));
    }
    if (accessToken == null) return const Result.ok(null);
    final result = await _authenticate(
        () => repository.signInWithGoogle(accessToken),
        mergeGuest: true);
    return result.when(
        ok: (session) => Result.ok(session),
        err: (failure) => Result.err(failure));
  }

  Future<void> enterGuest() async {
    await _clear(const SessionState.guest(browsing: true));
    await preferences.setBool('session.guest', true);
  }

  Future<void> _clear(SessionState next) async {
    ++_revision;
    _token = null;
    _publish(next);
    await _serialize(() async {
      await tokens.clear();
      await preferences.remove('session.user');
      await preferences.remove('session.owner');
      await preferences.setBool('session.guest', false);
      await cache.clearScope('user');
    });
  }

  Future<void> expire(String rejectedToken) async {
    if (_token == null || _token != rejectedToken) return;
    await _clear(const SessionState.expired());
  }

  Future<void> signOut() async {
    final revision = ++_revision;
    try {
      if (_token != null) await repository.signOut();
    } finally {
      if (revision == _revision ||
          (_token == null && _state is ExpiredSession)) {
        await _clear(const SessionState.guest());
        try {
          await google.signOut();
        } catch (_) {/* Local logout still succeeds. */}
      }
    }
  }

  Future<Result<AppUser>> updateProfile(UpdateProfileRequest request) async {
    final revision = _revision;
    final result = await repository.updateProfile(request);
    await result.when(
        ok: (user) async {
          if (revision == _revision) {
            await _serialize(() => _persistUser(user, revision));
          }
        },
        err: (_) async {});
    return result;
  }

  Future<Result<AppUser>> changeEmail(ChangeEmailRequest request) async {
    final revision = _revision;
    final result = await repository.changeEmail(request);
    await result.when(
        ok: (user) async {
          if (revision == _revision) {
            await _serialize(() => _persistUser(user, revision));
          }
        },
        err: (_) async {});
    return result;
  }

  Future<Result<void>> changePassword(ChangePasswordRequest request) async {
    final revision = _revision;
    final result = await repository.changePassword(request);
    if (result is Ok<void> && revision == _revision) {
      await _clear(const SessionState.expired());
    }
    return result;
  }

  Future<Result<void>> deleteAccount() async {
    final owner = ownerId.value;
    final revision = _revision;
    final result = await repository.deleteAccount();
    if (result is Ok<void> && revision == _revision) {
      await _clear(const SessionState.guest());
      try {
        if (owner != null) await _deleteLocalData?.call(owner);
      } catch (_) {
        return const Result.err(Failure.cache(
            message: 'Account deleted; local data could not be cleared.'));
      }
      try {
        await google.signOut();
      } catch (_) {/* Account is already deleted. */}
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    ownerId.dispose();
    gateIdentity.dispose();
    super.dispose();
  }
}
