import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flixquest/data/ads/ads_policy.dart';
import 'package:flixquest/data/models/billing.dart';
import 'package:flixquest/data/repositories/billing_repository.dart';
import 'package:flixquest/mobile/screens/plus_payment_screen.dart';
import 'package:flixquest/mobile/screens/plus_screen.dart';
import 'package:flixquest/mobile/screens/wallet_screen.dart';
import 'package:flixquest/mobile/widgets/plus_card.dart';
import 'package:flixquest/mobile/widgets/plus_sheets.dart';
import 'package:flixquest/presentation/billing/plus_controller.dart';
import 'package:flixquest/tv/screens/tv_plus_screen.dart';
import 'package:flixquest/tv/screens/tv_redeem_code_screen.dart';
import 'package:flixquest/widgets/plus/plus_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/fakes.dart';
import 'support/tv_localization.dart';

final _now = DateTime.utc(2026, 10, 24, 7);

PlusAccount _member() => PlusAccount(
      entitlements: PlusEntitlement(
        adFree: true,
        startsAt: _now.subtract(const Duration(days: 8)),
        expiresAt: _now.add(const Duration(days: 23)),
      ),
      serverTime: _now,
      wallet: const WalletBalance(
          id: 'wallet-1',
          balanceCents: 800,
          spendableCents: 800,
          periodsFundable: 4),
      renewal: PlusRenewal(
        mode: 'wallet',
        autoRenew: true,
        nextChargeCents: 200,
        nextChargeAt: _now.add(const Duration(days: 23)),
        currentTermsVersion: '2026-10-24',
      ),
    );

PlusAccount _free({int spendable = 0}) => PlusAccount(
      serverTime: _now,
      wallet: WalletBalance(
          id: 'wallet-1',
          balanceCents: spendable,
          spendableCents: spendable,
          periodsFundable: spendable ~/ 200),
    );

/// A viewer with $1 of credit and a 50% code waiting for two periods.
PlusAccount _discounted() => _free(spendable: 100).copyWith(
      renewal: const PlusRenewal(
        discount: PlusDiscount(
            type: 'percent_off', percentOff: 50, periodsRemaining: 2),
      ),
    );

const _pending = WalletTopup(
  id: 'topup-1',
  status: 'pending',
  amountCents: 1000,
  activatePlus: true,
  checkoutStep: 'choose_coin',
);

const _usdt = PayCoin(
  code: 'usdttrc20',
  ticker: 'USDT',
  name: 'Tether USD',
  network: 'trx',
  networkLabel: 'Tron (TRC-20)',
  popular: true,
);

const _xrp = PayCoin(
  code: 'xrp',
  ticker: 'XRP',
  name: 'Ripple',
  network: 'xrp',
  networkLabel: 'XRP Ledger',
  extraId: 'destination_tag',
);

WalletTopup _sending(PayCoin coin, {String step = 'send'}) => _pending.copyWith(
      checkoutStep: step,
      status: step == 'send_remaining' ? 'partially_paid' : 'pending',
      payment: TopupPayment(
        id: '6000000001',
        status: step == 'send_remaining' ? 'partially_paid' : 'waiting',
        coin: coin,
        amount: '10.0412',
        paid: step == 'send_remaining' ? '6' : '0',
        remaining: step == 'send_remaining' ? '4.0412' : null,
        address: 'TXYZexampledepositaddress000',
        extraId: coin.extraId == null ? null : '482910',
        expiresAt: DateTime.now().add(const Duration(minutes: 20)),
      ),
    );

class _Billing extends BillingRepository {
  _Billing(this.account) : super(Dio());

  PlusAccount account;

  @override
  Future<PlusCatalog> plans() async => const PlusCatalog(
        purchasesEnabled: true,
        plans: [
          PlusPlan(
              code: 'plus_monthly',
              amountCents: 200,
              intervalDays: 31,
              termsVersion: '2026-10-24'),
        ],
      );

  @override
  Future<PlusAccount> wallet() async => account;

  @override
  Future<PlusAccount> entitlements() async => account;

