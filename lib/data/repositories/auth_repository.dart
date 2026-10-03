import 'package:dio/dio.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/failure_exception.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/network/interceptors/error_interceptor.dart';
import '../models/app_user.dart';
import '../models/auth_requests.dart';
import '../models/auth_session.dart';
import '../sources/laravel_api.dart';

class AuthRepository {
  const AuthRepository(this.api);
  final LaravelApi api;
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

  Future<Result<AuthSession>> signIn(LoginRequest request) =>
      _result(() async => _session(await api.request('auth/login',
              method: 'POST',
              authenticated: false,
              data: {
                ...request.toJson(),
                'email': request.email.trim().toLowerCase()
              })));
  Future<Result<AuthSession>> signUp(RegisterRequest request) =>
      _result(() async => _session(await api.request('auth/register',
              method: 'POST',
              authenticated: false,
              data: {
                ...request.toJson(),
                'name': request.name.trim(),
                'email': request.email.trim().toLowerCase(),
                'username': request.username.trim().toLowerCase()
              })));
  Future<Result<AuthSession>> signInWithGoogle(String accessToken) =>
      _result(() async => _session(await api.request('auth/google',
          method: 'POST',
          authenticated: false,
          data: {'access_token': accessToken})));
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
  Future<Result<void>> deleteAccount() => _result(() async {
        await api.request('user/account', method: 'DELETE');
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
