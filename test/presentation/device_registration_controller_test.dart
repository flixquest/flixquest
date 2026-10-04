import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/data/repositories/device_repository.dart';
import 'package:flixquest/presentation/notifications/device_registration_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_push_messaging.dart';
import '../support/session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionHarness h;
  late FakePushMessaging push;
  late DeviceRegistrationController controller;
  DeviceRegistrationController create() => DeviceRegistrationController(
      DeviceRepository(h.dio), h.session, h.preferences, push,
      platform: 'android', appVersion: '4.3.0');
  setUp(() async {
    h = await SessionHarness.create();
    push = FakePushMessaging();
    controller = create();
  });
  tearDown(() async {
    controller.dispose();
    await push.dispose();
    await h.dispose();
  });
  void registered() => h.adapter.enqueueJson({'success': true});

  Future<void> login({int id = 7, bool register = false}) async {
    h.adapter.enqueueJson(authFixture(id: id, token: 'auth-$id'));
    if (register) registered();
    expect(
        await h.session.signIn(
            const LoginRequest(email: 'a@example.com', password: 'password')),
        isA<Ok>());
  }

  test(
      'boot registers the signed-in device and repeated resumes avoid duplicates',
      () async {
    await login();
    registered();
    await controller.boot();
    expect(h.adapter.requests.last.uri.path, '/api/v1/devices/register');
    await controller.onResume();
    await controller.onResume();
    expect(h.adapter.requests.length, 2);
    expect(h.preferences.getJson('notifications.device.registration'), {
      'owner': 'user:7',
      'token': 'device-token',
      'platform': 'android',
      'app_version': '4.3.0',
    });
  });
  test(
      'guests never read or upload an FCM token, and login registers immediately',
      () async {
    await h.session.enterGuest();
    await controller.boot();
    push.tokens.add('refreshed-guest-token');
    await controller.onResume();
    expect(h.adapter.requests, isEmpty);
    expect(push.tokenReads, 0);
    await login(register: true);
    await controller.onResume();
    expect(h.adapter.requests.last.data['fcm_token'], 'refreshed-guest-token');
  });

  test(
      'token refresh uploads the new token once and a cold boot re-registers it',
      () async {
    await login();
    registered();
    await controller.boot();
    registered();
    push.token = 'new-token';
    push.tokens.add('new-token');
    await controller.onResume();
    expect(h.adapter.requests.last.data['fcm_token'], 'new-token');
    push.tokens.add('new-token');
    await controller.onResume();
    expect(h.adapter.requests.length, 3);
    controller.dispose();
    controller = create();
    registered();
    await controller.boot();
    expect(h.adapter.requests.length, 4);
    expect(h.adapter.requests.last.data['fcm_token'], 'new-token');
  });

  test('unavailable tokens and failed HTTP registration retry on resume',
      () async {
    await login();
    push.token = null;
    await controller.boot();
    expect(h.adapter.requests.length, 1);
    push.token = 'device-token';
    h.adapter.enqueueError();
    await controller.onResume();
    expect(h.preferences.getJson('notifications.device.registration'), isNull);
    registered();
    await controller.onResume();
    expect(h.adapter.requests.length, 3);
    expect(
        h.preferences.getJson('notifications.device.registration'), isNotNull);
  });

  test('an account change during SDK token lookup registers only the new owner',
      () async {
    await login();
    final pending = Completer<String?>();
    push.pendingToken = pending.future;
    final work = controller.boot();
    await login(id: 8, register: true);
    pending.complete('device-token');
    await work;
    expect(h.adapter.requests.length, 3);
    expect(h.adapter.requests.last.headers['Authorization'], 'Bearer auth-8');
    expect(
        (h.preferences.getJson('notifications.device.registration')
            as Map)['owner'],
        'user:8');
  });

  test(
      'switching owners transfers the token and returning to the first owner registers again',
      () async {
    await login();
    registered();
    await controller.boot();
    await login(id: 8, register: true);
    await controller.onResume();
    expect(h.adapter.requests.last.headers['Authorization'], 'Bearer auth-8');
    await login(id: 7, register: true);
    await controller.onResume();
    expect(h.adapter.requests.last.headers['Authorization'], 'Bearer auth-7');
    expect(h.adapter.requests.length, 6);
  });

  test(
      'disposed registration ignores a late token and future SDK/session events',
      () async {
    await login();
    final pending = Completer<String?>();
    push.pendingToken = pending.future;
    final work = controller.boot();
    controller.dispose();
    pending.complete('late-token');
    await work;
    push.tokens.add('another-token');
    await controller.onResume();
    expect(h.adapter.requests.length, 1);
    expect(h.preferences.getJson('notifications.device.registration'), isNull);
  });
  test(
      'an identical refresh during registration does not upload the token twice',
      () async {
    await login();
    registered();
    final entered = Completer<void>();
    final release = Completer<void>();
    h.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      if (request.path == 'devices/register') {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      }
      handler.next(request);
    }));
    final work = controller.boot();
    await entered.future;
    registered();
    push.tokens.add('device-token');
    release.complete();
    await work;
    expect(h.adapter.requests.length, 2);
  });
  test(
      'a newer refresh during HTTP registration wins over the old acknowledgement',
      () async {
    await login();
    registered();
    registered();
    final entered = Completer<void>();
    final release = Completer<void>();
    h.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      if (request.path == 'devices/register' && !entered.isCompleted) {
        entered.complete();
        await release.future;
      }
      handler.next(request);
    }));
    final work = controller.boot();
    await entered.future;
    push.tokens.add('newest-token');
    release.complete();
    await work;
    expect(h.adapter.requests.length, 3);
    expect(h.adapter.requests.last.data['fcm_token'], 'newest-token');
    expect(
        (h.preferences.getJson('notifications.device.registration')
            as Map)['token'],
        'newest-token');
  });
}
