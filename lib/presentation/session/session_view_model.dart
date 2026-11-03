import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flixquest/core/cache/http_cache.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/storage/kv_store.dart';
import 'package:flixquest/core/storage/secure_token_store.dart';
import '../../data/models/app_user.dart';
import '../../data/models/auth_requests.dart';
import '../../data/models/auth_session.dart';
import '../../data/models/tv_sign_in.dart';
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

  /// The backend account behind this install: `user:<id>`, or `guest:<id>`
  /// for a tracked guest that never syncs. Push registration follows it.
  final ValueNotifier<String?> accountId = ValueNotifier(null);
  int? _guestId;
  Future<void>? _guestWork;
  String? get _guestToken => _guestId == null ? null : _token;
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
    accountId.value = user != null
        ? 'user:${user!.id}'
        : _guestId != null && _token != null
            ? 'guest:$_guestId'
            : null;
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
      _guestId = null;
      final browsing = preferences.getBool('session.guest') ?? false;
      final guestId = preferences.getInt('session.guest_id');
      if (_token != null && guestId != null) {
        _guestId = guestId;
        _publish(SessionState.guest(browsing: browsing));
        return;
      }
      if (_token == null) {
        _publish(SessionState.guest(browsing: browsing));
        if (browsing) unawaited(ensureGuestAccount());
        return;
      }
      // The cached profile opens the app at once and the backend only
      // confirms it, so launching never waits on, or signs out over, an outage.
      final cached = _cachedUser();
      if (cached != null) {
        _publish(SessionState.authenticated(cached));
        _validation =
            _validate(revision, cached: true).catchError((Object _) {});
        return;
      }
      await _validate(revision, cached: false);
    } catch (_) {
      if (revision == _revision) _publish(const SessionState.guest());
    }
  }

  /// The background profile check started by the last cached [restore].
  @visibleForTesting
  Future<void>? get validation => _validation;
  Future<void>? _validation;

  /// Bounds the launch wait when there is no cached profile to open with.
  static const _restoreTimeout = Duration(seconds: 8);

  AppUser? _cachedUser() {
    final saved = preferences.getJson('session.user');
    if (saved is! Map<String, dynamic>) return null;
    try {
      final user = AppUser.fromJson(saved);
      return preferences.getString('session.owner') == 'user:${user.id}'
          ? user
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _validate(int revision, {required bool cached}) async {
    var profile = repository.profile();
    if (!cached) {
      profile = profile.timeout(_restoreTimeout,
          onTimeout: () => const Result.err(Failure.timeout()));
    }
    final result = await profile;
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
          // Only Laravel itself can end a session; outages, edge errors and
          // malformed responses keep the cached one.
          if (failure is UnauthorizedFailure || failure is ForbiddenFailure) {
            await _clear(const SessionState.guest());
          } else if (!cached) {
            // Retain the token for a later successful restore; grant no account access.
            _publish(const SessionState.guest());
          }
        });
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
              _guestId = null;
              await preferences.remove('session.guest_id');
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

  Future<Result<AuthSession>> signIn(LoginRequest request,
          {int? replaceDeviceId}) =>
      _authenticate(
          () => repository.signIn(request,
              guestToken: _guestToken, replaceDeviceId: replaceDeviceId),
          mergeGuest: true);
  Future<Result<AuthSession>> signUp(RegisterRequest request) => _authenticate(
      () => repository.signUp(request, guestToken: _guestToken),
      mergeGuest: true);
  /// Signs in an upgraded install from the Firebase session it still holds.
  Future<Result<AuthSession>> signInWithFirebaseSession(String idToken) =>
      _authenticate(() => repository.exchangeFirebaseSession(idToken),
          mergeGuest: true);
  Future<Result<TvSignInCode>> startTvSignIn() => repository.startTvSignIn();

  /// Checks once whether a phone approved [deviceCode]. An approval signs
  /// this install in like any other sign-in; waiting changes nothing here.
  Future<Result<TvSignInCheck>> checkTvSignIn(String deviceCode,
      {int? replaceDeviceId}) async {
    final result = await repository.checkTvSignIn(deviceCode,
        guestToken: _guestToken, replaceDeviceId: replaceDeviceId);
    final session = switch (result) {
      Ok(:final value) => value.session,
      Err() => null,
    };
    if (session == null) return result;
    final signedIn = await _authenticate(() async => Result.ok(session),
        mergeGuest: true);
    return signedIn.map(
        (session) => TvSignInCheck(TvSignInStatus.approved, session));
  }

  /// The Google sign-in a device-limit refusal answered, reused when the
  /// person picks a device to sign out so Google does not ask again.
  String? _deviceLimitedGoogleToken;

  Future<Result<AuthSession?>> signInWithGoogle({int? replaceDeviceId}) async {
    final revision = _revision;
    final idToken = replaceDeviceId != null && _deviceLimitedGoogleToken != null
        ? _deviceLimitedGoogleToken
        : await google.authenticate();
    _deviceLimitedGoogleToken = null;
    if (revision != _revision) {
      return const Result.err(
          Failure.unknown(message: 'Session changed. Please try again.'));
    }
    if (idToken == null) return const Result.ok(null);
    final result = await _authenticate(
        () => repository.signInWithGoogle(idToken,
            guestToken: _guestToken, replaceDeviceId: replaceDeviceId),
        mergeGuest: true);
    return result.when(
        ok: (session) => Result.ok(session),
        err: (failure) {
          if (failure is DeviceLimitFailure) _deviceLimitedGoogleToken = idToken;
          return Result.err(failure);
        });
  }

  Future<void> enterGuest() async {
    if (_guestId != null && _token != null) {
      await preferences.setBool('session.guest', true);
      _publish(const SessionState.guest(browsing: true));
      return;
    }
    await _clear(const SessionState.guest(browsing: true));
    await preferences.setBool('session.guest', true);
    unawaited(ensureGuestAccount());
  }

  /// Returns to the sign-in screens without discarding the guest account, as
  /// Firebase keeps an anonymous user until it is linked or replaced: signing
  /// up upgrades it and Continue anonymously reuses it.
  Future<void> leaveGuest() async {
    await preferences.setBool('session.guest', false);
    _publish(const SessionState.guest());
  }

  /// Gives a browsing guest its backend account, like a Firebase anonymous
  /// sign-in. Offline guests keep browsing; launch and resume retry.
  Future<void> ensureGuestAccount() =>
      _guestWork ??= _createGuestAccount().whenComplete(() => _guestWork = null);

  Future<void> _createGuestAccount() async {
    final browsing = _state.maybeWhen(guest: (b) => b, orElse: () => false);
    if (!browsing || _token != null) return;
    final revision = _revision;
    final result = await repository.createGuest();
    await result.when(
        ok: (guest) => _serialize(() async {
              if (revision != _revision || _token != null) return;
              await tokens.write(guest.token);
              await preferences.setInt('session.guest_id', guest.id);
              if (revision != _revision) return;
              _token = guest.token;
              _guestId = guest.id;
              _publish(const SessionState.guest(browsing: true));
            }),
        err: (_) async {});
  }

  Future<void> _clear(SessionState next) async {
    ++_revision;
    _token = null;
    _guestId = null;
    _publish(next);
    await _serialize(() async {
      await tokens.clear();
      await preferences.remove('session.guest_id');
      await preferences.remove('session.user');
      await preferences.remove('session.owner');
      await preferences.setBool('session.guest', false);
      await cache.clearScope('user');
    });
  }

  Future<void> expire(String rejectedToken) async {
    if (_token == null || _token != rejectedToken) return;
    if (_guestId != null) {
      // A revoked guest account is replaced while the guest keeps browsing.
      await _clear(const SessionState.guest(browsing: true));
      await preferences.setBool('session.guest', true);
      unawaited(ensureGuestAccount());
      return;
    }
    await _clear(const SessionState.expired());
  }

  Future<void> signOut() async {
    if (_guestId != null && user == null) return leaveGuest();
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

  Future<Result<void>> deleteAccount(
      {bool acknowledgeWalletCredit = false}) async {
    final owner = ownerId.value;
    final revision = _revision;
    final result = await repository.deleteAccount(
        acknowledgeWalletCredit: acknowledgeWalletCredit);
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
    accountId.dispose();
    super.dispose();
  }
}
