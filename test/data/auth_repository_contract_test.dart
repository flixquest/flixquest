import 'package:dio/dio.dart';
import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/core/network/interceptors/logging_interceptor.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/data/repositories/auth_repository.dart';
import 'package:flixquest/data/sources/laravel_api.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_dio.dart';
import '../support/session_harness.dart';

void main() {
  late Dio dio;
  late FakeDioAdapter adapter;
  late AuthRepository repo;
  setUp(() {
    adapter = FakeDioAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1/'))
      ..httpClientAdapter = adapter;
    repo = AuthRepository(LaravelApi(dio));
  });
  tearDown(() => dio.close());
  final endpoints = <(
    String,
    String,
    bool,
    Future<Result<dynamic>> Function(AuthRepository)
  )>[
    (
      'POST',
      'auth/register',
      false,
      (r) => r.signUp(const RegisterRequest(
          name: ' Example ',
          email: ' EXAMPLE@email.test ',
          username: ' Example ',
          password: ' secret ',
          profileId: 3))
    ),
    (
      'POST',
      'auth/login',
      false,
      (r) =>
          r.signIn(const LoginRequest(email: 'a@b.test', password: 'password'))
    ),
    ('POST', 'auth/google', false, (r) => r.signInWithGoogle('access-token')),
    ('GET', 'user/profile', true, (r) => r.profile()),
    (
      'PUT',
      'user/profile',
      true,
      (r) => r.updateProfile(const UpdateProfileRequest(name: 'New name'))
    ),
    (
      'POST',
      'user/change-email',
      true,
      (r) => r.changeEmail(const ChangeEmailRequest(
          currentPassword: ' exact ', email: ' NEW@email.test '))
    ),
    (
      'POST',
      'user/change-password',
      true,
      (r) => r.changePassword(const ChangePasswordRequest(
          currentPassword: ' old ', password: ' new '))
    ),
    ('POST', 'auth/logout', true, (r) => r.signOut()),
    ('DELETE', 'user/account', true, (r) => r.deleteAccount()),
    (
      'POST',
      'auth/forgot-password',
      false,
      (r) => r.forgotPassword(' EXAMPLE@email.test ')
    ),
    (
      'POST',
      'auth/reset-password',
      false,
      (r) => r.resetPassword(
          email: ' EXAMPLE@email.test ', token: 'reset', password: ' new ')
    ),
    (
      'GET',
      'users/check-username',
      false,
      (r) => r.usernameAvailable(' Example ')
    ),
  ];
  for (final endpoint in endpoints) {
    test(
        '${endpoint.$1} ${endpoint.$2} follows backend envelope and bypasses cache',
        () async {
      adapter.enqueueJson({...authFixture(), 'available': true},
          statusCode: endpoint.$2 == 'auth/register' ? 201 : 200);
      expect(await endpoint.$4(repo), isA<Ok>());
      final request = adapter.requests.single;
      expect(request.method, endpoint.$1);
      expect(request.uri.path, '/api/v1/${endpoint.$2}');
      expect(request.extra['authRequired'], endpoint.$3);
      expect(request.extra['cachePolicy'], CachePolicy.noStore);
      switch (endpoint.$2) {
        case 'auth/register':
          expect(request.data, {
            'name': 'Example',
            'email': 'example@email.test',
            'username': 'example',
            'password': ' secret ',
            'profile_id': 3,
            'photo_url': null
          });
        case 'user/profile' when endpoint.$1 == 'PUT':
          expect(request.data, {'name': 'New name'});
        case 'user/change-email':
          expect(request.data,
              {'current_password': ' exact ', 'email': 'new@email.test'});
        case 'user/change-password':
          expect(
              request.data, {'current_password': ' old ', 'password': ' new '});
        case 'auth/forgot-password':
          expect(request.data, {'email': 'example@email.test'});
        case 'auth/reset-password':
          expect(request.data, {
            'email': 'example@email.test',
            'token': 'reset',
            'password': ' new ',
            'password_confirmation': ' new '
          });
        case 'users/check-username':
          expect(request.queryParameters, {'username': 'example'});
        default:
          break;
      }
    });
  }
  for (final entry in <(int, Matcher)>[
    (401, isA<UnauthorizedFailure>()),
    (403, isA<ForbiddenFailure>()),
    (409, isA<ConflictFailure>()),
    (422, isA<ValidationFailure>()),
    (429, isA<RateLimitedFailure>()),
    (500, isA<ServerFailure>())
  ]) {
    test('HTTP ${entry.$1} maps to a typed auth failure', () async {
      adapter.enqueueJson(
          {
            'success': false,
            'message': 'Action failed',
            'errors': {
              'email': ['Bad email']
            }
          },
          statusCode: entry.$1,
          headers: {
            'retry-after': ['27']
          });
      final result = await repo
          .signIn(const LoginRequest(email: 'a@b.test', password: 'secret'));
      final failure = result.when(ok: (_) => fail('Must fail'), err: (e) => e);
      expect(failure, entry.$2);
      expect(failure.message, 'Action failed');
      if (failure is RateLimitedFailure) expect(failure.retryAfter, 27);
      if (failure is ValidationFailure) {
        expect(failure.fields, {
          'email': ['Bad email']
        });
      }
    });
  }
  test('password setup marker survives boolean backend errors', () async {
    adapter.enqueueJson({
      'success': false,
      'message': 'Reset your password.',
      'errors': {'requires_password_setup': true}
    }, statusCode: 422);
    final failure = (await repo
            .signIn(const LoginRequest(email: 'a@b.test', password: 'secret')))
        .when(ok: (_) => fail('Must fail'), err: (e) => e);
    expect(failure, isA<ValidationFailure>());
    final action = AuthActionException.fromFailure(failure);
    expect(action.code, 'requires-password-setup');
    expect(action.message, 'Reset your password.');
  });
  test('Google conflict tells users to sign into the password account first',
      () {
    expect(AuthActionException.fromFailure(const Failure.conflict()).message,
        'This email already has a password account. Sign in with your password first.');
  });
  for (final bad in <Object?>[
    null,
    [],
    {'success': true},
    {'success': true, 'token': '', 'user': authFixture()['user']},
    {'success': true, 'available': 'yes'}
  ]) {
    test('malformed envelope becomes a failure: $bad', () async {
      adapter.enqueueJson(bad);
      final result = await repo
          .signIn(const LoginRequest(email: 'a@b.test', password: 'secret'));
      expect(result, isA<Err>());
    });
  }
  test('success false at HTTP 200 never creates a session', () async {
    adapter.enqueueJson({'success': false, 'message': 'Cannot authenticate'});
    expect(
        await repo
            .signIn(const LoginRequest(email: 'a@b.test', password: 'secret')),
        isA<Err>());
  });
  test('network and timeout failures are typed', () async {
    adapter.enqueueError();
    expect((await repo.profile()).when(ok: (_) => null, err: (e) => e),
        isA<NetworkFailure>());
    adapter.enqueueError(type: DioExceptionType.receiveTimeout);
    expect((await repo.profile()).when(ok: (_) => null, err: (e) => e),
        isA<TimeoutFailure>());
  });
  test('logs and DTO string representations contain no passwords or tokens',
      () async {
    final logs = <String>[];
    dio.interceptors.add(LoggingInterceptor(log: logs.add));
    adapter.enqueueJson(authFixture());
    final request =
        const LoginRequest(email: 'a@b.test', password: 'private-password');
    final result = await repo.signIn(request);
    final session = result.when(ok: (s) => s, err: (_) => fail('Must succeed'));
    expect([...logs, request.toString(), session.toString()].join(),
        isNot(contains('private-password')));
    expect(
        [...logs, session.toString()].join(), isNot(contains(session.token)));
    expect(
        const ChangePasswordRequest(
                currentPassword: 'private-password',
                password: 'private-password')
            .toString(),
        isNot(contains('private-password')));
    expect(
        const ChangeEmailRequest(
                currentPassword: 'private-password', email: 'x@y.test')
            .toString(),
        isNot(contains('private-password')));
  });
}
