import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../presentation/billing/plus_controller.dart';
import '../../services/plus_navigation.dart';
import '../../widgets/plus/plus_format.dart';
import '../../widgets/plus/plus_visuals.dart';

import '../../mobile/widgets/verified_badge.dart';
import '../../services/auth_navigation_service.dart';
import '../app/tv_design.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_page_header.dart';
import '../widgets/tv_pill_button.dart';
import 'tv_account_screens.dart';

class LaravelTvProfileScreen extends StatelessWidget {
  const LaravelTvProfileScreen({
    required this.metrics,
    this.focusController,
    super.key,
  });

  final TvShellMetrics metrics;
  final TvScreenFocusController? focusController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: AuthRuntime.session,
        builder: (context, _) {
          final user = AuthRuntime.session.user;
          return _ProfileLayout(
              metrics: metrics,
              name: user?.name ?? tr('guest'),
              subtitle: user == null
                  ? tr('tv_local_watchlist_and_browsing_session')
                  : '@${user.username}',
              profileId: user?.profileId ?? 0,
              photoUrl: user?.photoUrl,
              verified: user?.isAccountVerified ?? false,
              isGuest: user == null,
              focusController: focusController,
              onSignOut: () => _confirmSignOut(context));
        });
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    await showTvDialog<void>(
      context: context,
      title: tr('tv_sign_out'),
      content: Text(
        tr('tv_you_will_return_to_the_flixquest_tv_welcome_screen'),
      ),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('cancel'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        TvDialogAction(
          label: tr('sign_out'),
          isPrimary: true,
          onPressed: () async {
            Navigator.of(context).pop();
            await FlixQuestAuthService().signOut();
            if (context.mounted) {
              await AuthNavigationService.returnToSignedOutRoot(context);
            }
          },
        ),
      ],
    );
  }
}

class _ProfileLayout extends StatelessWidget {
  const _ProfileLayout({
    required this.metrics,
    required this.name,
    required this.subtitle,
    required this.profileId,
    required this.onSignOut,
    this.photoUrl,
    this.verified = false,
    this.isGuest = false,
    this.focusController,
  });

  final TvShellMetrics metrics;
  final String name;

  /// The admin-granted badge, after the name as on the phone.
  final bool verified;
  final String subtitle;
  final int profileId;
  final String? photoUrl;
  final VoidCallback onSignOut;
  final bool loading = false;
  final bool isGuest;
  final TvScreenFocusController? focusController;

  Widget _profileImage(BuildContext context, {required double size}) {
    final palette = TvPalette.of(context);
    final fallback = Container(
      width: size,
      height: size,
      color: palette.raisedSurface,
      child: Icon(
        PhosphorIcons.user(),
        color: palette.mutedText,
        size: 54,
      ),
    );
    final url = photoUrl?.trim() ?? '';
    final image = url.isEmpty
        ? Image.asset(
            'assets/images/profiles/${profileId.clamp(0, 149)}.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      child: image,
    );
  }

