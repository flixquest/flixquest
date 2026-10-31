import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/models/billing.dart';
import '../../data/repositories/billing_repository.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../widgets/page_kit.dart';
import '../widgets/patreon_sheet.dart';
import '../widgets/pill_button.dart';
import '../widgets/plus_sheets.dart';
import '../widgets/settings_kit.dart';
import 'plus_payment_screen.dart';
import 'wallet_screen.dart';

/// FlixQuest Plus on the phone: what it is, the viewer's access, renewal and
/// balance, and every action on them. Paid access, renewal and the balance
/// are shown apart, exactly as Laravel keeps them.
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final plus = context.read<PlusController>();
      unawaited(plus.refresh(full: true));
      if (plus.catalog == null) unawaited(plus.refreshCatalog());
      unawaited(prepareDates(context).then((_) {
        if (mounted) setState(() {});
      }));
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } on BillingError catch (error) {
      if (mounted) _say(billingMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _say(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  int _price(PlusController plus) =>
      plus.renewal?.amountCents ?? plus.plan?.amountCents ?? 200;

  int _interval(PlusController plus) =>
      plus.renewal?.intervalDays ?? plus.plan?.intervalDays ?? 31;

  /// Starts Plus from the balance (now, or at the end of paid time).
  Future<void> _enable(PlusController plus) async {
    final chargesNow = !plus.adFree;
    // Consent is always to the current terms, which may differ from the
    // ones an old agreement was made under.
    final price = plus.plan?.amountCents ?? _price(plus);
    final agreed = await confirmPlusRenewal(
      context,
      priceCents: plus.chargeFor(price),
      discountNote: discountConsentNote(plus.discount, price),
      intervalDays: plus.plan?.intervalDays ?? _interval(plus),
      chargesNow: chargesNow,
      firstCharge: plus.activeUntil,
    );
    if (!agreed || !mounted) return;
    await _run(() async {
      await plus.enableRenewal();
      if (mounted && !chargesNow) _say(tr('plus_renewal_on'));
    });
  }

  Future<void> _disable(PlusController plus) async {
    final until = plus.activeUntil;
    final confirmed = await showConfirmDialog(
      context,
      icon: PhosphorIcons.pauseCircle(),
      title: tr('plus_turn_off_renewal'),
      message: until == null
          ? tr('plus_turn_off_body_no_time')
          : tr('plus_turn_off_body', args: [formatDay(context, until)]),
      confirmLabel: tr('plus_turn_off'),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await plus.disableRenewal();
      if (mounted) _say(tr('plus_renewal_off'));
    });
  }

  Future<void> _signIn() async {
    await FlixQuestAuthService().signOut();
    if (mounted) await AuthNavigationService.returnToSignedOutRoot(context);
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController>();
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final renewal = plus.renewal;
    final wallet = plus.wallet;
    final topup = plus.topup;
    final pending = topup != null && topup.isOpen
        ? topup
        : plus.account?.pendingTopups.firstOrNull;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('plus_name'), contentWidth: 760),
      body: RefreshIndicator(
        color: palette.mutedText,
        onRefresh: () => plus.refresh(full: true),
        child: ReadableWidth(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
                top: AppSpace.sm,
                bottom: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: _Hero(
                  plus: plus,
                  working: _working,
                  onGetPlus: () => unawaited(showAddFundsSheet(context)),
                  onPatreon: () => unawaited(showPatreonSheet(context)),
                  onStartFromBalance: () => unawaited(_enable(plus)),
                  onSignIn: () => unawaited(_signIn()),
                ),
              ),
              if (plus.pendingCoupon != null && !plus.signedIn) ...<Widget>[
                const SizedBox(height: AppSpace.lg),
                _Notice(
                  icon: PhosphorIcons.ticket(),
                  title: tr('plus_code_waiting_title',
                      args: [plus.pendingCoupon!]),
                  body: tr('plus_code_waiting_body'),
                ),
              ],
              if (pending != null) ...<Widget>[
                const SizedBox(height: AppSpace.lg),
                _Notice(
                  icon: PhosphorIcons.hourglassMedium(),
                  title: _pendingTitle(pending),
                  body: _pendingBody(pending),
                  action: tr('plus_view'),
                  onAction: () => unawaited(openPlusPayment(context, pending)),
                ),
              ],
              ..._notices(plus),
              if (plus.signedIn) ...<Widget>[
                const SizedBox(height: AppSpace.xxl),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: SettingsGroup(
                    title: tr('plus_your_plan'),
                    children: <Widget>[
                      if (renewal?.autoRenew == true || plus.adFree)
                        SwitchRow(
                          icon: PhosphorIcons.arrowsClockwise(),
                          label: tr('plus_renew_from_balance'),
                          subtitle: _renewalLine(plus),
                          value: renewal?.autoRenew ?? false,
                          onChanged: _working
                              ? null
                              : (on) => unawaited(
                                  on ? _enable(plus) : _disable(plus)),
                        ),
                      ListRow(
                        icon: PhosphorIcons.wallet(),
                        label: tr('plus_balance'),
                        value: formatUsd(wallet?.spendableCents ?? 0),
                        subtitle: _balanceLine(plus),
                        onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                                builder: (_) => const WalletScreen())),
                      ),
                      ListRow(
                        icon: PhosphorIcons.plusCircle(),
                        label: tr('plus_add_funds'),
                        onTap: wallet?.frozen == true
                            ? null
                            : () => unawaited(showAddFundsSheet(context)),
                      ),
                      if (plus.patreon?.linked == true ||
                          plus.patreonOffer.enabled)
                        ListRow(
                          icon: PhosphorIcons.heart(),
                          label: plus.patreon?.linked == true
                              ? tr('plus_patreon')
                              : tr('plus_patreon_use'),
                          subtitle: plus.patreon?.linked == true
                              ? patreonStatusLine(plus.patreon!)
                              : tr('plus_patreon_row_offer'),
                          onTap: () => unawaited(showPatreonSheet(context)),
                        ),
                      ListRow(
                        icon: PhosphorIcons.ticket(),
                        label: tr('plus_redeem_code'),
                        subtitle: _discountLine(renewal?.discount),
                        onTap: () => unawaited(showRedeemSheet(context)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xxl),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: SettingsGroup(
                  title: tr('plus_what_you_get'),
                  children: <Widget>[
                    for (final (icon, label) in <(IconData, String)>[
                      (PhosphorIcons.prohibit(), 'plus_benefit_banners'),
                      (PhosphorIcons.playCircle(), 'plus_benefit_popups'),
                      (PhosphorIcons.filmSlate(), 'plus_benefit_video'),
                      (PhosphorIcons.shieldCheck(), 'plus_benefit_blocker'),
                      (PhosphorIcons.television(), 'plus_benefit_devices'),
                    ])
                      ListRow(icon: icon, label: tr(label), showsNext: false),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child:
                    _HowItWorks(price: _price(plus), interval: _interval(plus)),
              ),
              if (wallet?.id != null) ...<Widget>[
                const SizedBox(height: AppSpace.xl),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: wallet.id!));
                      if (mounted) _say(tr('plus_reference_copied'));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        tr('plus_wallet_reference', args: [wallet!.id!]),
                        style:
                            AppType.metadata.copyWith(color: palette.mutedText),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _renewalLine(PlusController plus) {
    final renewal = plus.renewal;
    final until = plus.activeUntil;
    if (renewal?.autoRenew == true && renewal?.nextChargeAt != null) {
      return tr('plus_next_renewal_on', args: [
        formatUsd(renewal!.nextChargeCents ?? _price(plus)),
        formatDay(context, renewal.nextChargeAt!),
      ]);
    }
    if (until != null) {
      return tr('plus_renewal_off_until', args: [formatDay(context, until)]);
    }
    return tr('plus_renewal_off_line');
  }

  String _balanceLine(PlusController plus) {
    final wallet = plus.wallet;
    if (wallet?.frozen == true) return tr('plus_wallet_on_hold');
    final periods = wallet?.periodsFundable ?? 0;
    if (periods < 1) {
      return tr('plus_covers_none',
          args: [formatUsd(plus.chargeFor(_price(plus)))]);
    }
    return plural(
        plus.adFree ? 'plus_covers_more_periods' : 'plus_covers_periods_short',
        periods,
        namedArgs: {'days': '${_interval(plus)}'});
  }

  String? _discountLine(PlusDiscount? discount) {
    if (discount == null) return null;
    final periods = '${discount.periodsRemaining}';
    if (discount.percentOff != null) {
      return tr('plus_discount_percent',
          args: ['${discount.percentOff}', periods]);
    }
    if (discount.amountOffCents != null) {
      return tr('plus_discount_amount',
          args: [formatUsd(discount.amountOffCents!), periods]);
    }
    return null;
  }

  /// An unfinished top-up, by where its checkout is.
  String _pendingTitle(WalletTopup topup) {
    final payment = topup.payment;
    return switch (topup.step) {
      'send' ||
      'send_remaining' when payment != null =>
        tr('plus_send_amount', args: [payment.due ?? '', payment.coin.ticker]),
      'choose_coin' => tr('plus_payment_waiting'),
      _ => tr('plus_payment_confirming_title',
          args: [formatUsd(topup.amountCents)]),
    };
  }

  String _pendingBody(WalletTopup topup) {
    final coin = topup.payment?.coin;
    return switch (topup.step) {
      'send' ||
      'send_remaining' when coin != null =>
        tr('plus_coin_on_network', args: [coin.ticker, coin.networkLabel]),
      'choose_coin' =>
        tr('plus_choose_coin_body', args: [formatUsd(topup.amountCents)]),
      _ => tr('plus_payment_confirming_body'),
    };
  }

  List<Widget> _notices(PlusController plus) {
    final renewal = plus.renewal;
    final wallet = plus.wallet;
    final notices = <Widget>[];
    void add(Widget notice) =>
        notices.addAll(<Widget>[const SizedBox(height: AppSpace.lg), notice]);
    final patreon = plus.patreon;
    final patreonLink = plus.patreonLink;
    if (patreonLink != null && patreonLink.isOpen) {
      add(_Notice(
        icon: PhosphorIcons.heart(),
        title: tr('plus_patreon_waiting_title'),
        body: tr('plus_patreon_waiting_body'),
        action: tr('plus_view'),
        onAction: () => unawaited(showPatreonSheet(context)),
      ));
    } else if (patreon?.linked == true && patreon!.needsReauthorization) {
      add(_Notice(
        icon: PhosphorIcons.heartBreak(),
        title: tr('plus_patreon_reconnect_title'),
        body: tr('plus_patreon_reconnect_body'),
        action: tr('plus_patreon_reconnect'),
        onAction: () => unawaited(showPatreonSheet(context)),
        warning: true,
      ));
    } else if (patreon?.linked == true && patreon!.declined) {
      add(_Notice(
        icon: PhosphorIcons.heartBreak(),
        title: tr('plus_patreon_declined'),
        body: tr('plus_patreon_disclosure_manage'),
        action: tr('plus_patreon_manage_pledge'),
        onAction: () => unawaited(showPatreonSheet(context)),
      ));
    }
    if (wallet?.frozen == true) {
      add(_Notice(
        icon: PhosphorIcons.lockKey(),
        title: tr('plus_wallet_on_hold'),
        body: tr('plus_wallet_on_hold_body'),
        warning: true,
      ));
    }
    if (renewal?.termsOutdated == true && renewal?.autoRenew == true) {
      add(_Notice(
        icon: PhosphorIcons.fileText(),
        title: tr('plus_terms_changed'),
        body: tr('plus_terms_changed_body', args: [
          formatUsd(plus.plan?.amountCents ?? renewal!.amountCents),
          '${plus.plan?.intervalDays ?? renewal!.intervalDays}',
        ]),
        action: tr('plus_review'),
        onAction: () => unawaited(_enable(plus)),
      ));
    }
    final next = renewal?.nextChargeCents;
    if (renewal?.autoRenew == true &&
        next != null &&
        (wallet?.spendableCents ?? 0) < next &&
        renewal?.nextChargeAt != null &&
        renewal!.nextChargeAt!.difference(plus.serverNow) <
            const Duration(days: 7)) {
      add(_Notice(
        icon: PhosphorIcons.batteryLow(),
        title: tr('plus_low_balance'),
        body: tr('plus_low_balance_body',
            args: [formatUsd(next), formatDay(context, renewal.nextChargeAt!)]),
        action: tr('plus_add_funds'),
        onAction: () =>
            unawaited(showAddFundsSheet(context, offerActivation: false)),
      ));
    } else if (!plus.adFree &&
        renewal?.lapsedForFunds == true &&
        renewal?.autoRenew == true) {
      add(_Notice(
        icon: PhosphorIcons.pauseCircle(),
        title: tr('plus_paused'),
        body: tr('plus_paused_body',
            args: [formatUsd(plus.chargeFor(renewal!.amountCents))]),
        action: tr('plus_add_funds'),
        onAction: () =>
            unawaited(showAddFundsSheet(context, offerActivation: false)),
      ));
    }
    return notices;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.plus,
    required this.working,
    required this.onGetPlus,
    required this.onPatreon,
    required this.onStartFromBalance,
    required this.onSignIn,
  });

  final PlusController plus;
  final bool working;
  final VoidCallback onGetPlus;
  final VoidCallback onPatreon;
  final VoidCallback onStartFromBalance;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final price = plus.plan?.amountCents ?? plus.renewal?.amountCents ?? 200;
    final interval =
        plus.plan?.intervalDays ?? plus.renewal?.intervalDays ?? 31;
    final until = plus.activeUntil;
    final active = until != null || plus.adFree;
    final charge = plus.chargeFor(price);
    final fundable = (plus.wallet?.spendableCents ?? 0) >= charge;
    final open = plus.catalog?.purchasesEnabled ?? false;
    final ends = plus.entitlement?.expiresAt;
    final left = ends == null ? 0 : daysLeft(plus.serverNow, ends);
    return PlusAurora(
      borderRadius: BorderRadius.circular(AppRadii.hero),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const PlusWordmark(size: 28),
                      const SizedBox(height: 16),
                      Text(
                        active
                            ? tr('plus_youre_ad_free')
                            : plus.signedIn
                                ? tr('plus_cta_member')
                                : tr('plus_cta_guest'),
                        style: const TextStyle(
                          fontFamily: 'FigtreeBold',
                          fontSize: 24,
                          height: 1.15,
                          letterSpacing: -.4,
                          color: PlusColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        active && until != null
                            ? tr('plus_ad_free_until',
                                args: [formatDay(context, until)])
                            : tr('plus_price_line',
                                args: [formatPrice(price), '$interval']),
                        style: const TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 14.5,
                          height: 1.4,
                          color: PlusColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (active && ends != null)
                  PlusPeriodRing(
                    used: plus.periodProgress,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '$left',
                          style: const TextStyle(
                            fontFamily: 'FigtreeBlack',
                            fontSize: 26,
                            height: 1,
                            color: PlusColors.ink,
                          ),
                        ),
                        Text(
                          plural('plus_days_left', left),
                          style: const TextStyle(
                            fontFamily: 'FigtreeSB',
                            fontSize: 10.5,
                            color: PlusColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const PlusEmblem(size: 58),
              ],
            ),
            const SizedBox(height: 20),
            if (!plus.signedIn)
              PillButton(
                label: tr('plus_sign_up_or_in'),
                icon: PhosphorIcons.signIn(),
                primary: true,
                onArtwork: true,
                onPressed: onSignIn,
              )
            else if (!active) ...<Widget>[
              if (fundable)
                PillButton(
                  label:
                      tr('plus_start_from_balance', args: [formatUsd(charge)]),
                  leading: const PlusMark(),
                  primary: true,
                  onArtwork: true,
                  busy: working,
                  onPressed: onStartFromBalance,
                )
              else if (open) ...<Widget>[
                PillButton(
                  label: tr('plus_get_plus'),
                  leading: const PlusMark(),
                  primary: true,
                  onArtwork: true,
                  onPressed: onGetPlus,
                ),
                if (plus.patreonOffer.enabled &&
                    plus.patreon?.linked != true) ...<Widget>[
                  const SizedBox(height: 10),
                  PillButton(
                    label: tr('plus_patreon_use'),
                    icon: PhosphorIcons.heart(),
                    onArtwork: true,
                    onPressed: onPatreon,
                  ),
                ],
              ] else
                Text(
                  tr('plus_not_on_sale'),
                  style: const TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 13,
                    color: PlusColors.mutedInk,
                  ),
                ),
            ] else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  PlusChip(
                    icon: plus.renewal?.autoRenew == true
                        ? PhosphorIcons.arrowsClockwise()
                        : PhosphorIcons.pause(),
                    label: plus.renewal?.autoRenew == true
                        ? tr('plus_auto_renew_on')
                        : tr('plus_auto_renew_off'),
                  ),
                  PlusChip(
                    icon: PhosphorIcons.wallet(),
                    label: tr('plus_balance_chip',
                        args: [formatUsd(plus.wallet?.spendableCents ?? 0)]),
                  ),
                  if (plus.patreon?.activePatron == true)
                    PlusChip(
                      icon: PhosphorIcons.heart(),
                      label: tr('plus_patreon_chip',
                          args: [formatUsd(plus.patreon!.monthlyCents)]),
                    ),
                  if (plus.showingCached)
                    PlusChip(
                      icon: PhosphorIcons.cloudSlash(),
                      label: tr('plus_offline_chip'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
              color: warning ? error.withValues(alpha: .5) : palette.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 22, color: warning ? error : palette.foreground),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppType.cardTitle
                        .copyWith(fontSize: 15, color: palette.foreground),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppType.body.copyWith(color: palette.mutedText),
                  ),
                  if (action != null && onAction != null) ...<Widget>[
                    const SizedBox(height: AppSpace.md),
                    PillButton(label: action!, onPressed: onAction),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.price, required this.interval});

  final int price;
  final int interval;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final steps = <(String, String)>[
      (tr('plus_how_1_title'), tr('plus_how_1_body')),
      (
        tr('plus_how_2_title'),
        tr('plus_how_2_body', args: [formatUsd(price), '$interval'])
      ),
      (tr('plus_how_3_title'), tr('plus_how_3_body')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
          child: Text(
            tr('plus_how_it_works').toUpperCase(),
            style: AppType.kicker.copyWith(color: palette.mutedText),
          ),
        ),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.idleFill,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style:
                        AppType.cardTitle.copyWith(color: palette.foreground),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        steps[i].$1,
                        style: AppType.cardTitle
                            .copyWith(fontSize: 15, color: palette.foreground),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[i].$2,
                        style: AppType.body.copyWith(color: palette.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(
          tr('plus_fine_print'),
          style:
              AppType.metadata.copyWith(height: 1.45, color: palette.mutedText),
        ),
      ],
    );
  }
}
