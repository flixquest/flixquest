import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/presentation/session/session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/session_harness.dart';

const login = LoginRequest(email: 'beamlak@example.com', password: 'password');

class DelayedTokens extends MemoryTokens {
  Completer<String?>? pendingRead;
  Completer<void>? pendingWrite;
  @override
  Future<String?> read() => pendingRead?.future ?? super.read();
  @override
  Future<void> write(String token) async {
    await pendingWrite?.future;
    await super.write(token);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionHarness h;
  setUp(() async {
    h = await SessionHarness.create();
  });
  tearDown(() async {
    await h.dispose();
  });
  Future<void> signIn(
      {String token = '7|sanitized-test-token', int id = 7}) async {
    h.adapter.enqueueJson(authFixture(token: token, id: id));
    expect(await h.session.signIn(login), isA<Ok>());
  }

  test('restore without a token presents the landing gate without HTTP',
      () async {
    await h.session.restore();
    expect(h.session.state, const SessionState.guest());
    expect(h.session.gateIdentity.value, null);
    expect(h.adapter.requests, isEmpty);
  });
  test('login securely persists token and publishes Laravel owner', () async {
    await signIn();
    expect(h.tokens.value, '7|sanitized-test-token');
    expect(h.preferences.getString('session.owner'), 'user:7');
    expect(h.session.ownerId.value, 'user:7');
    expect(h.preferences.getString('sanctum_token'), null);
  });
  test('boot validates the stored token with profile and attaches Bearer',
      () async {
    h.tokens.value = 'stored-token';
    h.adapter.enqueueJson(authFixture());
    await h.session.restore();
    expect(h.session.user?.id, 7);
    expect(h.adapter.requests.single.uri.path, '/api/v1/user/profile');
    expect(h.adapter.requests.single.headers['Authorization'],
        'Bearer stored-token');
  });
  test('revoked token at boot clears storage and returns to guest', () async {
    h.tokens.value = 'revoked-token';
    h.adapter.enqueueJson({'success': false, 'message': 'Unauthenticated.'},
        statusCode: 401);
    await h.session.restore();
    expect(h.session.state, const SessionState.guest());
    expect(h.tokens.value, null);
    expect(h.session.ownerId.value, null);
  });
  test(
      'offline boot restores only the cached profile belonging to the stored owner',
      () async {
    await signIn();
    h.adapter.enqueueError();
    await h.session.restore();
    expect(h.session.user?.id, 7);
    await h.preferences.setString('session.owner', 'user:other');
    h.adapter.enqueueError();
    await h.session.restore();
    expect(h.session.user, null);
  });
  test('guest browsing works offline and survives boot without creating a user',
      () async {
    await h.session.enterGuest();
    expect(h.session.gateIdentity.value, 'guest');
    expect(h.session.ownerId.value, null);
    await h.session.restore();
    expect(h.session.state, const SessionState.guest(browsing: true));
    expect(h.adapter.requests, isEmpty);
  });
  test('failed login does not attach or expire an existing token', () async {
    await signIn();
    h.adapter.enqueueJson({'success': false}, statusCode: 401);
    expect(await h.session.signIn(login), isA<Err>());
    expect(h.session.user?.id, 7);
    expect(h.adapter.requests.last.headers['Authorization'], null);
    expect(h.tokens.clears, 0);
  });
  test('protected 401 expires once and never retries', () async {
    await signIn();
    h.adapter.enqueueJson({'success': false}, statusCode: 401);
    await h.session.repository.profile();
    expect(h.session.state, const SessionState.expired());
    expect(h.tokens.value, null);
    final clears = h.tokens.clears;
    await h.session.expire('7|sanitized-test-token');
    expect(h.tokens.clears, clears);
    expect(h.adapter.requests.length, 2);
  });
  test('late rejection for an old token cannot expire a newer login', () async {
    await signIn(token: 'old');
    await signIn(token: 'new', id: 8);
    await h.session.expire('old');
    expect(h.tokens.value, 'new');
    expect(h.session.ownerId.value, 'user:8');
  });
  test('Bearer token is never sent to another origin or a public auth endpoint',
      () async {
    await signIn();
    h.adapter.enqueueJson({'success': true});
    await h.dio.get('https://outside.test/user/profile');
    expect(h.adapter.requests.last.headers['Authorization'], null);
    h.adapter.enqueueJson({'success': true, 'available': true});
    await h.session.repository.usernameAvailable('newname');
    expect(h.adapter.requests.last.headers['Authorization'], null);
  });
  test('successful password change clears the revoked token immediately',
      () async {
    await signIn();
    h.adapter.enqueueJson({'success': true});
    expect(
        await h.session.changePassword(const ChangePasswordRequest(
            currentPassword: 'old', password: 'new')),
        isA<Ok>());
    expect(h.session.state, const SessionState.expired());
    expect(h.tokens.value, null);
  });
  test('failed password change keeps the current session', () async {
    await signIn();
    h.adapter.enqueueJson({'success': false}, statusCode: 422);
    expect(
        await h.session.changePassword(const ChangePasswordRequest(
            currentPassword: 'wrong', password: 'new')),
        isA<Err>());
    expect(h.session.user?.id, 7);
  });
  test('email change publishes the new profile and retains the backend token',
      () async {
    await signIn();
    final body = authFixture();
    (body['user'] as Map)['email'] = 'new@example.com';
    h.adapter.enqueueJson(body);
    await h.session.changeEmail(const ChangeEmailRequest(
        currentPassword: 'password', email: 'new@example.com'));
    expect(h.session.user?.email, 'new@example.com');
    expect(h.tokens.value, isNotNull);
  });
  test(
      'logout clears local state even when its request is offline and signs out Google',
      () async {
    await signIn();
    h.adapter.enqueueError();
    await h.session.signOut();
    expect(h.session.state, const SessionState.guest());
    expect(h.tokens.value, null);
    expect(h.preferences.getJson('session.user'), null);
    expect(h.google.signOuts, 1);
  });
  test('Google cancellation leaves state unchanged and sends no request',
      () async {
    await h.session.restore();
    final result = await h.session.signInWithGoogle();
    expect(result, isA<Ok>());
    expect(
        result.when(
            ok: (value) => value, err: (_) => fail('Cancelled login failed')),
        null);
    expect(h.session.state, const SessionState.guest());
    expect(h.adapter.requests, isEmpty);
  });
  test('Google exchange sends access token and persists the Sanctum session',
      () async {
    h.google.accessToken = 'oauth-token';
    h.adapter.enqueueJson(authFixture());
    expect(await h.session.signInWithGoogle(), isA<Ok>());
    expect(h.adapter.requests.single.data, {'access_token': 'oauth-token'});
    expect(h.tokens.value, '7|sanitized-test-token');
  });
  test('Google conflict leaves tokens empty and returns an actionable failure',
      () async {
    h.google.accessToken = 'oauth-token';
    h.adapter.enqueueJson(
        {'success': false, 'message': 'Password account exists.'},
        statusCode: 409);
    final result = await h.session.signInWithGoogle();
    expect(result.when(ok: (_) => null, err: (e) => e), isA<ConflictFailure>());
    expect(h.tokens.value, null);
  });
  test(
      'delete account wipes only the captured Laravel owner after server success',
      () async {
    await h.dispose();
    final deleted = <String>[];
    h = await SessionHarness.create(deleteLocalData: (owner) async {
      deleted.add(owner);
    });
    await signIn();
    h.adapter.enqueueJson({'success': false}, statusCode: 500);
    expect(await h.session.deleteAccount(), isA<Err>());
    expect(deleted, isEmpty);
    h.adapter.enqueueJson({'success': true});
    expect(await h.session.deleteAccount(), isA<Ok>());
    expect(deleted, ['user:7']);
    expect(h.tokens.value, null);
    expect(h.google.signOuts, 1);
  });
  test('sign out while login is pending prevents stale authentication',
      () async {
    final sent = Completer<void>();
    final released = Completer<void>();
    h.dio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (request, handler) async {
      if (request.path == 'auth/login') {
        sent.complete();
        await released.future;
      }
      handler.next(request);
    }));
    h.adapter.enqueueJson(authFixture());
    final pending = h.session.signIn(login);
    await sent.future;
    await h.session.signOut();
    released.complete();
    expect(await pending, isA<Err>());
    expect(h.tokens.value, null);
    expect(h.session.user, null);
  });
  test('a late secure-storage read cannot overwrite a newer login token',
      () async {
    await h.dispose();
    final tokens = DelayedTokens()..pendingRead = Completer<String?>();
    h = await SessionHarness.create(tokenStore: tokens);
    final restoring = h.session.restore();
    await signIn(token: 'new');
    tokens.pendingRead!.complete('old');
    await restoring;
    expect(h.session.token, 'new');
    expect(h.session.user?.id, 7);
  });
  test(
      'logout during a secure-storage write cannot resurrect the in-memory token',
      () async {
    await h.dispose();
    final tokens = DelayedTokens()..pendingWrite = Completer<void>();
    h = await SessionHarness.create(tokenStore: tokens);
    final writing = Completer<void>();
    h.dio.interceptors.add(InterceptorsWrapper(onResponse: (response, handler) {
      writing.complete();
      handler.next(response);
    }));
    h.adapter.enqueueJson(authFixture());
    final pending = h.session.signIn(login);
    await writing.future;
    final logout = h.session.signOut();
    tokens.pendingWrite!.complete();
    await pending;
    await logout;
    expect(h.session.token, null);
    expect(tokens.value, null);
    expect(h.session.user, null);
  });
  test('a delayed logout response cannot clear a newer login', () async {
    await signIn(token: 'old');
    final sent = Completer<void>();
    final release = Completer<void>();
    h.dio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (request, handler) async {
      if (request.path == 'auth/logout') {
        sent.complete();
        await release.future;
      }
      handler.next(request);
    }));
    final logout = h.session.signOut();
    await sent.future;
    await signIn(token: 'new', id: 8);
    h.adapter.enqueueJson({'success': true});
    release.complete();
    await logout;
    expect(h.session.token, 'new');
    expect(h.session.user?.id, 8);
    expect(h.google.signOuts, 0);
  });
  test('disabled stored accounts are cleared on restore', () async {
    h.tokens.value = 'disabled';
    h.adapter.enqueueJson({'success': false}, statusCode: 403);
    await h.session.restore();
    expect(h.session.state, const SessionState.guest());
    expect(h.tokens.value, null);
  });
  test(
      'profile edits persist the typed profile and do not leave stale data after logout',
      () async {
    await signIn();
    final profile = authFixture();
    (profile['user'] as Map)['name'] = 'Edited name';
    h.adapter.enqueueJson(profile);
    await h.session
        .updateProfile(const UpdateProfileRequest(name: 'Edited name'));
    expect(h.session.user?.name, 'Edited name');
    expect(
        (h.preferences.getJson('session.user') as Map)['name'], 'Edited name');
    h.adapter.enqueueJson({'success': true});
    await h.session.signOut();
    expect(h.preferences.getJson('session.user'), null);
  });
}
