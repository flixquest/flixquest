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
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../screens/plus_payment_screen.dart';
import 'page_kit.dart';
import 'patreon_sheet.dart';
import 'pill_button.dart';
import 'settings_kit.dart';

/// Add funds: an amount, an optional "start Plus when it confirms", and the
/// crypto disclosure. Continuing creates the top-up and opens FlixQuest's
/// checkout, where the viewer picks a coin.
Future<void> showAddFundsSheet(BuildContext context,
    {bool offerActivation = true}) {
  final plus = context.read<PlusController>();
  return showAppSheet<void>(
    context,
    builder: (_) => ChangeNotifierProvider<PlusController>.value(
      value: plus,
      child: _AddFundsSheet(host: context, offerActivation: offerActivation),
    ),
  );
}

class _AddFundsSheet extends StatefulWidget {
  const _AddFundsSheet({required this.host, required this.offerActivation});

  final BuildContext host;
  final bool offerActivation;

  @override
  State<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<_AddFundsSheet> {
  final TextEditingController _custom = TextEditingController();
  int? _selected;
  bool _customMode = false;
  bool _activate = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final plus = context.read<PlusController>();
    final suggested =
        (plus.catalog?.wallet ?? const TopupLimits()).offeredCents;
    // $10 is five periods: the amount the offer leads with.
    _selected = suggested.contains(1000)
        ? 1000
        : suggested.isEmpty
            ? null
            : suggested.first;
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  int? get _amount {
    if (!_customMode) return _selected;
    final text = _custom.text.trim().replaceAll(',', '.');
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) return null;
    return (value * 100).round();
  }

  String? _validate(PlusController plus) {
    final amount = _amount;
    final limits = plus.catalog?.wallet ?? const TopupLimits();
    if (amount == null) return tr('plus_amount_invalid');
    if (amount < limits.minCents || amount > limits.maxCents) {
      return tr('plus_amount_range',
          args: [formatUsd(limits.minCents), formatUsd(limits.maxCents)]);
    }
    return null;
  }

  bool _canActivate(PlusController plus) =>
      widget.offerActivation &&
      !plus.adFree &&
      !(plus.renewal?.autoRenew ?? false);

