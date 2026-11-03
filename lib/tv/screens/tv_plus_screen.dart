import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/billing.dart';
import '../../data/repositories/billing_repository.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../app/tv_design.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_pill_button.dart';
import 'tv_redeem_code_screen.dart';

/// FlixQuest Plus on Android TV. Nobody types amounts or a wallet address
/// with a remote: the TV shows a QR code that opens this account's top-up
/// page on a phone, the viewer pays there, and the TV follows the payment
/// until Laravel confirms it. Viewers without crypto can switch the code to
/// a Patreon link instead: their pledge then adds to the balance.
class TvPlusScreen extends StatefulWidget {
  const TvPlusScreen({super.key});

  @override
  State<TvPlusScreen> createState() => _TvPlusScreenState();
}

class _TvPlusScreenState extends State<TvPlusScreen> {
  String? _message;
  bool _working = false;

  /// The phone link on the QR code, renewed before it expires.
  ({Uri url, DateTime expiresAt})? _link;
  BillingError? _linkError;
  bool _linkLoading = false;
  String? _linkOwner;
  Timer? _linkRenewal;

  /// The QR code shows the Patreon link instead of the top-up page.
  bool _patreonMode = false;
  bool _patreonLoading = false;
  BillingError? _patreonError;

  /// Checks for a top-up started on the phone while this screen is open.
  Timer? _watch;
  late DateTime _openedAt;
  late final PlusController _plus = context.read<PlusController>();

  /// How often the TV looks for the phone's payment, and for how long.
  static const _watchEvery = Duration(seconds: 8);
  static const _watchFor = Duration(minutes: 45);

