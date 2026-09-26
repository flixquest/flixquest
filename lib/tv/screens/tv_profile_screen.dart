import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../widgets/tv_dialog.dart';

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

  Widget _profileImage({
    required ColorScheme colors,
    required double size,
  }) {
    final fallback = Container(
      width: size,
      height: size,
      color: colors.surfaceContainerHighest,
      child: Icon(
        PhosphorIcons.user(),
        color: colors.onSurfaceVariant,
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
      borderRadius: BorderRadius.circular(8),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ProfileFocusEntry(
      focusController: focusController,
      builder: (signOutFocusNode) => Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    TvDesign.pageBackground,
                    colors.primary.withValues(alpha: 0.045),
                    TvDesign.pageBackground,
                  ],
                  stops: const <double>[0, 0.72, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(metrics.contentPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ACCOUNT',
                  style: TextStyle(
                    color: colors.primary,
                    fontFamily: 'FigtreeBold',
                    fontSize: 13,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: TvDesign.foreground,
                    fontFamily: 'FigtreeBold',
                    fontSize: metrics.compact ? 31 : 37,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: metrics.compact ? 18 : 28),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: TvDesign.surfaceFor(context, emphasis: 0.005),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: TvDesign.hairline),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: EdgeInsets.all(
                              metrics.compact ? 26 : 42,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: colors.primary
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: _profileImage(
                                      colors: colors,
                                      size: metrics.compact ? 126 : 174,
                                    ),
                                  ),
                                  SizedBox(width: metrics.compact ? 26 : 38),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        if (loading)
                                          SizedBox(
                                            width: 240,
                                            child: LinearProgressIndicator(
                                              color: colors.primary,
                                              backgroundColor:
                                                  TvDesign.raisedSurface,
                                            ),
                                          )
                                        else ...<Widget>[
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: TvDesign.foreground,
                                              fontFamily: 'FigtreeBold',
                                              fontSize:
                                                  metrics.compact ? 34 : 44,
                                              letterSpacing: -1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            subtitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                              fontSize:
                                                  metrics.compact ? 17 : 20,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 22),
                                        _AccountStatus(
                                          isGuest: isGuest,
                                          compact: metrics.compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: EdgeInsets.symmetric(
                            vertical: metrics.compact ? 22 : 34,
                          ),
                          color: TvDesign.hairline,
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: EdgeInsets.all(
                              metrics.compact ? 22 : 34,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  isGuest ? 'GUEST SESSION' : 'YOUR ACCOUNT',
                                  style: const TextStyle(
                                    color: TvDesign.mutedText,
                                    fontFamily: 'FigtreeBold',
                                    fontSize: 12,
                                    letterSpacing: 1.7,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isGuest
                                      ? 'Your activity stays on this device.'
                                      : 'Your profile and watch activity stay in sync.',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: metrics.compact ? 16 : 18,
                                    height: 1.42,
                                  ),
                                ),
                                const SizedBox(height: 25),
                                TvFocusable(
                                  focusNode: signOutFocusNode,
                                  semanticLabel: 'Sign out',
                                  onActivate: onSignOut,
                                  focusScale: 1.02,
                                  borderRadius: BorderRadius.circular(7),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          colors.error.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: colors.error
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(
                                          PhosphorIcons.signOut(),
                                          color: colors.error,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Sign out',
                                          style: TextStyle(
                                            color: colors.onSurface,
                                            fontFamily: 'FigtreeSB',
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isGuest ? colors.onSurfaceVariant : colors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          isGuest ? 'LOCAL PROFILE' : 'SIGNED IN',
          style: TextStyle(
            color: colors.onSurfaceVariant,
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

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _signOutFocusNode.context != null &&
          _signOutFocusNode.canRequestFocus) {
        _signOutFocusNode.requestFocus();
      }
    });
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
