import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flixquest/core/error/failure.dart';
import 'package:flixquest/data/ads/ads_policy.dart';
import 'package:flixquest/data/models/billing.dart';
import 'package:flixquest/data/repositories/billing_repository.dart';
import 'package:flixquest/presentation/billing/plus_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

final _start = DateTime.utc(2026, 10, 24, 7);

PlusAccount _account({
  bool adFree = true,
  DateTime? expires,
  DateTime? serverTime,
  int spendable = 800,
}) =>
    PlusAccount(
      entitlements: PlusEntitlement(
        adFree: adFree,
        startsAt: adFree ? _start : null,
        expiresAt:
            adFree ? (expires ?? _start.add(const Duration(days: 31))) : null,
        revision: 1,
      ),
      serverTime: serverTime ?? _start,
      wallet: WalletBalance(spendableCents: spendable, balanceCents: spendable),
      renewal: const PlusRenewal(mode: 'wallet', autoRenew: true),
    );

WalletTopup _topup(String status) => WalletTopup(
      id: 'topup-1',
      status: status,
      amountCents: 1000,
      nextAction: status == 'pending' ? 'open_checkout' : 'none',
      checkoutUrl: 'https://nowpayments.io/payment/?iid=1',
    );

/// Answers each call from a queue, so a test decides when (and whether) the
/// network replies.
class _FakeBilling extends BillingRepository {
  _FakeBilling() : super(Dio());

  final walletCalls = <Completer<PlusAccount>>[];

  /// Which endpoint each call in [walletCalls] went to.
  final endpoints = <String>[];
  final topupKeys = <String>[];
  final topupAnswers = <FutureOr<WalletTopup> Function()>[];
  final checks = <String>[];
  WalletTopup Function()? onCheck;
  PlusAccount Function()? onRedeem;

  @override
  Future<PlusCatalog> plans() async => const PlusCatalog(
        purchasesEnabled: true,
        plans: [
          PlusPlan(
              code: 'plus_monthly',
              amountCents: 200,
              intervalDays: 31,
              termsVersion: '2026-10-24')
        ],
      );

  @override
  Future<PlusAccount> wallet() => _answer('wallet');

  @override
  Future<PlusAccount> entitlements() => _answer('entitlements');

  Future<PlusAccount> _answer(String endpoint) {
    final call = Completer<PlusAccount>();
    walletCalls.add(call);
    endpoints.add(endpoint);
    return call.future;
  }

  @override
  Future<WalletTopup> createTopup(
      {required int amountCents,
      required String idempotencyKey,
      bool activatePlus = false,
      String? termsVersion}) async {
    topupKeys.add(idempotencyKey);
    return topupAnswers.removeAt(0)();
  }

  @override
  Future<WalletTopup> topup(String id) async {
    checks.add('status');
    return onCheck!();
  }

  @override
  Future<WalletTopup> reconcileTopup(String id) async {
    checks.add('reconcile');
    return onCheck!();
  }

  @override
  Future<(PlusAccount, CouponRedemption)> redeemCoupon(String code) async =>
      (onRedeem!(), const CouponRedemption(type: 'free_plus', freeDays: 14));
}

