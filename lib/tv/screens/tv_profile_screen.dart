import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../app/tv_design.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_page_header.dart';
import '../widgets/tv_pill_button.dart';

class TvProfileScreen extends StatelessWidget {
  const TvProfileScreen({
    required this.metrics,
    this.focusController,
    super.key,
  });

  final TvShellMetrics metrics;
  final TvScreenFocusController? focusController;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return _ProfileLayout(
        metrics: metrics,
        name: 'Guest',
        subtitle: 'Local watchlist and browsing session',
        profileId: 0,
        isGuest: true,
        focusController: focusController,
        onSignOut: () => _confirmSignOut(context),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['name']?.toString().trim();
        final username = data?['username']?.toString().trim();
        final profileId = data?['profileId'] is int
            ? data!['profileId'] as int
            : int.tryParse(data?['profileId']?.toString() ?? '') ?? 0;
        return _ProfileLayout(
          metrics: metrics,
          name: name == null || name.isEmpty
              ? user.displayName ?? 'FlixQuest member'
              : name,
          subtitle: username == null || username.isEmpty
              ? user.email ?? 'Signed in'
              : '@$username',
          profileId: profileId,
          photoUrl: data?['photoUrl']?.toString(),
          loading: snapshot.connectionState != ConnectionState.done,
          focusController: focusController,
          onSignOut: () => _confirmSignOut(context),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    await showTvDialog<void>(
      context: context,
      title: 'Sign out?',
      content: const Text(
        'You will return to the FlixQuest TV welcome screen.',
      ),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: 'Cancel',
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        TvDialogAction(
          label: 'Sign out',
          isPrimary: true,
          onPressed: () async {
            Navigator.of(context).pop();
            await FlixQuestAuthService.signOutGoogle();
            await FirebaseAuth.instance.signOut();
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
    this.loading = false,
    this.isGuest = false,
    this.focusController,
  });

  final TvShellMetrics metrics;
  final String name;
  final String subtitle;
  final int profileId;
  final String? photoUrl;
  final VoidCallback onSignOut;
  final bool loading;
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

  @override
  Widget build(BuildContext context) {
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
                kicker: 'ACCOUNT',
                title: 'Profile',
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
                          Text(
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
                              ? 'Your list and history stay on this TV.'
                              : 'Your list and history stay in sync across '
                                  'your devices.',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: compact ? 14 : 16,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 26),
                        TvPillButton(
                          focusNode: signOutFocusNode,
                          label: 'Sign out',
                          icon: PhosphorIcons.signOut(),
                          onActivate: onSignOut,
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

class _AccountStatus extends StatelessWidget {
  const _AccountStatus({required this.isGuest, required this.compact});

  final bool isGuest;
  final bool compact;

  @override
  Widget build(BuildContext context) {
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
          isGuest ? 'LOCAL PROFILE' : 'SIGNED IN',
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
  final FocusNode _signOutFocusNode =
      FocusNode(debugLabel: 'TV profile sign out');

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
