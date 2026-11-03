import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/billing.dart';
import '../../data/repositories/billing_repository.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../presentation/billing/plus_controller.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';
import 'page_kit.dart';
import 'pill_button.dart';
import 'settings_kit.dart';

/// Patreon, for viewers who can't pay in crypto: connect it (the browser
/// signs in to Patreon and confirms the account), wait while that happens,
/// then see the pledge and what it has added to the balance.
Future<void> showPatreonSheet(BuildContext context) {
  final plus = context.read<PlusController>();
  return showAppSheet<void>(
    context,
    builder: (_) => ChangeNotifierProvider<PlusController>.value(
      value: plus,
      child: const _PatreonSheet(),
    ),
  );
}

/// Opens a Patreon page (the link, or the pledge page) in the browser.
Future<bool> openPatreonPage(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

class _PatreonSheet extends StatefulWidget {
  const _PatreonSheet();

  @override
  State<_PatreonSheet> createState() => _PatreonSheetState();
}

class _PatreonSheetState extends State<_PatreonSheet> {
  bool _activate = true;
  bool _busy = false;
  String? _error;

  /// The link this sheet started, so its success is shown here once.
  String? _startedLink;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on BillingError catch (error) {
      if (mounted) setState(() => _error = billingMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _canActivate(PlusController plus) =>
      !plus.adFree && !(plus.renewal?.autoRenew ?? false);

  Future<void> _connect(PlusController plus) => _run(() async {
        final link = await plus.startPatreonLink(
            activatePlus: _canActivate(plus) && _activate);
        _startedLink = link.id;
        if (!await openPatreonPage(link.url!) && mounted) {
          setState(() => _error = tr('plus_patreon_open_failed'));
        }
      });

  Future<void> _disconnect(PlusController plus) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: PhosphorIcons.linkBreak(),
      title: tr('plus_patreon_disconnect'),
      message: tr('plus_patreon_disconnect_body'),
      confirmLabel: tr('plus_patreon_disconnect'),
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await plus.unlinkPatreon();
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController>();
    final link = plus.patreonLink;
    final patreon = plus.patreon;
    final Widget body;
    if (link != null && link.isOpen) {
      body = _waiting(plus, link);
    } else if (patreon != null && patreon.linked) {
      body = _linked(plus, patreon,
          justConnected: link?.linked == true && link?.id == _startedLink);
    } else {
      body = _connectForm(plus, patreonLinkProblem(link));
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpace.lg),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: body,
        ),
      ),
    );
  }

  Widget _connectForm(PlusController plus, String? problem) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final price = plus.plan?.amountCents ?? plus.renewal?.amountCents ?? 200;
    final interval =
        plus.plan?.intervalDays ?? plus.renewal?.intervalDays ?? 31;
    final recommended = plus.patreonOffer.recommendedCents;
    final activate = _canActivate(plus);
    final reconnect = plus.patreon?.needsReauthorization ?? false;
    final error = _error ?? problem;
    return Column(
      key: const ValueKey('connect'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SheetTitle(reconnect
            ? tr('plus_patreon_reconnect_title')
            : tr('plus_patreon_connect')),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Text(tr('plus_patreon_connect_intro'),
              style: AppType.body.copyWith(color: palette.mutedText)),
        ),
        const SizedBox(height: AppSpace.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: _InfoCard(
            icon: PhosphorIcons.heart(),
            text:
                tr('plus_patreon_recommended', args: [formatUsd(recommended)]),
          ),
        ),
        if (activate) ...<Widget>[
          const SizedBox(height: AppSpace.sm),
          SwitchRow(
            icon: PhosphorIcons.calendarCheck(),
            label: tr('plus_patreon_start_plus'),
            subtitle: tr('plus_patreon_start_plus_consent',
                    args: [formatUsd(plus.chargeFor(price)), '$interval']) +
                discountConsentNote(plus.discount, price),
            value: _activate,
            onChanged: (value) => setState(() => _activate = value),
          ),
        ],
        Padding(
          padding:
              EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, AppSpace.lg),
          child: _Disclosure(lines: <String>[
            tr('plus_patreon_disclosure_credit'),
            tr('plus_disclosure_credit'),
            tr('plus_patreon_disclosure_manage'),
          ]),
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.md),
            child: Text(error,
                style: AppType.body
                    .copyWith(color: Theme.of(context).colorScheme.error)),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: PillButton(
            label: reconnect
                ? tr('plus_patreon_reconnect')
                : tr('plus_patreon_connect'),
            icon: PhosphorIcons.arrowSquareOut(),
            primary: true,
            busy: _busy,
            onPressed: () => unawaited(_connect(plus)),
          ),
        ),
      ],
    );
  }

  Widget _waiting(PlusController plus, PatreonLink link) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      key: const ValueKey('waiting'),
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpace.lg),
          const SizedBox.square(
            dimension: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            tr('plus_patreon_waiting_title'),
            textAlign: TextAlign.center,
            style: AppType.sectionHeader
                .copyWith(fontFamily: AppType.bold, color: palette.foreground),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            tr('plus_patreon_waiting_body'),
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: AppSpace.xl),
          if (link.url != null) ...[
            PillButton(
              label: tr('plus_patreon_open_again'),
              icon: PhosphorIcons.arrowSquareOut(),
              primary: true,
              onPressed: () => unawaited(openPatreonPage(link.url!)),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          PillButton(
            label: tr('plus_patreon_check_now'),
            icon: PhosphorIcons.arrowClockwise(),
            busy: plus.checkingPatreon,
            onPressed: () => unawaited(plus.checkPatreonLink()),
          ),
        ],
      ),
    );
  }

  Widget _linked(PlusController plus, PatreonMembership patreon,
      {required bool justConnected}) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final price = plus.plan?.amountCents ?? plus.renewal?.amountCents ?? 200;
    final interval =
        plus.plan?.intervalDays ?? plus.renewal?.intervalDays ?? 31;
    final pledgeUrl = patreon.pledgeUrl ?? plus.patreonOffer.pledgeUrl;
    final notes = <String>[
      if (patreon.activePatron &&
          !patreon.coversPlus &&
          patreon.monthlyCents > 0)
        tr('plus_patreon_below_price', args: [formatUsd(price), '$interval']),
      if (patreon.plusPending)
        tr('plus_patreon_plus_pending',
            args: [formatUsd(plus.chargeFor(price))]),
    ];
    return Column(
      key: const ValueKey('linked'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (justConnected)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, 0),
            child: Column(
              children: <Widget>[
                const PlusEmblem(size: 56),
                const SizedBox(height: AppSpace.md),
                Text(
                  tr('plus_patreon_connected_title'),
                  style: AppType.sectionHeader.copyWith(
                      fontFamily: AppType.bold, color: palette.foreground),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  patreon.activePatron
                      ? tr('plus_patreon_connected_body')
                      : tr('plus_patreon_connected_join'),
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: palette.mutedText),
                ),
                const SizedBox(height: AppSpace.md),
              ],
            ),
          )
        else
          SheetTitle(tr('plus_patreon')),
        ListRow(
          icon: PhosphorIcons.heart(),
          label: patreon.fullName ?? tr('plus_patreon'),
          subtitle: patreonStatusLine(patreon),
          showsNext: false,
        ),
        if (patreon.nextChargeAt != null && patreon.activePatron)
          ListRow(
            icon: PhosphorIcons.calendarBlank(),
            label: tr('plus_patreon_next_charge',
                args: [formatDay(context, patreon.nextChargeAt!)]),
            showsNext: false,
          ),
        ListRow(
          icon: PhosphorIcons.wallet(),
          label: tr('plus_patreon_credited',
              args: [formatUsd(patreon.creditedCents)]),
          showsNext: false,
        ),
        for (final note in notes)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, 0),
            child: _InfoCard(icon: PhosphorIcons.info(), text: note),
          ),
        if (_error != null)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
            child: Text(_error!,
                style: AppType.body
                    .copyWith(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: AppSpace.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (pledgeUrl != null)
                PillButton(
                  label: patreon.activePatron
                      ? tr('plus_patreon_manage_pledge')
                      : tr('plus_patreon_join'),
                  icon: PhosphorIcons.arrowSquareOut(),
                  primary: !patreon.activePatron,
                  onPressed: () => unawaited(openPatreonPage(pledgeUrl)),
                ),
              const SizedBox(height: AppSpace.md),
              PillButton(
                label: tr('plus_patreon_check_now'),
                icon: PhosphorIcons.arrowClockwise(),
                busy: _busy,
                onPressed: () => unawaited(_run(() async {
                  await plus.syncPatreon();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('plus_patreon_checked'))));
                  }
                })),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        ListRow(
          icon: PhosphorIcons.linkBreak(),
          label: tr('plus_patreon_disconnect'),
          destructive: true,
          showsNext: false,
          onTap: _busy ? null : () => unawaited(_disconnect(plus)),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
          Icon(icon, size: 22, color: palette.foreground),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(text,
                style: AppType.body.copyWith(color: palette.foreground)),
          ),
        ],
      ),
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = AppType.metadata
        .copyWith(fontSize: 12.5, height: 1.45, color: palette.mutedText);
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