void main() {
  late _FakeBilling billing;
  late FakeKvStore store;
  late ValueNotifier<String?> owner;
  late DateTime now;
  late PlusController controller;

  PlusController build() => PlusController(
        repository: billing,
        store: store,
        owner: owner,
        now: () => now,
        pollInterval: const Duration(milliseconds: 5),
        pollWindow: const Duration(seconds: 5),
      );

  setUp(() {
    billing = _FakeBilling();
    store = FakeKvStore();
    owner = ValueNotifier<String?>('user:1');
    now = _start;
    AdsPolicy.update(adFree: false);
    controller = build();
  });

  tearDown(() {
    controller.dispose();
    AdsPolicy.update(adFree: false);
  });

  test('a verified entitlement turns ads off, and signing out turns them on',
      () async {
    await controller.start();
    billing.walletCalls.single.complete(_account());
    await controller.refresh();
    await pumpEventQueue();

    expect(controller.adFree, isTrue);
    expect(AdsPolicy.adFree, isTrue);

    owner.value = null;

    expect(controller.adFree, isFalse);
    expect(AdsPolicy.adFree, isFalse);
  });

  test('an answer for the previous account never reaches the next one',
      () async {
    await controller.start();
    final forFirst = billing.walletCalls.single;

    owner.value = 'user:2';
    forFirst.complete(_account());
    await pumpEventQueue();

    expect(controller.owner, 'user:2');
    expect(controller.adFree, isFalse);
    expect(AdsPolicy.adFree, isFalse);
    expect(billing.walletCalls, hasLength(2));
  });

  test('an account that never used Plus is not given a wallet by a check',
      () async {
    await controller.start();
    expect(billing.endpoints, ['entitlements']);
    billing.walletCalls.single.complete(_account(adFree: false));
    await pumpEventQueue();

    unawaited(controller.refresh(full: true));
    await pumpEventQueue();
    expect(billing.endpoints, ['entitlements', 'wallet']);
    billing.walletCalls.last.complete(_account());
    await pumpEventQueue();

    // A member's balance stays current with the background checks.
    unawaited(controller.refresh());
    await pumpEventQueue();
    expect(billing.endpoints.last, 'wallet');
  });

  test('guests get no access and make no account request', () async {
    owner.value = null;
    await controller.start();

    expect(billing.walletCalls, isEmpty);
    expect(controller.adFree, isFalse);
  });

  test('paid access ends at its expiry even without the network', () async {
    await controller.start();
    billing.walletCalls.single
        .complete(_account(expires: _start.add(const Duration(hours: 2))));
    await pumpEventQueue();
    expect(controller.adFree, isTrue);

    now = _start.add(const Duration(hours: 2, seconds: 1));

    expect(controller.adFree, isFalse);
  });

  group('offline cache', () {
    Future<void> verifyThenRestart() async {
      await controller.start();
      billing.walletCalls.single.complete(_account());
      await pumpEventQueue();
      controller.dispose();
      AdsPolicy.update(adFree: false);
      billing.walletCalls.clear();
      controller = build();
    }

    test('restores the same account before the network answers', () async {
      await verifyThenRestart();
      now = _start.add(const Duration(hours: 3));

      await controller.start();

      expect(controller.showingCached, isTrue);
      expect(controller.adFree, isTrue);
      expect(AdsPolicy.adFree, isTrue);
    });

    test('lapses 24 hours after the last check', () async {
      await verifyThenRestart();
      now = _start.add(const Duration(hours: 24, minutes: 1));

      await controller.start();

      expect(controller.adFree, isFalse);
      expect(AdsPolicy.adFree, isFalse);
    });

    test('belongs to its account only', () async {
      await verifyThenRestart();
      owner.value = 'user:2';

      await controller.start();

      expect(controller.account, isNull);
      expect(controller.adFree, isFalse);
    });

    test('is dropped when Laravel says the session has no access', () async {
      await verifyThenRestart();
      await controller.start();
      billing.walletCalls.single
          .completeError(const BillingError(Failure.unauthorized()));
      await pumpEventQueue();

      expect(controller.adFree, isFalse);
      expect(store.getJson('plus.account'), isNull);
    });

    test('an outage keeps the cached access', () async {
      await verifyThenRestart();
      await controller.start();
      billing.walletCalls.single
          .completeError(const BillingError(Failure.network()));
      await pumpEventQueue();

      expect(controller.adFree, isTrue);
      expect(controller.error?.offline, isTrue);
    });
  });

  test('retrying a top-up whose answer was lost reuses its key', () async {
    await controller.start();
    billing.walletCalls.single.complete(_account(adFree: false, spendable: 0));
    await pumpEventQueue();
    billing.topupAnswers.addAll([
      () => throw const BillingError(Failure.timeout()),
      () => _topup('pending'),
      () => _topup('pending'),
    ]);

    await expectLater(
        controller.startTopup(1000), throwsA(isA<BillingError>()));
    await controller.startTopup(1000);
    await controller.startTopup(1000);

    expect(billing.topupKeys[0], billing.topupKeys[1]);
    expect(billing.topupKeys[2], isNot(billing.topupKeys[1]));
    controller.dismissTopup();
  });

  test('a top-up is followed until Laravel credits it', () async {
    await controller.start();
    billing.walletCalls.single.complete(_account(adFree: false, spendable: 0));
    await pumpEventQueue();
    var answers = 0;
    billing.onCheck =
        () => ++answers < 5 ? _topup('pending') : _topup('settled');
    billing.topupAnswers.add(() => _topup('pending'));

    await controller.startTopup(1000, activatePlus: true);
    while (billing.walletCalls.length < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    billing.walletCalls.last.complete(_account());
    await pumpEventQueue();

    expect(controller.topup!.settled, isTrue);
    expect(billing.checks, contains('reconcile'));
    expect(controller.adFree, isTrue);
    // Plus that started in this session is celebrated once.
    expect(controller.celebrationPending, isTrue);
    controller.takeCelebration();
    expect(controller.celebrationPending, isFalse);
  });

  test('opening the app as a member is not a celebration', () async {
    await controller.start();
    billing.walletCalls.single.complete(_account());
    await pumpEventQueue();

    expect(controller.adFree, isTrue);
    expect(controller.celebrationPending, isFalse);
  });

  test('a code that grants Plus is celebrated', () async {
    await controller.start();
    billing.walletCalls.single.complete(_account(adFree: false));
    await pumpEventQueue();
    billing.onRedeem = _account;

    final redemption = await controller.redeemCoupon('WELCOME');

    expect(redemption.freeDays, 14);
    expect(controller.adFree, isTrue);
    expect(AdsPolicy.adFree, isTrue);
    expect(controller.celebrationPending, isTrue);
  });

  test('suggests Plus only while it is on sale and not owned', () async {
    await controller.start();
    await pumpEventQueue();
    expect(controller.shouldSuggest, isTrue);

    billing.walletCalls.single.complete(_account());
    await pumpEventQueue();
    expect(controller.shouldSuggest, isFalse);
  });

  test('coming back soon after a check does not ask Laravel again', () async {
    await controller.start();
    billing.walletCalls.single.complete(_account());
    await pumpEventQueue();

    controller.onPause();
    now = now.add(const Duration(minutes: 1));
    controller.onResume();
    await pumpEventQueue();
    expect(billing.walletCalls, hasLength(1));

    controller.onPause();
    now = now.add(PlusController.resumeRecheckAfter);
    controller.onResume();
    await pumpEventQueue();
    expect(billing.walletCalls, hasLength(2));
  });

  test('access only restored from the cache is checked again on resume',
      () async {
    await controller.start();
    billing.walletCalls.single.complete(_account());
    await pumpEventQueue();
    controller.dispose();
    billing = _FakeBilling();
    controller = build();
    await controller.start();
    billing.walletCalls.single
        .completeError(const BillingError(Failure.network()));
    await pumpEventQueue();

    controller.onPause();
    controller.onResume();
    await pumpEventQueue();

    expect(billing.walletCalls, hasLength(2));
  });

  test('server time, not the device clock, decides expiry', () async {
    // The device runs two hours behind Laravel.
    now = _start.subtract(const Duration(hours: 2));
    await controller.start();
    billing.walletCalls.single
        .complete(_account(expires: _start.add(const Duration(hours: 1))));
    await pumpEventQueue();
    expect(controller.adFree, isTrue);

    // One hour and one second later on the device is past expiry on Laravel.
    now = now.add(const Duration(hours: 1, seconds: 1));

    expect(controller.adFree, isFalse);
  });
}
