import 'package:dio/dio.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/failure_exception.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/network/interceptors/error_interceptor.dart';
import '../models/app_user.dart';
import '../models/auth_requests.dart';
import '../models/auth_session.dart';
import '../models/tv_sign_in.dart';
import '../sources/laravel_api.dart';

class AuthRepository {
  const AuthRepository(this.api, {this.deviceFields});
  final LaravelApi api;

  /// The `device_id`, `device_name` and `platform` every sign-in sends.
  final Future<Map<String, Object>> Function()? deviceFields;
  Future<Map<String, Object>> _device() async =>
      await deviceFields?.call() ?? const {};
  Future<Result<T>> _result<T>(Future<T> Function() work) async {
    try {
      return Result.ok(await work());
    } on FailureException catch (e) {
      return Result.err(e.failure);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 422 &&
          data is Map<String, dynamic> &&
          (data['requires_password_setup'] == true ||
              (data['errors'] is Map &&
                  data['errors']['requires_password_setup'] == true))) {
        return Result.err(Failure.validation({
          'requires_password_setup': ['Set a password using password reset.']
        }, message: data['message'] as String?));
      }
      if (e.response?.statusCode == 409 &&
          data is Map<String, dynamic> &&
          data['code'] == 'wallet_credit_remaining') {
        return Result.err(Failure.validation({
          'wallet_credit_remaining': [
            (data['message'] as String?) ?? 'Your FlixQuest balance has credit.'
          ]
        }, message: data['message'] as String?));
      }
      return Result.err(failureForDio(e));
    } on FormatException {
      return const Result.err(
          Failure.unknown(message: 'Invalid server response.'));
    } on TypeError {
      return const Result.err(
          Failure.unknown(message: 'Invalid server response.'));
    }
  }

  AuthSession _session(Map<String, dynamic> body) {
    final session = AuthSession.fromJson(body);
    if (session.token.trim().isEmpty) {
      throw const FormatException('Missing session token');
    }
    return session;
  }

  /// A credential-less account the backend tracks, like a Firebase anonymous
  /// user. Signing in with its token upgrades or replaces it.
  Future<Result<({int id, String token})>> createGuest() =>
      _result(() async {
        final body = await api.request('auth/guest',
            method: 'POST', authenticated: false);
        final token = body['token'];
        final id = (body['user'] as Map<String, dynamic>)['id'];
        if (token is! String || token.trim().isEmpty || id is! int) {
          throw const FormatException('Missing guest account');
        }
        return (id: id, token: token);
      });
  /// [replaceDeviceId] signs that device out first, after the account was
  /// found at its device limit.
  Future<Result<AuthSession>> signIn(LoginRequest request,
          {String? guestToken, int? replaceDeviceId}) =>
      _result(() async => _session(await api.request('auth/login',
              method: 'POST',
              authenticated: false,
              data: {
                ...request.toJson(),
                ...await _device(),
                'email': request.email.trim().toLowerCase(),
                if (guestToken != null) 'guest_token': guestToken,
                if (replaceDeviceId != null)
                  'replace_device_id': replaceDeviceId
              })));
  Future<Result<AuthSession>> signUp(RegisterRequest request,
          {String? guestToken}) =>
      _result(() async => _session(await api.request('auth/register',
              method: 'POST',
              authenticated: false,
              data: {
                ...request.toJson(),
                ...await _device(),
                'name': request.name.trim(),
                'email': request.email.trim().toLowerCase(),
                'username': request.username.trim().toLowerCase(),
                if (guestToken != null) 'guest_token': guestToken
              })));
  Future<Result<AuthSession>> signInWithGoogle(String idToken,
          {String? guestToken, int? replaceDeviceId}) =>
      _result(() async => _session(await api.request('auth/google',
          method: 'POST',
          authenticated: false,
          data: {
            ...await _device(),
            'id_token': idToken,
            if (guestToken != null) 'guest_token': guestToken,
            if (replaceDeviceId != null) 'replace_device_id': replaceDeviceId
          })));
  /// A code for this TV to show so a phone can sign it in.
  Future<Result<TvSignInCode>> startTvSignIn() =>
      _result(() async => TvSignInCode.fromJson(await api.request(
          'auth/tv/codes',
          method: 'POST',
          authenticated: false,
          data: await _device())));

  /// Whether a phone has approved [deviceCode] yet, and once it has, this
  /// TV's session. A device-limit refusal leaves the approval standing, so
  /// the check can be repeated with [replaceDeviceId].
  Future<Result<TvSignInCheck>> checkTvSignIn(String deviceCode,
          {String? guestToken, int? replaceDeviceId}) =>
      _result(() async {
        final body = await api.request('auth/tv/token',
            method: 'POST',
            authenticated: false,
            data: {
              ...await _device(),
              'device_code': deviceCode,
              if (guestToken != null) 'guest_token': guestToken,
              if (replaceDeviceId != null) 'replace_device_id': replaceDeviceId
            });
        return switch (body['status']) {
          'approved' => TvSignInCheck(TvSignInStatus.approved, _session(body)),
          'pending' => const TvSignInCheck(TvSignInStatus.pending),
          'denied' => const TvSignInCheck(TvSignInStatus.denied),
          'expired' => const TvSignInCheck(TvSignInStatus.expired),
          _ => throw const FormatException('Invalid TV sign-in status'),
        };
      });
  Future<Result<AuthSession>> exchangeFirebaseSession(String idToken) =>
      _result(() async => _session(await api.request('auth/firebase/exchange',
          method: 'POST',
          authenticated: false,
          data: {...await _device(), 'id_token': idToken})));
  Future<Result<AppUser>> profile() => _result(() async => AppUser.fromJson(
      (await api.request('user/profile'))['user'] as Map<String, dynamic>));
  Future<Result<AppUser>> updateProfile(UpdateProfileRequest request) =>
      _result(() async => AppUser.fromJson((await api.request('user/profile',
          method: 'PUT',
          data: request.toJson()))['user'] as Map<String, dynamic>));
  Future<Result<AppUser>> changeEmail(ChangeEmailRequest request) =>
      _result(() async => AppUser.fromJson((await api
              .request('user/change-email', method: 'POST', data: {
            ...request.toJson(),
            'email': request.email.trim().toLowerCase()
          }))['user'] as Map<String, dynamic>));
  Future<Result<void>> changePassword(ChangePasswordRequest request) =>
      _result(() async {
        await api.request('user/change-password',
            method: 'POST', data: request.toJson());
      });
  Future<Result<void>> signOut() => _result(() async {
        await api.request('auth/logout', method: 'POST');
      });
  /// Laravel refuses (409 `wallet_credit_remaining`) while the FlixQuest
  /// balance holds credit, until the viewer acknowledges it.
  Future<Result<void>> deleteAccount({bool acknowledgeWalletCredit = false}) =>
      _result(() async {
        await api.request('user/account',
            method: 'DELETE',
            data: acknowledgeWalletCredit
                ? {'acknowledge_wallet_credit': true}
                : null);
      });
  Future<Result<void>> forgotPassword(String email) => _result(() async {
        await api.request('auth/forgot-password',
            method: 'POST',
            authenticated: false,
            data: {'email': email.trim().toLowerCase()});
      });
  Future<Result<void>> resetPassword(
          {required String email,
          required String token,
          required String password}) =>
      _result(() async {
        await api.request('auth/reset-password',
            method: 'POST',
            authenticated: false,
            data: {
              'email': email.trim().toLowerCase(),
              'token': token,
              'password': password,
              'password_confirmation': password
            });
      });
  Future<Result<bool>> usernameAvailable(String username) => _result(() async {
        final body = await api.request('users/check-username',
            authenticated: false,
            query: {'username': username.trim().toLowerCase()});
        if (body['available'] is! bool) {
          throw const FormatException('Invalid username response');
        }
        return body['available'] as bool;
      });
}