  @override
  void initState() {
    super.initState();
    _openedAt = _plus.serverNow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_plus.refresh(full: true));
      if (_plus.catalog == null) unawaited(_plus.refreshCatalog());
      unawaited(prepareDates(context).then((_) {
        if (mounted) setState(() {});
      }));
    });
    final stopAt = DateTime.now().add(_watchFor);
    _watch = Timer.periodic(_watchEvery, (timer) {
      if (!mounted || DateTime.now().isAfter(stopAt)) {
        timer.cancel();
        return;
      }
      unawaited(_lookForPhonePayment());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final plus = context.watch<PlusController>();
    // A new account (or a sign-out) gets its own code, never the last one's.
    if (plus.owner != _linkOwner) {
      _linkOwner = plus.owner;
      _link = null;
      _linkError = null;
      _linkRenewal?.cancel();
      if (plus.signedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _newLink());
      }
    }
  }

  @override
  void dispose() {
    _watch?.cancel();
    _linkRenewal?.cancel();
    super.dispose();
  }

  Future<void> _newLink() async {
    if (!mounted || _linkLoading || !_plus.signedIn) return;
    final owner = _plus.owner;
    setState(() {
      _linkLoading = true;
      _linkError = null;
    });
    try {
      final link = await _plus.topupLink();
      if (!mounted || owner != _plus.owner) return;
      setState(() => _link = link);
      _linkRenewal?.cancel();
      final renewIn = link.expiresAt.difference(DateTime.now().toUtc()) -
          const Duration(minutes: 1);
      _linkRenewal = Timer(
          renewIn.isNegative ? const Duration(seconds: 30) : renewIn,
          () => unawaited(_newLink()));
    } on BillingError catch (error) {
      if (mounted) setState(() => _linkError = error);
    } finally {
      if (mounted) setState(() => _linkLoading = false);
    }
  }

  /// A Patreon link for the phone; Plus starts from the balance once a
  /// charge covers it unless it is already on (the TV states this consent).
  Future<void> _newPatreonLink() async {
    if (!mounted || _patreonLoading || !_plus.signedIn) return;
    setState(() {
      _patreonLoading = true;
      _patreonError = null;
    });
    try {
      await _plus.startPatreonLink(activatePlus: _patreonActivates(_plus));
    } on BillingError catch (error) {
      if (mounted) setState(() => _patreonError = error);
    } finally {
      if (mounted) setState(() => _patreonLoading = false);
    }
  }

  bool _patreonActivates(PlusController plus) =>
      !plus.adFree && !(plus.renewal?.autoRenew ?? false);

  void _togglePatreon() {
    setState(() => _patreonMode = !_patreonMode);
    if (_patreonMode && !(_plus.patreonLink?.isOpen ?? false)) {
      unawaited(_newPatreonLink());
    }
  }

  /// A top-up the phone started after this screen opened is followed until
  /// it settles; the celebration then shows if it started Plus.
  Future<void> _lookForPhonePayment() async {
    if (!_plus.signedIn || _plus.topup != null) return;
    await _plus.refresh(full: true);
    if (!mounted || _plus.topup != null) return;
    final since = _openedAt.subtract(const Duration(minutes: 2));
    for (final topup in _plus.account?.pendingTopups ?? const <WalletTopup>[]) {
      final created = topup.createdAt;
      if (topup.isOpen && created != null && created.isAfter(since)) {
        _plus.followTopup(topup);
        return;
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await action();
    } on BillingError catch (error) {
      if (mounted) setState(() => _message = billingMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  int _price(PlusController plus) =>
      plus.plan?.amountCents ?? plus.renewal?.amountCents ?? 200;

  int _interval(PlusController plus) =>
      plus.plan?.intervalDays ?? plus.renewal?.intervalDays ?? 31;

  Future<void> _enable(PlusController plus) async {
    final chargesNow = !plus.adFree;
    final until = plus.activeUntil;
    final charge = formatUsd(plus.chargeFor(_price(plus)));
    final agreed = await showTvDialog<bool>(
      context: context,
      title: chargesNow ? tr('plus_start_plus') : tr('plus_turn_on_renewal'),
      content: Text(
        '${chargesNow ? tr('plus_consent_now', args: [
                charge,
                '${_interval(plus)}'
              ]) : tr('plus_consent_later', args: [
                charge,
                until == null ? '' : formatDay(context, until),
                '${_interval(plus)}'
              ])}${discountConsentNote(plus.discount, _price(plus))}'
        '\n\n${tr('plus_consent_stop_anytime')}',
      ),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('plus_agree_and_continue'),
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        TvDialogAction(
          label: tr('cancel'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
    if (agreed == true && mounted) await _run(plus.enableRenewal);
  }

  Future<void> _disable(PlusController plus) async {
    final until = plus.activeUntil;
    final confirmed = await showTvDialog<bool>(
      context: context,
      title: tr('plus_turn_off_renewal'),
      content: Text(until == null
          ? tr('plus_turn_off_body_no_time')
          : tr('plus_turn_off_body', args: [formatDay(context, until)])),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('cancel'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        TvDialogAction(
          label: tr('plus_turn_off'),
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed == true && mounted) await _run(plus.disableRenewal);
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController>();
    final palette = TvPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: LayoutBuilder(builder: (context, constraints) {
        final metrics = TvShellMetrics.fromConstraints(constraints);
        final compact = metrics.compact;
        final gap = compact ? 20.0 : 32.0;
        return Padding(
          padding: EdgeInsets.all(metrics.safeInset + metrics.contentPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: _StatusPanel(plus: plus, compact: compact),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 6,
                // Scrolls when the buttons wrap on a small TV; each button
                // brings itself into view as it takes focus.
                child: FocusTraversalGroup(
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      clipBehavior: Clip.none,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _actions(context, plus, compact),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _actions(BuildContext context, PlusController plus, bool compact) {
    final palette = TvPalette.of(context);
    final topup = plus.topup;
    final title = TextStyle(
      fontFamily: 'FigtreeBold',
      fontSize: compact ? 24 : 30,
      height: 1.1,
      color: palette.foreground,
    );
    final body = TextStyle(
      fontSize: compact ? 14 : 17,
      height: 1.4,
      color: palette.mutedText,
    );
    final message = _message == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(_message!,
                style:
                    body.copyWith(color: Theme.of(context).colorScheme.error)),
          );

    if (!plus.signedIn) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(tr('plus_cta_guest'), style: title),
          const SizedBox(height: 12),
          Text(tr('plus_tv_sign_in_body'), style: body),
          if (plus.pendingCoupon != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(tr('plus_code_waiting_title', args: [plus.pendingCoupon!]),
                style: body.copyWith(color: palette.foreground)),
          ],
          const SizedBox(height: 26),
          TvPillButton(
            label: tr('plus_sign_up_or_in'),
            icon: PhosphorIcons.signIn(),
            autofocus: true,
            prominent: true,
            onActivate: () async {
              await FlixQuestAuthService().signOut();
              if (context.mounted) {
                await AuthNavigationService.returnToSignedOutRoot(context);
              }
            },
          ),
        ],
      );
    }

    if (topup != null) {
      return _CheckoutPanel(
        key: ValueKey(topup.id),
        plus: plus,
        topup: topup,
        compact: compact,
        message: message,
      );
    }

    final charge = plus.chargeFor(_price(plus));
    final fundable = (plus.wallet?.spendableCents ?? 0) >= charge;
    final open = plus.catalog?.purchasesEnabled ?? false;
    final renewing = plus.renewal?.autoRenew == true;
    final frozen = plus.wallet?.frozen == true;
    final patreonLink = plus.patreonLink;
    final offersPatreon =
        plus.patreonOffer.enabled && plus.patreon?.linked != true;
    if (_patreonMode && patreonLink != null && !_patreonLoading) {
      if (patreonLink.linked || !offersPatreon) {
        // Connected from the phone: back to the balance, now with Patreon.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _patreonMode = false);
        });
      } else if (patreonLink.status == 'expired' && _patreonError == null) {
        // The code ran out (or was cancelled): show a fresh one.
        WidgetsBinding.instance
            .addPostFrameCallback((_) => unawaited(_newPatreonLink()));
      }
    }
    final link = _patreonMode
        ? (patreonLink?.isOpen == true && patreonLink?.url != null
            ? (
                url: Uri.parse(patreonLink!.url!),
                expiresAt: patreonLink.expiresAt ?? DateTime.now()
              )
            : null)
        : _link;
    final linkError = _patreonMode ? _patreonError : _linkError;
    final qrProblem = linkError != null
        ? billingMessage(linkError)
        : _patreonMode && patreonLink?.status != 'expired'
            ? patreonLinkProblem(patreonLink)
            : null;
    final qrSize = compact ? 176.0 : 260.0;
    final buttons = <Widget>[
      if (!plus.adFree && fundable)
        TvPillButton(
          label: tr('plus_start_from_balance', args: [formatUsd(charge)]),
          leading: const PlusMark(),
          autofocus: true,
          prominent: true,
          enabled: !_working,
          onActivate: () => _enable(plus),
        ),
      if (plus.adFree || renewing)
        TvPillButton(
          label: renewing
              ? tr('plus_turn_off_renewal')
              : tr('plus_turn_on_renewal'),
          icon: renewing
              ? PhosphorIcons.pause()
              : PhosphorIcons.arrowsClockwise(),
          autofocus: plus.adFree || !fundable,
          enabled: !_working,
          onActivate: () => renewing ? _disable(plus) : _enable(plus),
        ),
      if (open && !frozen)
        TvPillButton(
          label: tr('plus_tv_phone_refresh'),
          icon: PhosphorIcons.qrCode(),
          autofocus: !fundable && !plus.adFree && !renewing,
          enabled: !(_patreonMode ? _patreonLoading : _linkLoading),
          onActivate: _patreonMode ? _newPatreonLink : _newLink,
        ),
      if (open && !frozen && (offersPatreon || _patreonMode))
        TvPillButton(
          label: _patreonMode
              ? tr('plus_tv_crypto_instead')
              : tr('plus_patreon_use'),
          icon: _patreonMode ? PhosphorIcons.qrCode() : PhosphorIcons.heart(),
          onActivate: _togglePatreon,
        ),
      TvPillButton(
        label: tr('plus_redeem_code'),
        icon: PhosphorIcons.ticket(),
        onActivate: () => TvRedeemCodeScreen.open(context),
      ),
    ];
    if (!open || frozen) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(tr('plus_add_funds'), style: title),
          const SizedBox(height: 10),
          Text(frozen ? tr('plus_wallet_on_hold_body') : tr('plus_not_on_sale'),
              style: body),
          if (buttons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 12, children: buttons),
          ],
          message,
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: qrSize,
              height: qrSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
              ),
              alignment: Alignment.center,
              child: link != null
                  ? Semantics(
                      label: tr('plus_tv_phone_step1'),
                      image: true,
                      child: QrImageView(
                        data: link.url.toString(),
                        size: qrSize,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    )
                  : qrProblem != null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            qrProblem,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        )
                      : const SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black45),
                        ),
            ),
            SizedBox(width: compact ? 20 : 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                      _patreonMode
                          ? tr('plus_tv_patreon_title')
                          : tr('plus_tv_phone_title'),
                      style: title),
                  SizedBox(height: compact ? 12 : 18),
                  for (final (index, key) in (_patreonMode
                          ? const <String>[
                              'plus_tv_phone_step1',
                              'plus_tv_patreon_step2',
                              'plus_tv_patreon_step3',
                            ]
                          : const <String>[
                              'plus_tv_phone_step1',
                              'plus_tv_phone_step2',
                              'plus_tv_phone_step3',
                            ])
                      .indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: compact ? 22 : 26,
                            height: compact ? 22 : 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.idleFill,
                              shape: BoxShape.circle,
                            ),
                            child: Text('${index + 1}',
                                style: body.copyWith(
                                    color: palette.foreground,
                                    fontFamily: 'FigtreeSB',
                                    fontSize: compact ? 12 : 14)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tr(key), style: body)),
                        ],
                      ),
                    ),
                  Text(
                      _patreonMode && _patreonActivates(plus)
                          ? tr('plus_tv_patreon_consent', args: [
                              formatUsd(charge),
                              '${_interval(plus)}',
                            ])
                          : tr('plus_tv_phone_expires'),
                      style: body.copyWith(fontSize: compact ? 12 : 14)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 20 : 28),
        Wrap(spacing: 12, runSpacing: 12, children: buttons),
        message,
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.plus, required this.compact});

  final PlusController plus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final until = plus.activeUntil;
    final ends = plus.entitlement?.expiresAt;
    final price = plus.plan?.amountCents ?? 200;
    final interval = plus.plan?.intervalDays ?? 31;
    final renewal = plus.renewal;
    final discount = plus.discount;
    final body = TextStyle(
      fontFamily: 'Figtree',
      fontSize: compact ? 14 : 17,
      height: 1.45,
      color: PlusColors.mutedInk,
    );
    return PlusAurora(
      borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
      child: Padding(
        padding: EdgeInsets.all(compact ? 24 : 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PlusWordmark(size: compact ? 30 : 40),
            const Spacer(),
            if (plus.adFree && ends != null) ...<Widget>[
              PlusPeriodRing(
                used: plus.periodProgress,
                size: compact ? 110 : 150,
                stroke: compact ? 7 : 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${daysLeft(plus.serverNow, ends)}',
                      style: TextStyle(
                        fontFamily: 'FigtreeBlack',
                        fontSize: compact ? 32 : 44,
                        height: 1,
                        color: PlusColors.ink,
                      ),
                    ),
                    Text(
                      plural('plus_days_left', daysLeft(plus.serverNow, ends)),
                      style: TextStyle(
                        fontFamily: 'FigtreeSB',
                        fontSize: compact ? 11 : 13,
                        color: PlusColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 18 : 26),
            ] else ...<Widget>[
              PlusEmblem(size: compact ? 72 : 96),
              SizedBox(height: compact ? 18 : 26),
            ],
            Text(
              plus.adFree
                  ? tr('plus_youre_ad_free')
                  : plus.signedIn
                      ? tr('plus_cta_member')
                      : tr('plus_cta_guest'),
              style: TextStyle(
                fontFamily: 'FigtreeBold',
                fontSize: compact ? 28 : 38,
                height: 1.1,
                letterSpacing: -.6,
                color: PlusColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              until != null
                  ? renewal?.autoRenew == true
                      ? tr('plus_renews_on', args: [formatDay(context, until)])
                      : tr('plus_ad_free_until',
                          args: [formatDay(context, until)])
                  : tr('plus_price_line',
                      args: [formatPrice(price), '$interval']),
              style: body,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (plus.signedIn)
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
                if (discount != null)
                  PlusChip(
                    icon: PhosphorIcons.ticket(),
                    label: discount.percentOff != null
                        ? tr('plus_discount_percent', args: [
                            '${discount.percentOff}',
                            '${discount.periodsRemaining}'
                          ])
                        : tr('plus_discount_amount', args: [
                            formatUsd(discount.amountOffCents ?? 0),
                            '${discount.periodsRemaining}'
                          ]),
                  ),
                PlusChip(
                    icon: PhosphorIcons.prohibit(),
                    label: tr('plus_tv_chip_no_ads')),
                PlusChip(
                    icon: PhosphorIcons.deviceMobile(),
                    label: tr('plus_tv_chip_devices')),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// What the phone is up to in FlixQuest's checkout, for the TV to say.
(String, String) _phoneStep(WalletTopup topup) {
  final payment = topup.payment;
  final coin = payment?.coin;
  return switch (topup.step) {
    'send_remaining' when payment != null && coin != null => (
        tr('plus_payment_partial'),
        tr('plus_tv_phone_rest_body', args: ['${payment.due} ${coin.ticker}'])
      ),
    'send_remaining' => (
        tr('plus_payment_partial'),
        tr('plus_payment_partial_body')
      ),
    'send' when payment != null && coin != null => (
        tr('plus_tv_phone_paying_title'),
        tr('plus_tv_phone_send_body',
            args: ['${payment.due} ${coin.ticker}', coin.networkLabel])
      ),
    'confirming' => (
        tr('plus_payment_confirming_title',
            args: [formatUsd(topup.amountCents)]),
        coin == null
            ? tr('plus_payment_confirming_body')
            : tr('plus_confirming_body', args: [coin.ticker, coin.networkLabel])
      ),
    _ => (
        tr('plus_tv_phone_paying_title'),
        tr('plus_tv_phone_paying_body', args: [formatUsd(topup.amountCents)])
      ),
  };
}

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel({
    required this.plus,
    required this.topup,
    required this.compact,
    required this.message,
    super.key,
  });

  final PlusController plus;
  final WalletTopup topup;
  final bool compact;
  final Widget message;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final title = TextStyle(
      fontFamily: 'FigtreeBold',
      fontSize: compact ? 24 : 30,
      height: 1.1,
      color: palette.foreground,
    );
    final body = TextStyle(
      fontSize: compact ? 14 : 17,
      height: 1.4,
      color: palette.mutedText,
    );
    final (heading, detail) = topup.settled
        ? (
            tr('plus_payment_received'),
            topup.activatePlus && plus.adFree
                ? tr('plus_payment_received_plus', args: [
                    formatDay(context, plus.activeUntil ?? DateTime.now())
                  ])
                : tr('plus_payment_received_balance',
                    args: [formatUsd(plus.wallet?.spendableCents ?? 0)])
          )
        : topup.failed
            ? (tr('plus_payment_failed'), tr('plus_payment_nothing_charged'))
            : _phoneStep(topup);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (topup.isOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: palette.mutedText),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Icon(
              topup.settled
                  ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                  : PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
              size: 40,
              color: topup.settled ? PlusColors.gold : palette.mutedText,
            ),
          ),
        Text(heading, style: title),
        const SizedBox(height: 10),
        Text(detail, style: body),
        if (topup.isOpen && plus.topupWatchExpired) ...<Widget>[
          const SizedBox(height: 14),
          Text(tr('plus_payment_still_waiting_body'),
              style: body.copyWith(fontSize: compact ? 12 : 14)),
        ],
        message,
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            if (topup.isOpen)
              TvPillButton(
                label: tr('plus_check_now'),
                icon: PhosphorIcons.arrowsClockwise(),
                autofocus: true,
                prominent: true,
                onActivate: () => plus.checkTopup(manual: true),
              ),
            TvPillButton(
              label:
                  topup.isOpen ? tr('plus_tv_back_to_code') : tr('plus_done'),
              autofocus: !topup.isOpen,
              prominent: !topup.isOpen,
              onActivate: plus.dismissTopup,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          tr('plus_reference', args: [topup.id]),
          style: body.copyWith(fontSize: compact ? 11 : 13),
        ),
      ],
    );
  }
}