  @override
  Future<WalletHistoryPage> transactions({String? cursor}) async =>
      WalletHistoryPage([
        WalletTransaction(
          id: '2',
          type: 'plus_period',
          amountCents: -200,
          balanceAfterCents: 800,
          periodStartsAt: _now,
          periodEndsAt: _now.add(const Duration(days: 31)),
          createdAt: _now,
        ),
        WalletTransaction(
            id: '1',
            type: 'topup',
            amountCents: 1000,
            balanceAfterCents: 1000,
            createdAt: _now),
      ], null);

  /// What the provider says about the followed top-up.
  WalletTopup current = _pending;
  int checks = 0;
  final paid = <String>[];

  @override
  Future<WalletTopup> topup(String id) async {
    checks++;
    return current;
  }

  @override
  Future<WalletTopup> reconcileTopup(String id) async {
    checks++;
    return current;
  }

  @override
  Future<List<PayCoin>> coins() async => const [_usdt, _xrp];

  @override
  Future<WalletTopup> payTopup(String id, String coin,
      {bool emailReceipt = false}) async {
    paid.add(coin);
    return current = _sending(coin == 'xrp' ? _xrp : _usdt);
  }

  int links = 0;

  @override
  Future<({Uri url, DateTime expiresAt})> topupLink() async {
    links++;
    return (
      url: Uri.parse('https://backend.flix.quest/plus/topup/link-$links'),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
    );
  }

  final redeemed = <String>[];

  @override
  Future<(PlusAccount, CouponRedemption)> redeemCoupon(String code) async {
    redeemed.add(code);
    return (_member(), const CouponRedemption(type: 'free_plus', freeDays: 14));
  }
}

