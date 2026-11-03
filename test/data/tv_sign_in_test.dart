import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/data/models/tv_sign_in.dart';
import 'package:flixquest/presentation/session/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

const _code = {
  'success': true,
  'device_code': 'device-secret',
  'user_code': 'BCDF-GHJK',
  'verification_url': 'https://backend.flix.quest/tv',
  'verification_url_complete': 'https://backend.flix.quest/tv/BCDF-GHJK',
  'expires_at': '2026-10-31T12:10:00.000000Z',
  'interval': 5,
};

void main() {
  test('a TV code carries what the screen shows and how often to check',
      () async {
    final harness = await SessionHarness.create();
    addTearDown(harness.dispose);
    harness.adapter.enqueueJson(_code, statusCode: 201);

    final code = (await harness.session.startTvSignIn())
        .when(ok: (code) => code, err: (f) => fail('$f'));

    expect(code.userCode, 'BCDF-GHJK');
    expect(
        code.completeUrl.toString(), 'https://backend.flix.quest/tv/BCDF-GHJK');
    expect('${code.url.host}${code.url.path}', 'backend.flix.quest/tv');
    expect(code.interval, const Duration(seconds: 5));
    expect(harness.adapter.requests.single.uri.path, '/api/v1/auth/tv/codes');
  });

  test('waiting changes nothing; the approval signs this TV in', () async {
    final harness = await SessionHarness.create();
    addTearDown(harness.dispose);
    await harness.session.restore();
    harness.adapter
      ..enqueueJson({'success': true, 'status': 'pending'})
      ..enqueueJson({'success': true, 'status': 'approved', ...authFixture()});

    final waiting = await harness.session.checkTvSignIn('device-secret');
    expect(waiting.when(ok: (check) => check.status, err: (f) => f),
        TvSignInStatus.pending);
    expect(harness.session.state, isA<GuestSession>());
    expect(harness.tokens.value, isNull);

    final approved = await harness.session.checkTvSignIn('device-secret');
    final check = approved.when(ok: (check) => check, err: (f) => fail('$f'));
    expect(check.status, TvSignInStatus.approved);
    expect(check.session?.user.id, 7);
    expect(harness.session.user?.id, 7);
    expect(harness.tokens.value, '7|sanitized-test-token');
    expect(harness.adapter.requests.last.data,
        containsPair('device_code', 'device-secret'));
  });

  test('a code turned down on the phone, or expired, says so', () async {
    final harness = await SessionHarness.create();
    addTearDown(harness.dispose);
    harness.adapter
      ..enqueueJson({'success': true, 'status': 'denied'})
      ..enqueueJson({'success': true, 'status': 'expired'});

    Future<Object> status() async =>
        (await harness.session.checkTvSignIn('device-secret'))
            .when(ok: (check) => check.status, err: (f) => f);

    expect(await status(), TvSignInStatus.denied);
    expect(await status(), TvSignInStatus.expired);
  });

  test('a device-limit refusal comes back to retry with a device signed out',
      () async {
    final harness = await SessionHarness.create();
    addTearDown(harness.dispose);
    harness.adapter
      ..enqueueJson({
        'success': false,
        'message': 'This account is signed in on 1 device.',
        'code': 'device_limit_reached',
        'limit': 1,
        'devices': [
          {'id': 4, 'name': 'Pixel 9', 'platform': 'android', 'current': false},
        ],
      }, statusCode: 409)
      ..enqueueJson({'success': true, 'status': 'approved', ...authFixture()});

    final refused = await harness.session.checkTvSignIn('device-secret');
    expect(refused.when(ok: (_) => null, err: (f) => f),
        isA<DeviceLimitFailure>());

    final retried = await harness.session
        .checkTvSignIn('device-secret', replaceDeviceId: 4);
    expect(retried.when(ok: (check) => check.status, err: (f) => f),
        TvSignInStatus.approved);
    expect(harness.adapter.requests.last.data,
        containsPair('replace_device_id', 4));
  });
}