  Future<void> _openManageAccount(BuildContext context) async {
    final previous = FocusManager.instance.primaryFocus;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TvManageAccountScreen()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (previous?.context != null && previous!.canRequestFocus) {
        previous.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final compact = metrics.compact;
    return _ProfileFocusEntry(
      focusController: focusController,
      builder: (signOutFocusNode) => Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.contentPadding,
          0,
          metrics.contentPadding,
          metrics.contentPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: TvDesign.focusOutset + 4),
              child: TvPageHeader(
                kicker: tr('tv_account'),
                title: tr('profile'),
                compact: compact,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: TvDesign.focusOutset + 4),
              child: Row(
                children: <Widget>[
                  _profileImage(context, size: compact ? 132 : 180),
                  SizedBox(width: compact ? 28 : 40),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _AccountStatus(isGuest: isGuest, compact: compact),
                        const SizedBox(height: 10),
                        if (loading)
                          SizedBox(
                            width: 240,
                            child: LinearProgressIndicator(
                              color: palette.mutedText,
                              backgroundColor: palette.raisedSurface,
                            ),
                          )
                        else ...<Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.foreground,
                                    fontFamily: 'FigtreeBold',
                                    fontSize: compact ? 34 : 46,
                                    height: 1.05,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              if (verified) ...<Widget>[
                                SizedBox(width: compact ? 8 : 12),
                                VerifiedBadge(size: compact ? 32 : 42),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.mutedText,
                              fontSize: compact ? 16 : 19,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          isGuest
                              ? tr('tv_your_list_and_history_stay_on_this_tv')
                              : tr(
                                  'tv_your_list_and_history_stay_in_sync_across_your_signed_in_devices'),
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: compact ? 14 : 16,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: compact ? 14 : 20),
                        _PlusLine(compact: compact),
                        SizedBox(height: compact ? 18 : 26),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            // The page opens on the first button.
                            if (!isGuest)
                              TvPillButton(
                                focusNode: signOutFocusNode,
                                label: tr('tv_manage_account'),
                                icon: PhosphorIcons.userGear(),
                                onActivate: () => _openManageAccount(context),
                              ),
                            TvPillButton(
                              focusNode: isGuest ? signOutFocusNode : null,
                              label: tr('sign_out'),
                              icon: PhosphorIcons.signOut(),
                              onActivate: onSignOut,
                            ),
                            if (!isGuest ||
                                (context.watch<PlusController?>()?.shouldSuggest ??
                                    false))
                              TvPillButton(
                                label: tr('plus_name'),
                                leading: const PlusMark(),
                                prominent: true,
                                onActivate: () => openPlus(context),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

/// One line on Plus under the profile: the days left for a member, or what
/// it costs while it is on sale.
class _PlusLine extends StatelessWidget {
  const _PlusLine({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final plus = context.watch<PlusController?>();
    if (plus == null) return const SizedBox.shrink();
    final until = plus.activeUntil;
    final String text;
    if (until != null) {
      text = tr('plus_ad_free_until', args: [formatDay(context, until)]);
    } else if (plus.shouldSuggest) {
      text = plus.signedIn ? tr('plus_cta_member') : tr('plus_cta_guest');
    } else {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PlusWordmark(size: compact ? 15 : 18, showName: false),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: TvPalette.of(context).mutedText,
              fontSize: compact ? 14 : 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountStatus extends StatelessWidget {
  const _AccountStatus({required this.isGuest, required this.compact});

  final bool isGuest;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isGuest ? palette.mutedText : palette.foreground,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          isGuest ? tr('tv_local_profile') : tr('tv_signed_in'),
          style: TextStyle(
            color: palette.mutedText,
            fontFamily: 'FigtreeBold',
            fontSize: compact ? 12 : 13,
            letterSpacing: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ProfileFocusEntry extends StatefulWidget {
  const _ProfileFocusEntry({required this.builder, this.focusController});

  final Widget Function(FocusNode signOutFocusNode) builder;
  final TvScreenFocusController? focusController;

  @override
  State<_ProfileFocusEntry> createState() => _ProfileFocusEntryState();
}

class _ProfileFocusEntryState extends State<_ProfileFocusEntry> {
  /// The first button: Manage account when signed in, else Sign out.
  final FocusNode _signOutFocusNode =
      FocusNode(debugLabel: 'TV profile first action');

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _requestFocus);
  }

  @override
  void didUpdateWidget(_ProfileFocusEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _requestFocus);
    }
  }

  bool _requestFocus() {
    if (_signOutFocusNode.context == null ||
        !_signOutFocusNode.canRequestFocus) {
      return false;
    }
    _signOutFocusNode.requestFocus();
    return true;
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _signOutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_signOutFocusNode);
}

class TvProfileScreen extends StatelessWidget {
  const TvProfileScreen(
      {required this.metrics, this.focusController, super.key});
  final TvShellMetrics metrics;
  final TvScreenFocusController? focusController;
  @override
  Widget build(BuildContext context) => LaravelTvProfileScreen(
      metrics: metrics, focusController: focusController);
}