void main() {
  initializeTvTranslations();

  late ValueNotifier<String?> owner;
  late PlusController plus;
  late _Billing billing;

  Future<PlusController> controllerFor(PlusAccount? account) async {
    owner = ValueNotifier<String?>(account == null ? null : 'user:1');
    final controller = PlusController(
      repository: billing = _Billing(account ?? _free()),
      store: FakeKvStore(),
      owner: owner,
      now: () => _now,
      pollInterval: const Duration(hours: 1),
    );
    await controller.start();
    await controller.refresh(full: true);
    await controller.refreshCatalog();
    return controller;
  }

  /// Unmounts the screens, then stops the controller's timers, so the test
  /// ends with none pending.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    plus.dispose();
    AdsPolicy.update(adFree: false);
  }

  Future<void> pump(WidgetTester tester, Widget child,
      {Size size = const Size(390, 844), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<PlusController>.value(
      value: plus,
      child: MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: child,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1500));
  }

  for (final (name, account) in <(String, PlusAccount? Function())>[
    ('a member', _member),
    ('a viewer with a balance', () => _free(spendable: 600)),
    ('a viewer without Plus', _free),
    ('a guest', () => null),
  ]) {
    for (final (label, size, scale) in <(String, Size, double)>[
      ('phone', const Size(390, 844), 1.0),
      ('small phone with large text', const Size(320, 640), 1.3),
    ]) {
      testWidgets('the Plus page lays out for $name on a $label',
          (tester) async {
        plus = await tester.runAsync(() => controllerFor(account()))
            as PlusController;
        await pump(tester, const Scaffold(body: PlusScreen()),
            size: size, textScale: scale);

        expect(tester.takeException(), isNull);
        expect(find.text('FlixQuest Plus'), findsWidgets);
        await done(tester);
      });
    }
  }

  testWidgets('a member sees days left and the renewal date', (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_member())) as PlusController;
    await pump(tester, const PlusScreen());

    expect(find.text('23'), findsOneWidget);
    expect(find.text("You're ad-free"), findsOneWidget);
    expect(find.textContaining('Next renewal: \$2.00'), findsOneWidget);
    await done(tester);
  });

  testWidgets('My FlixQuest shows the member card and the invitation',
      (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_member())) as PlusController;
    await pump(
        tester,
        const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: PlusCard())));
    expect(tester.takeException(), isNull);
    expect(find.text("You're ad-free"), findsOneWidget);

    await done(tester);
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    await pump(
        tester,
        const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: PlusCard())),
        size: const Size(320, 640),
        textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Subscribe to Plus to get rid of ads'), findsOneWidget);
    await done(tester);
  });

  testWidgets('the wallet lists periods and top-ups', (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_member())) as PlusController;
    await pump(tester, const WalletScreen());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Plus period'), findsOneWidget);
    expect(find.text('+\$10.00'), findsOneWidget);
    expect(find.text('−\$2.00'), findsOneWidget);
    await done(tester);
  });

  /// Everything on one screen, so no row is left unbuilt below the fold.
  const tall = Size(390, 2600);

  testWidgets('the checkout lists coins, then shows the address to pay',
      (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    plus.followTopup(_pending);
    await tester.runAsync(plus.loadCoins);
    await pump(tester, const PlusPaymentScreen(),
        size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);

    await pump(tester, const PlusPaymentScreen(), size: tall);
    expect(find.text('Choose a coin'), findsWidgets);
    expect(find.text('Popular'.toUpperCase()), findsOneWidget);
    expect(find.text('Tron (TRC-20)'), findsOneWidget);

    // Search narrows the list by name, ticker or network.
    await tester.enterText(find.byType(TextField), 'ledger');
    await tester.pump();
    expect(find.text('USDT'), findsNothing);
    expect(find.text('XRP'), findsWidgets);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    await tester.tap(find.text('USDT'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(plus.topup?.payment?.coin.code, 'usdttrc20');
    expect(find.text('Send 10.0412 USDT'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
        find.textContaining('TXYZexampledepositaddress000', findRichText: true),
        findsOneWidget);
    expect(
        find.text('Send only USDT on Tron (TRC-20). '
            'Another coin or network can be lost.'),
        findsOneWidget);
    expect(find.text('Check payment'), findsOneWidget);
    expect(find.textContaining('Amount held for'), findsOneWidget);
    expect(find.text('Open in wallet app'), findsNothing);

    // The send screen fits a small phone with large text too.
    await pump(tester, const PlusPaymentScreen(),
        size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);

    // Back to the list, and the first coin is still on offer.
    await pump(tester, const PlusPaymentScreen(), size: tall);
    await tester.tap(find.text('Pay with a different coin'));
    await tester.pump();
    expect(find.text('Keep paying with USDT'), findsOneWidget);
    expect(find.text('XRP'), findsWidgets);
    await done(tester);
  });

  testWidgets('a memo coin and a partly paid top-up say what is still needed',
      (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    plus.followTopup(_sending(_xrp));
    await pump(tester, const PlusPaymentScreen(),
        size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await pump(tester, const PlusPaymentScreen(), size: tall);
    expect(find.text('Destination tag (required)'), findsOneWidget);
    expect(find.textContaining('482910', findRichText: true), findsOneWidget);
    expect(find.textContaining('Include the destination tag'), findsOneWidget);

    plus.followTopup(_sending(_usdt, step: 'send_remaining'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Send the rest'), findsOneWidget);
    expect(find.text('Remaining amount'), findsOneWidget);
    expect(find.textContaining('4.0412', findRichText: true), findsWidgets);
    expect(find.text('Pay with a different coin'), findsNothing);
    expect(find.textContaining('Amount held for'), findsNothing);

    final confirming = _sending(_usdt);
    plus.followTopup(confirming.copyWith(
        checkoutStep: 'confirming',
        payment:
            confirming.payment!.copyWith(status: 'confirming', address: null)));
    await tester.pump();
    expect(find.text('Confirming your \$10.00 payment'), findsOneWidget);
    expect(find.textContaining('confirming on Tron (TRC-20)'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await done(tester);
  });

  testWidgets('checks slow down after two minutes instead of stopping',
      (tester) async {
    final billing = _Billing(_free());
    owner = ValueNotifier<String?>('user:1');
    plus = PlusController(
      repository: billing,
      store: FakeKvStore(),
      owner: owner,
      now: () => tester.binding.clock.now(),
    );
    plus.followTopup(_pending);

    await tester.pump(const Duration(minutes: 2));
    final fast = billing.checks;
    expect(fast, greaterThan(20));
    await tester.pump(const Duration(minutes: 1));
    expect(billing.checks - fast, inInclusiveRange(3, 5));
    expect(plus.topupWatchExpired, isFalse);

    await tester.pump(const Duration(minutes: 30));
    expect(plus.topupWatchExpired, isTrue);
    final last = billing.checks;
    await tester.pump(const Duration(minutes: 5));
    expect(billing.checks, last);
    await done(tester);
  });

  testWidgets('Android TV shows a QR code that opens the phone top-up page',
      (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    for (final size in const [Size(1920, 1080), Size(960, 540)]) {
      await pump(tester, const TvPlusScreen(), size: size);
      expect(tester.takeException(), isNull);
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr, isNotNull);
      expect(find.text('Add funds from your phone'), findsOneWidget);
      expect(find.text('New code'), findsOneWidget);
    }

    // The phone started paying: the TV waits for it, without a code.
    plus.followTopup(_pending);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Finish paying on your phone'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Once a coin is picked, the TV says what the phone has to send.
    plus.followTopup(_sending(_usdt));
    await tester.pump();
    expect(find.textContaining('Waiting for 10.0412 USDT on Tron (TRC-20)'),
        findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    plus.dismissTopup();
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    await done(tester);
  });

  testWidgets('a waiting code prices Plus at the discount, not the top-up',
      (tester) async {
    plus = await tester.runAsync(() => controllerFor(_discounted()))
        as PlusController;
    // Half price for two periods, rounded the way Laravel rounds, then full.
    expect(plus.chargeFor(200), 100);
    expect(plus.chargeFor(199), 100);
    expect(plus.periodsFundedBy(100, 200), 1);
    expect(plus.periodsFundedBy(1000, 200), 6);

    await pump(tester, const PlusScreen());
    // $1 of credit is enough to start Plus at half price.
    expect(find.text('Start Plus · \$1.00 from balance'), findsOneWidget);

    unawaited(showAddFundsSheet(tester.element(find.byType(PlusScreen))));
    await tester.pump(const Duration(seconds: 1));
    expect(
        find.textContaining(
            'your next 2 periods cost \$1.00 each instead of \$2.00'),
        findsOneWidget);
    // The payment itself is credit and stays the full amount.
    expect(find.text('Pay \$10.00 with crypto'), findsOneWidget);
    expect(find.text('Covers 6 Plus periods (186 days)'), findsOneWidget);
    await done(tester);
  });

  testWidgets('Android TV redeems a code typed on its own keyboard',
      (tester) async {
    plus = await tester.runAsync(() => controllerFor(_discounted()))
        as PlusController;
    await pump(tester, const TvPlusScreen(), size: const Size(1920, 1080));
    expect(find.text('Start Plus · \$1.00 from balance'), findsOneWidget);
    expect(find.text('50% off upcoming renewals (2 left)'), findsOneWidget);

    await tester.tap(find.text('Redeem a code'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TvRedeemCodeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final key in ['h', 'a', 'l', 'f', '-', '5', '0']) {
      await tester.tap(find.byKey(ValueKey<String>('tv-form-key-$key')));
      await tester.pump();
    }
    expect(find.text('HALF-50'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('tv-form-key-action')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(billing.redeemed, ['HALF-50']);
    expect(find.text('Free Plus added: 14 days.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TvRedeemCodeScreen), findsNothing);
    await done(tester);
  });

  testWidgets('Android TV asks guests to sign up first', (tester) async {
    plus = await tester.runAsync(() => controllerFor(null)) as PlusController;
    await pump(tester, const TvPlusScreen(), size: const Size(960, 540));

    expect(tester.takeException(), isNull);
    expect(find.text('Sign up and subscribe to Plus to get rid of ads'),
        findsWidgets);
    expect(find.byType(QrImageView), findsNothing);
    await done(tester);
  });

  testWidgets('Plus that starts in the app is celebrated once', (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    await pump(
        tester,
        const Stack(children: [
          Scaffold(body: SizedBox()),
          PlusCelebration(),
        ]));
    expect(find.text('Welcome to Plus'), findsNothing);

    await tester.runAsync(() => plus.redeemCoupon('WELCOME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Welcome to Plus'), findsOneWidget);
    // Shown above the navigator, it brings its own Material so text is not
    // drawn in the yellow-underlined fallback style.
    expect(
        find.ancestor(
            of: find.text('Welcome to Plus'), matching: find.byType(Material)),
        findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Welcome to Plus'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Welcome to Plus'), findsNothing);
    await done(tester);
  });
}
