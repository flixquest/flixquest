import '../core/error/failure.dart';
import '../core/error/result.dart';
import '../data/models/app_user.dart';
import '../data/models/auth_requests.dart';
import '../data/models/auth_session.dart';
import '../data/models/tv_sign_in.dart';
import '../presentation/session/auth_runtime.dart';
import '../presentation/session/session_view_model.dart';

/// Transitional action adapter for the existing phone/TV account forms.
class FlixQuestAuthService {
  FlixQuestAuthService({SessionViewModel? session}) : _provided = session;
  final SessionViewModel? _provided;
  SessionViewModel get session => _provided ?? AuthRuntime.session;
  T _value<T>(Result<T> result) => result.when(ok: (value) => value,
      err: (failure) => throw AuthActionException.fromFailure(failure));
  Future<AuthSession> signIn({required String email, required String password, int? replaceDeviceId}) async =>
      _value(await session.signIn(LoginRequest(email: email, password: password), replaceDeviceId: replaceDeviceId));
  Future<void> signInAnonymously() => session.enterGuest();
  Future<AuthSession?> signInWithGoogle({int? replaceDeviceId}) async =>
      _value(await session.signInWithGoogle(replaceDeviceId: replaceDeviceId));

  Future<TvSignInCode> startTvSignIn() async =>
      _value(await session.startTvSignIn());
  Future<TvSignInCheck> checkTvSignIn(String deviceCode, {int? replaceDeviceId}) async =>
      _value(await session.checkTvSignIn(deviceCode, replaceDeviceId: replaceDeviceId));

  /// Runs [signIn], and while the account is at its device limit asks [pick]
  /// which device to sign out and signs in again in its place. Null when the
  /// person backs out of the picker.
  Future<T?> withinDeviceLimit<T>(Future<T> Function(int? replaceDeviceId) signIn,
      {required Future<int?> Function(DeviceLimitFailure limit) pick}) async {
    int? replaceDeviceId;
    while (true) {
      try {
        return await signIn(replaceDeviceId);
      } on AuthActionException catch (error) {
        final limit = error.deviceLimit;
        if (limit == null) rethrow;
        replaceDeviceId = await pick(limit);
        if (replaceDeviceId == null) return null;
      }
    }
  }
  Future<AuthSession> createAccount({required String fullName, required String email,
      required String username, required String password, required int profileId,
      bool verified = false}) async {
    if (!_value(await session.repository.usernameAvailable(username))) {
      throw const AuthActionException(code: 'username-already-in-use', message: 'That username is already in use.');
    }
    return _value(await session.signUp(RegisterRequest(name: fullName, email: email,
        username: username, password: password, profileId: profileId)));
  }
  Future<AppUser> updateProfile(UpdateProfileRequest request) async => _value(await session.updateProfile(request));
  Future<AppUser> changeEmail(ChangeEmailRequest request) async => _value(await session.changeEmail(request));
  Future<void> changePassword(ChangePasswordRequest request) async => _value(await session.changePassword(request));
  Future<void> deleteAccount({bool acknowledgeWalletCredit = false}) async =>
      _value(await session.deleteAccount(
          acknowledgeWalletCredit: acknowledgeWalletCredit));
  Future<void> forgotPassword(String email) async => _value(await session.repository.forgotPassword(email));
  Future<bool> usernameAvailable(String username) async => _value(await session.repository.usernameAvailable(username));
  Future<void> signOut() => session.signOut();
  static Future<void> signOutGoogle() async {
    try { await AuthRuntime.session.google.signOut(); } catch (_) { /* Local state remains authoritative. */ }
  }
}
class AuthActionException implements Exception {
  const AuthActionException({required this.code, required this.message, this.deviceLimit});
  final String code;
  final String message;
  /// The signed-in devices, when the account is at its device limit.
  final DeviceLimitFailure? deviceLimit;
  factory AuthActionException.fromFailure(Failure failure) {
    final code = switch (failure) {
      UnauthorizedFailure() => 'invalid-credential',
      ForbiddenFailure() => 'user-disabled',
      DeviceLimitFailure() => 'device-limit-reached',
      ConflictFailure() => 'account-exists-with-different-credential',
      NetworkFailure() || TimeoutFailure() => 'network-request-failed',
      ValidationFailure(:final fields) when fields.containsKey('requires_password_setup') => 'requires-password-setup',
      ValidationFailure(:final fields) when fields.containsKey('wallet_credit_remaining') => 'wallet-credit-remaining',
      ValidationFailure(:final fields) when fields.containsKey('username') => 'username-already-in-use',
      ValidationFailure(:final fields) when fields.containsKey('email') => 'email-already-in-use',
      _ => 'request-failed',
    };
    final message = failure is ConflictFailure
        ? 'This email already has a password account. Sign in with your password first.'
        : failure is ValidationFailure && failure.fields.isNotEmpty
          ? failure.message ?? failure.fields.values.expand((messages) => messages).firstOrNull ?? 'Unable to complete this request. Please try again.'
          : failure.message ?? 'Unable to complete this request. Please try again.';
    return AuthActionException(code: code, message: message,
        deviceLimit: failure is DeviceLimitFailure ? failure : null);
  }
  @override
  String toString() => message;
}
