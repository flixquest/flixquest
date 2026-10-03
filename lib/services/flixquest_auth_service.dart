import '../core/error/failure.dart';
import '../core/error/result.dart';
import '../data/models/app_user.dart';
import '../data/models/auth_requests.dart';
import '../data/models/auth_session.dart';
import '../presentation/session/auth_runtime.dart';
import '../presentation/session/session_view_model.dart';

/// Transitional action adapter for the existing phone/TV account forms.
class FlixQuestAuthService {
  FlixQuestAuthService({SessionViewModel? session}) : _provided = session;
  final SessionViewModel? _provided;
  SessionViewModel get session => _provided ?? AuthRuntime.session;
  T _value<T>(Result<T> result) => result.when(ok: (value) => value,
      err: (failure) => throw AuthActionException.fromFailure(failure));
  Future<AuthSession> signIn({required String email, required String password}) async =>
      _value(await session.signIn(LoginRequest(email: email, password: password)));
  Future<void> signInAnonymously() => session.enterGuest();
  Future<AuthSession?> signInWithGoogle() async => _value(await session.signInWithGoogle());
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
  Future<void> deleteAccount() async => _value(await session.deleteAccount());
  Future<void> forgotPassword(String email) async => _value(await session.repository.forgotPassword(email));
  Future<bool> usernameAvailable(String username) async => _value(await session.repository.usernameAvailable(username));
  Future<void> signOut() => session.signOut();
  static Future<void> signOutGoogle() async {
    try { await AuthRuntime.session.google.signOut(); } catch (_) { /* Local state remains authoritative. */ }
  }
}
class AuthActionException implements Exception {
  const AuthActionException({required this.code, required this.message});
  final String code;
  final String message;
  factory AuthActionException.fromFailure(Failure failure) {
    final code = switch (failure) {
      UnauthorizedFailure() => 'invalid-credential',
      ForbiddenFailure() => 'user-disabled',
      ConflictFailure() => 'account-exists-with-different-credential',
      NetworkFailure() || TimeoutFailure() => 'network-request-failed',
      ValidationFailure(:final fields) when fields.containsKey('requires_password_setup') => 'requires-password-setup',
      ValidationFailure(:final fields) when fields.containsKey('username') => 'username-already-in-use',
      ValidationFailure(:final fields) when fields.containsKey('email') => 'email-already-in-use',
      _ => 'request-failed',
    };
    final message = failure is ConflictFailure
        ? 'This email already has a password account. Sign in with your password first.'
        : failure is ValidationFailure && failure.fields.isNotEmpty
          ? failure.message ?? failure.fields.values.expand((messages) => messages).firstOrNull ?? 'Unable to complete this request. Please try again.'
          : failure.message ?? 'Unable to complete this request. Please try again.';
    return AuthActionException(code: code, message: message);
  }
  @override
  String toString() => message;
}
