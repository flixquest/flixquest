import 'package:dio/dio.dart';
import 'package:flixquest/data/ads/ads_policy.dart';
import 'package:flixquest/data/models/billing.dart';
import 'package:flixquest/data/repositories/billing_repository.dart';
import 'package:flixquest/mobile/screens/plus_screen.dart';
import 'package:flixquest/mobile/screens/wallet_screen.dart';
import 'package:flixquest/presentation/billing/plus_controller.dart';
import 'package:flixquest/tv/screens/tv_plus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/fakes.dart';
import 'support/tv_localization.dart';

final _now = DateTime.utc(2026, 10, 31, 9);

const _linkUrl =
    'https://backend.flix.quest/plus/patreon/abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdef';

const _patron = PatreonMembership(
  enabled: true,
  linked: true,
  fullName: 'Pat Ron',
  patronStatus: 'active_patron',
  activePatron: true,
  pledgeCents: 300,
  willPayCents: 300,
  coversPlus: true,
  creditedCents: 600,
);

PlusAccount _free({PatreonMembership? patreon}) => PlusAccount(
      serverTime: _now,
      wallet: const WalletBalance(id: 'wallet-1'),
      patreon: patreon ?? const PatreonMembership(enabled: true),
    );

PlusAccount _member() => PlusAccount(
      entitlements: PlusEntitlement(
        adFree: true,
        startsAt: _now,
        expiresAt: _now.add(const Duration(days: 31)),
      ),
      serverTime: _now,
      wallet: const WalletBalance(id: 'wallet-1', balanceCents: 100),
      renewal: const PlusRenewal(mode: 'wallet', autoRenew: true),
      patreon: _patron,
    );

class _Billing extends BillingRepository {
  _Billing(this.account) : super(Dio());

  PlusAccount account;

  /// What Laravel says about the followed link.
  PatreonLink link = const PatreonLink(id: 'link-1', status: 'pending');
  final started = <({bool activatePlus, String? terms})>[];

  @override
  Future<PlusCatalog> plans() async => const PlusCatalog(
        purchasesEnabled: true,
        plans: [
          PlusPlan(
              code: 'plus',
              amountCents: 200,
              intervalDays: 31,
              termsVersion: '2026-10-24'),
        ],
        patreon: PatreonOffer(enabled: true, recommendedCents: 200),
      );

  @override
  Future<PlusAccount> wallet() async => account;

  @override
  Future<PlusAccount> entitlements() async =>
      account.copyWith(wallet: null, renewal: null, patreon: null);

  @override
  Future<PatreonLink> startPatreonLink(
      {bool activatePlus = false, String? termsVersion}) async {
    started.add((activatePlus: activatePlus, terms: termsVersion));
    return link.copyWith(
        url: _linkUrl, expiresAt: _now.add(const Duration(minutes: 20)));
  }

  @override
  Future<(PatreonLink, PatreonMembership)> patreonLink(String id) async =>
      (link, account.patreon ?? const PatreonMembership());

  @override
  Future<WalletHistoryPage> transactions({String? cursor}) async =>
      WalletHistoryPage([
        WalletTransaction(
            id: '2',
            type: 'topup',
            source: 'patreon',
            amountCents: 300,
            createdAt: _now),
        WalletTransaction(
            id: '1',
            type: 'topup',
            source: 'nowpayments',
            amountCents: 1000,
            createdAt: _now),
      ], null);
}

