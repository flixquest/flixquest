import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/models/billing.dart';
import '../../data/repositories/billing_repository.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import '../widgets/plus_sheets.dart';
import 'plus_payment_screen.dart';

/// The prepaid balance: what is available, what it covers, payments still
/// confirming and every top-up and Plus period, newest first.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final List<WalletTransaction> _items = <WalletTransaction>[];
  final ScrollController _scroll = ScrollController();
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  BillingError? _error;
  int? _seenRevision;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(prepareDates(context).then((_) {
        if (mounted) setState(() {});
      }));
      unawaited(_reload());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A top-up or renewal posted elsewhere shows up without pulling.
    final revision = Provider.of<PlusController>(context).wallet?.revision;
    if (_seenRevision != null && revision != _seenRevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_reload());
      });
    }
    _seenRevision = revision;
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) unawaited(_more());
  }

  Future<void> _reload() async {
    _cursor = null;
    _done = false;
    _items.clear();
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page =
          await context.read<PlusController>().history(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.transactions);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
      });
    } on BillingError catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController>();
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final wallet = plus.wallet;
    final pending = plus.account?.pendingTopups ?? const <WalletTopup>[];
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: tr('plus_wallet'),
        kicker: tr('plus_name'),
        contentWidth: 760,
      ),
      body: RefreshIndicator(
        color: palette.mutedText,
        onRefresh: () async {
          await plus.refresh(full: true);
          await _reload();
        },
        child: ReadableWidth(
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
                bottom: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
                child: _BalanceHeader(plus: plus),
              ),
              const SizedBox(height: AppSpace.lg),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: PillButton(
                        label: tr('plus_add_funds'),
                        icon: PhosphorIcons.plus(),
                        primary: true,
                        onPressed: wallet?.frozen == true
                            ? null
                            : () => unawaited(showAddFundsSheet(context)),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: PillButton(
                        label: tr('plus_redeem_code'),
                        icon: PhosphorIcons.ticket(),
                        onPressed: () => unawaited(showRedeemSheet(context)),
                      ),
                    ),
                  ],
                ),
              ),
              if (pending.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpace.xxl),
                KickerHeading(tr('plus_confirming')),
                for (final topup in pending)
                  ListRow(
                    icon: PhosphorIcons.hourglassMedium(),
                    label: tr('plus_topup_of',
                        args: [formatUsd(topup.amountCents)]),
                    subtitle: switch (topup.step) {
                      'send_remaining' => tr('plus_payment_partial'),
                      'choose_coin' => tr('plus_step_choose_coin'),
                      'confirming' => tr('plus_confirming'),
                      _ => tr('plus_payment_waiting'),
                    },
                    onTap: () => unawaited(openPlusPayment(context, topup)),
                  ),
              ],
              const SizedBox(height: AppSpace.xxl),
              KickerHeading(tr('plus_history')),
              if (_items.isEmpty && !_loading && _error == null)
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: gutter, vertical: AppSpace.md),
                  child: Text(
                    tr('plus_history_empty'),
                    style: AppType.body.copyWith(color: palette.mutedText),
                  ),
                ),
              for (final item in _items) _TransactionRow(item: item),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpace.xl),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: gutter, vertical: AppSpace.md),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          billingMessage(_error!),
                          style:
                              AppType.body.copyWith(color: palette.mutedText),
                        ),
                      ),
                      PillButton(
                        label: tr('retry'),
                        onPressed: () => unawaited(_more()),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.plus});

  final PlusController plus;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final wallet = plus.wallet;
    final renewal = plus.renewal;
    final price = renewal?.amountCents ?? plus.plan?.amountCents ?? 200;
    final interval = renewal?.intervalDays ?? plus.plan?.intervalDays ?? 31;
    final spendable = wallet?.spendableCents ?? 0;
    final periods =
        wallet?.periodsFundable ?? plus.periodsFundedBy(spendable, price);
    final nextAt = renewal?.nextChargeAt;
    final lines = <String>[
      if (wallet?.frozen == true)
        tr('plus_wallet_on_hold')
      else if (periods > 0)
        plural(
            plus.adFree
                ? 'plus_covers_more_periods'
                : 'plus_covers_periods_short',
            periods,
            namedArgs: {'days': '$interval'})
      else
        tr('plus_covers_none', args: [formatUsd(plus.chargeFor(price))]),
      if (renewal?.autoRenew == true && nextAt != null)
        tr('plus_next_renewal_on', args: [
          formatUsd(renewal?.nextChargeCents ?? price),
          formatDay(context, nextAt)
        ]),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            tr('plus_available').toUpperCase(),
            style: AppType.kicker.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: AppSpace.sm),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: spendable.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              formatUsd(value.round()),
              style: TextStyle(
                fontFamily: 'FigtreeBlack',
                fontSize: 42,
                height: 1,
                letterSpacing: -1.2,
                color: palette.foreground,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                style: AppType.body.copyWith(
                  color: wallet?.frozen == true
                      ? Theme.of(context).colorScheme.error
                      : palette.mutedText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.item});

  final WalletTransaction item;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (icon, label) = switch (item.type) {
      'topup' when item.source == 'patreon' => (
          PhosphorIcons.heart(),
          tr('plus_tx_patreon')
        ),
      'topup' => (PhosphorIcons.arrowDownLeft(), tr('plus_tx_topup')),
      'plus_period' => (PhosphorIcons.calendarCheck(), tr('plus_tx_period')),
      'reversal' => (PhosphorIcons.arrowUUpLeft(), tr('plus_tx_reversal')),
      'refund' => (PhosphorIcons.arrowUpRight(), tr('plus_tx_refund')),
      _ => (PhosphorIcons.sliders(), tr('plus_tx_adjustment')),
    };
    final starts = item.periodStartsAt;
    final ends = item.periodEndsAt;
    final created = item.createdAt;
    final subtitle = starts != null && ends != null
        ? '${formatDay(context, starts)} – ${formatDay(context, ends)}'
        : created == null
            ? null
            : formatDay(context, created);
    final positive = item.amountCents > 0;
    return ListRow(
      // A Plus period carries the Plus mark; money movements their arrows.
      icon: item.type == 'plus_period' ? null : icon,
      leading: item.type == 'plus_period'
          ? PlusMark(size: 22, color: palette.mutedText)
          : null,
      label: label,
      subtitle: subtitle,
      showsNext: false,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            '${positive ? '+' : ''}${formatUsd(item.amountCents)}',
            style: AppType.cardTitle.copyWith(
              fontSize: 15,
              color: palette.foreground,
            ),
          ),
          if (item.balanceAfterCents != null)
            Text(
              tr('plus_balance_after',
                  args: [formatUsd(item.balanceAfterCents!)]),
              style: AppType.metadata.copyWith(color: palette.mutedText),
            ),
        ],
      ),
    );
  }
}