  Future<void> _continue() async {
    final plus = context.read<PlusController>();
    final problem = _validate(plus);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final topup = await plus.startTopup(_amount!,
          activatePlus: _canActivate(plus) && _activate);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.host.mounted) {
        unawaited(openPlusPayment(widget.host, topup));
      }
    } on BillingError catch (error) {
      if (mounted) setState(() => _error = billingMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController>();
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final limits = plus.catalog?.wallet ?? const TopupLimits();
    final price = plus.renewal?.amountCents ?? plus.plan?.amountCents ?? 200;
    final interval =
        plus.renewal?.intervalDays ?? plus.plan?.intervalDays ?? 31;
    final amount = _amount;
    final spendable = plus.wallet?.spendableCents ?? 0;
    final periods =
        amount == null ? 0 : plus.periodsFundedBy(spendable + amount, price);
    final activate = _canActivate(plus);
    final discount = plus.discount;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SheetTitle(tr('plus_add_funds')),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Text(
                tr('plus_add_funds_intro'),
                style: AppType.body.copyWith(color: palette.mutedText),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: <Widget>[
                  for (final cents in limits.offeredCents)
                    TogglePill(
                      label: formatPrice(cents),
                      selected: !_customMode && _selected == cents,
                      onTap: () => setState(() {
                        _customMode = false;
                        _selected = cents;
                        _error = null;
                      }),
                    ),
                  TogglePill(
                    label: tr('plus_other_amount'),
                    selected: _customMode,
                    onTap: () => setState(() {
                      _customMode = true;
                      _error = null;
                    }),
                  ),
                ],
              ),
            ),
            if (_customMode)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
                child: TextField(
                  controller: _custom,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    LengthLimitingTextInputFormatter(8),
                  ],
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    prefixText: r'$ ',
                    labelText: tr('plus_amount_usd'),
                    helperText: tr('plus_amount_range', args: [
                      formatUsd(limits.minCents),
                      formatUsd(limits.maxCents)
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _CoverageLine(
                periods: periods,
                days: periods * interval,
                price: price,
                interval: interval,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, 0),
              child: discount == null
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => unawaited(showRedeemSheet(context)),
                        icon: Icon(PhosphorIcons.ticket(), size: 18),
                        label: Text(tr('plus_have_code')),
                      ),
                    )
                  : _DiscountLine(
                      text: plural(
                          'plus_discount_applied', discount.periodsRemaining,
                          namedArgs: {
                            'price': formatUsd(plus.chargeFor(price)),
                            'full': formatUsd(price),
                          }),
                    ),
            ),
            if (activate) ...<Widget>[
              const SizedBox(height: AppSpace.sm),
              SwitchRow(
                icon: PhosphorIcons.calendarCheck(),
                label: tr('plus_start_when_confirmed'),
                subtitle: tr('plus_start_when_confirmed_consent',
                        args: [formatUsd(plus.chargeFor(price)), '$interval']) +
                    discountConsentNote(discount, price),
                value: _activate,
                onChanged: (value) => setState(() => _activate = value),
              ),
            ],
            if (plus.patreonOffer.enabled && plus.patreon?.linked != true)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (widget.host.mounted) {
                        unawaited(showPatreonSheet(widget.host));
                      }
                    },
                    icon: Icon(PhosphorIcons.heart(), size: 18),
                    label: Text(tr('plus_patreon_row_offer')),
                  ),
                ),
              ),
            Padding(
              padding:
                  EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, AppSpace.lg),
              child: _Disclosure(lines: <String>[
                tr('plus_disclosure_crypto'),
                tr('plus_disclosure_credit'),
                tr('plus_disclosure_no_auto_charge'),
              ]),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.md),
                child: Text(
                  _error!,
                  style: AppType.body
                      .copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: PillButton(
                label: amount == null
                    ? tr('plus_continue_to_payment')
                    : tr('plus_pay_amount', args: [formatUsd(amount)]),
                icon: PhosphorIcons.lockSimple(),
                primary: true,
                busy: _busy,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageLine extends StatelessWidget {
  const _CoverageLine({
    required this.periods,
    required this.days,
    required this.price,
    required this.interval,
  });

  final int periods;
  final int days;
  final int price;
  final int interval;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: palette.raisedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: <Widget>[
          Icon(PhosphorIcons.calendarCheck(),
              size: 22, color: palette.foreground),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              periods < 1
                  ? tr('plus_covers_none', args: [formatUsd(price)])
                  : plural('plus_covers_periods', periods,
                      namedArgs: {'total': '$days'}),
              style: AppType.body.copyWith(color: palette.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// The waiting coupon discount, and that it lowers Plus, not this payment.
class _DiscountLine extends StatelessWidget {
  const _DiscountLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child:
              Icon(PhosphorIcons.ticket(), size: 18, color: palette.foreground),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(text,
              style: AppType.body.copyWith(color: palette.foreground)),
        ),
      ],
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = AppType.metadata.copyWith(
      fontSize: 12.5,
      height: 1.45,
      color: palette.mutedText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(PhosphorIcons.info(),
                      size: 14, color: palette.mutedText),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Text(line, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Enter a code: free Plus days now, or a discount on the coming renewals.
/// [code], from a link, arrives typed in; the viewer still taps Redeem.
Future<void> showRedeemSheet(BuildContext context, {String? code}) {
  final plus = context.read<PlusController>();
  return showAppSheet<void>(
    context,
    builder: (_) => ChangeNotifierProvider<PlusController>.value(
      value: plus,
      child: _RedeemSheet(code: code),
    ),
  );
}

class _RedeemSheet extends StatefulWidget {
  const _RedeemSheet({this.code});

  final String? code;

  @override
  State<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<_RedeemSheet> {
  late final TextEditingController _code =
      TextEditingController(text: widget.code);
  bool _busy = false;
  String? _error;
  CouponRedemption? _done;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _code.text.trim();
    if (code.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final redemption =
          await context.read<PlusController>().redeemCoupon(code);
      if (mounted) setState(() => _done = redemption);
    } on BillingError catch (error) {
      if (mounted) setState(() => _error = billingMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final done = _done;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: done != null
              ? Padding(
                  key: const ValueKey('done'),
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PlusEmblem(size: 64),
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        tr('plus_redeemed'),
                        style: AppType.sectionHeader.copyWith(
                          fontFamily: AppType.bold,
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        redemptionSummary(done),
                        textAlign: TextAlign.center,
                        style: AppType.body.copyWith(color: palette.mutedText),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      PillButton(
                        label: tr('plus_done'),
                        primary: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                )
              : Column(
                  key: const ValueKey('form'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SheetTitle(tr('plus_redeem_code')),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: Text(
                        tr('plus_redeem_intro'),
                        style: AppType.body.copyWith(color: palette.mutedText),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          gutter, AppSpace.lg, gutter, AppSpace.lg),
                      child: TextField(
                        controller: _code,
                        autofocus: widget.code == null,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(40),
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        onSubmitted: (_) => _redeem(),
                        onChanged: (_) => setState(() => _error = null),
                        style: const TextStyle(
                          fontFamily: AppType.semiBold,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(PhosphorIcons.ticket()),
                          labelText: tr('plus_code'),
                          errorText: _error,
                          errorMaxLines: 3,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: PillButton(
                        label: tr('plus_redeem'),
                        primary: true,
                        busy: _busy,
                        onPressed: _redeem,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The renewal consent: what is taken, when, and that stopping keeps paid
/// time and the balance. True when the viewer agrees.
Future<bool> confirmPlusRenewal(BuildContext context,
    {required int priceCents,
    required int intervalDays,
    required bool chargesNow,
    String discountNote = '',
    DateTime? firstCharge}) async {
  final message = chargesNow
      ? tr('plus_consent_now', args: [formatUsd(priceCents), '$intervalDays'])
      : tr('plus_consent_later', args: [
          formatUsd(priceCents),
          firstCharge == null ? '' : formatDay(context, firstCharge),
          '$intervalDays',
        ]);
  final agreed = await showConfirmDialog(
    context,
    icon: PhosphorIcons.arrowsClockwise(),
    title: chargesNow ? tr('plus_start_plus') : tr('plus_turn_on_renewal'),
    message: '$message$discountNote\n\n${tr('plus_consent_stop_anytime')}',
    confirmLabel: tr('plus_agree_and_continue'),
  );
  return agreed == true;
}