void main() {
  initializeTvTranslations();

  late PlusController plus;
  late _Billing billing;

  Future<PlusController> controllerFor(PlusAccount account) async {
    final controller = PlusController(
      repository: billing = _Billing(account),
      store: FakeKvStore(),
      owner: ValueNotifier<String?>('user:1'),
      now: () => _now,
      pollInterval: const Duration(hours: 1),
    );
    await controller.start();
    await controller.refresh(full: true);
    await controller.refreshCatalog();
    return controller;
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    plus.dispose();
    AdsPolicy.update(adFree: false);
  }

  Future<void> pump(WidgetTester tester, Widget child,
      {Size size = const Size(390, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<PlusController>.value(
      value: plus,
      child: MaterialApp(theme: ThemeData.dark(), home: child),
    ));
    await tester.pump(const Duration(milliseconds: 1500));
  }

  test('Laravel\'s Patreon answers parse into the membership and the offer',
      () {
    final account = PlusAccount.fromJson({
      'entitlements': {'ad_free': false, 'revision': 0},
      'patreon': {
        'enabled': true,
        'pledge_url': 'https://www.patreon.com/flixquest',
        'linked': true,
        'full_name': 'Pat Ron',
        'patron_status': 'declined_patron',
        'active_patron': false,
        'pledge_cents': 200,
        'will_pay_cents': 0,
        'pledge_cadence_months': 1,
        'covers_plus': false,
        'next_charge_at': '2026-11-30T00:00:00.000000Z',
        'credited_cents': 400,
        'plus_pending': true,
        'needs_reauthorization': false,
        'link': {
          'id': 'link-1',
          'status': 'failed',
          'error_code': 'patreon_linked_elsewhere',
          'expires_at': '2026-10-31T09:20:00.000000Z',
          'completed_at': null,
        },
      },
    });
    final catalog = PlusCatalog.fromJson({
      'purchases_enabled': true,
      'plans': <Object>[],
      'patreon': {'enabled': true, 'recommended_cents': 200},
    });

    expect(account.patreon!.declined, isTrue);
    expect(account.patreon!.monthlyCents, 200);
    expect(account.patreon!.plusPending, isTrue);
    expect(account.patreon!.link!.errorCode, 'patreon_linked_elsewhere');
    expect(account.patreon!.link!.isOpen, isFalse);
    expect(catalog.patreon.enabled, isTrue);
    expect(catalog.patreon.recommendedCents, 200);
  });

  test('a link that finishes in the browser reads the account again', () async {
    plus = await controllerFor(_free());

    await plus.startPatreonLink(activatePlus: true);
    expect(billing.started.single, (activatePlus: true, terms: '2026-10-24'));
    expect(plus.patreonLink!.isOpen, isTrue);

    billing
      ..link = const PatreonLink(id: 'link-1', status: 'linked')
      ..account = _member();
    await plus.checkPatreonLink();

    expect(plus.patreonLink!.linked, isTrue);
    expect(plus.patreon!.linked, isTrue);
    expect(plus.adFree, isTrue);
    plus.dispose();
    AdsPolicy.update(adFree: false);
  });

  testWidgets('a viewer without Plus is offered Patreon next to crypto',
      (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    await pump(tester, const PlusScreen());

    expect(find.text('Pay with Patreon'), findsWidgets);
    await tester.tap(find.text('Pay with Patreon').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Connect Patreon'), findsWidgets);
    expect(find.text('Start Plus when my balance covers it'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await done(tester);
  });

  testWidgets('a linked patron sees the pledge, and is asked to reconnect',
      (tester) async {
    plus = await tester.runAsync(() => controllerFor(_member()
            .copyWith(patreon: _patron.copyWith(needsReauthorization: true))))
        as PlusController;
    await pump(tester, const PlusScreen());

    expect(find.text('Pledging \$3.00 a month'), findsOneWidget);
    expect(find.text('Patreon \$3.00'), findsOneWidget);
    expect(find.text('Reconnect Patreon'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await done(tester);
  });

  testWidgets('the wallet names credit that came from Patreon', (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_member())) as PlusController;
    await pump(tester, const WalletScreen());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Patreon pledge'), findsOneWidget);
    expect(find.text('Top-up'), findsOneWidget);
    await done(tester);
  });

  testWidgets('Android TV switches its code to a Patreon link and back',
      (tester) async {
    plus =
        await tester.runAsync(() => controllerFor(_free())) as PlusController;
    await pump(tester, const TvPlusScreen(), size: const Size(1920, 1080));
    expect(find.text('Add funds from your phone'), findsOneWidget);

    await tester.tap(find.text('Pay with Patreon'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Pay with Patreon'), findsWidgets);
    expect(tester.widget<QrImageView>(find.byType(QrImageView)), isNotNull);
    expect(find.text('Sign in to Patreon and confirm this account'),
        findsOneWidget);
    expect(find.textContaining('Plus starts from your balance when it covers'),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    billing
      ..link = const PatreonLink(id: 'link-1', status: 'linked')
      ..account = _member();
    await tester.runAsync(plus.checkPatreonLink);
    await tester.pump();
    await tester.pump();

    expect(find.text('Add funds from your phone'), findsOneWidget);
    expect(find.text('Patreon \$3.00'), findsOneWidget);
    await done(tester);
  });
}
