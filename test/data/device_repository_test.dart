import 'package:flixquest/core/cache/cache_policy.dart';
import 'package:flixquest/core/error/result.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:flixquest/data/repositories/device_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionHarness h;
  setUp(() async => h = await SessionHarness.create());
  tearDown(() => h.dispose());

  test(
      'device registration sends authenticated snake-case fields without caching',
      () async {
    h.adapter.enqueueJson(authFixture());
    await h.session.signIn(
        const LoginRequest(email: 'a@example.com', password: 'password'));
    h.adapter.enqueueJson(
        {'success': true, 'message': 'Device registered successfully.'});
    expect(
        await DeviceRepository(h.dio)
            .register('fcm-token', 'tv', '4.3.0', owner: 'user:7'),
        isA<Ok<void>>());
    final request = h.adapter.requests.last;
    expect(request.uri.path, '/api/v1/devices/register');
    expect(request.method, 'POST');
    expect(request.headers['Authorization'], 'Bearer 7|sanitized-test-token');
    expect(request.data,
        {'fcm_token': 'fcm-token', 'platform': 'tv', 'app_version': '4.3.0'});
    expect(request.extra['cachePolicy'], CachePolicy.noStore);
  });
  test(
      'queued registration for a previous owner cannot use the current account',
      () async {
    h.adapter.enqueueJson(authFixture(id: 8));
    await h.session.signIn(
        const LoginRequest(email: 'a@example.com', password: 'password'));
    expect(
        await DeviceRepository(h.dio)
            .register('token', 'android', '4.3.0', owner: 'user:7'),
        isA<Err<void>>());
    expect(h.adapter.requests.length, 1);
  });
}
