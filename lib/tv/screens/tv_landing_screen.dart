import 'package:flixquest/services/flixquest_auth_service.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/error/failure.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../widgets/tv_device_limit_picker.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_poster_wall.dart';
import 'tv_auth_screen.dart';
import 'tv_phone_sign_in_screen.dart';
import '../../widgets/app_logo.dart';

class LaravelTvLandingScreen extends StatefulWidget {
  const LaravelTvLandingScreen({super.key});

  static const screenKey = Key('tv-landing-screen');

  @override
  State<LaravelTvLandingScreen> createState() => _TvLandingScreenState();
}

class _TvLandingScreenState extends State<LaravelTvLandingScreen> {
  final _authService = FlixQuestAuthService();
  bool _isEnteringAsGuest = false;
  bool _isGoogleSigningIn = false;

  Future<void> _continueWithGoogle() async {
    if (_isEnteringAsGuest || _isGoogleSigningIn) return;

    setState(() => _isGoogleSigningIn = true);
    try {
      await _authService.withinDeviceLimit(
        (replaceDeviceId) =>
            _authService.signInWithGoogle(replaceDeviceId: replaceDeviceId),
        pick: _pickDeviceToSignOut,
      );
      if (!mounted) return;
      Provider.of<SettingsProvider>(context, listen: false)
          .analytics
          .trackLogin('google');
      // UserState owns the destination. Its session gate replaces this landing
      // screen with TvHomeShell when the Google session becomes active.
    } on AuthActionException catch (error) {
      if (mounted) {
        _showError(_googleAuthMessage(error));
      }
    } on PlatformException catch (error) {
      if (mounted && !_isGoogleSignInCancel(error)) {
        _showError(_googlePlatformMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showError(tr('tv_unable_to_sign_in_with_google_please_try_again'));
      }
    } finally {
      if (mounted) setState(() => _isGoogleSigningIn = false);
    }
  }

  /// Guests are asked once more, with what an account adds, since a guest's
  /// list never leaves this TV.
  Future<void> _confirmGuest() async {
    if (_isEnteringAsGuest || _isGoogleSigningIn) return;
    final choice = await showTvDialog<bool>(
      context: context,
      title: tr('tv_guest_confirm_title'),
      content: Text(tr('tv_guest_confirm_body')),
      actions: <TvDialogAction>[
        TvDialogAction(
          label: tr('tv_create_free_account'),
          isPrimary: true,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        TvDialogAction(
          label: tr('tv_continue_as_guest'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice) {
      await _continueAsGuest();
    } else {
      _open(const TvAuthScreen.createAccount());
    }
  }

  Future<void> _continueAsGuest() async {
    if (_isEnteringAsGuest) return;

    setState(() => _isEnteringAsGuest = true);
    try {
      await _authService.signInAnonymously();
      if (!mounted) return;
      Provider.of<SettingsProvider>(context, listen: false)
          .analytics
          .trackLogin('anonymous');
      // UserState owns the destination; the local guest session opens TvHomeShell.
    } on AuthActionException catch (error) {
      if (mounted) {
        _showError(_authMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showError(tr('tv_unable_to_continue_as_guest_check_your_connection'));
      }
    } finally {
      if (mounted) setState(() => _isEnteringAsGuest = false);
    }
  }

  Future<int?> _pickDeviceToSignOut(DeviceLimitFailure limit) async =>
      mounted ? showTvDeviceLimitPicker(context, limit) : null;

  void _open(Widget screen) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, maxLines: 2)),
    );
  }

  String _googleAuthMessage(AuthActionException error) {
    return switch (error.code) {
      'account-exists-with-different-credential' => error.message,
      'network-request-failed' =>
        tr('tv_check_your_internet_connection_and_retry'),
      'operation-not-allowed' =>
        tr('tv_google_sign_in_is_currently_unavailable'),
      'invalid-credential' => tr('google_signin_failed'),
      _ => error.message,
    };
  }

  bool _isGoogleSignInCancel(PlatformException error) {
    final code = error.code.toLowerCase();
    return code.contains('canceled') ||
        code.contains('cancelled') ||
        code.contains('interrupted') ||
        code.contains('user_cancelled');
  }

  String _googlePlatformMessage(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code == 'network_error' ||
        error.message?.toLowerCase().contains('network') == true) {
      return tr('tv_check_your_internet_connection_and_retry');
    }
    final detail =
        (error.message?.isNotEmpty ?? false) ? error.message! : error.code;
    return tr('tv_google_unavailable_device', namedArgs: {'detail': detail});
  }

  String _authMessage(AuthActionException error) {
    return switch (error.code) {
      'operation-not-allowed' => tr('tv_guest_access_is_currently_unavailable'),
      'network-request-failed' =>
        tr('tv_check_your_internet_connection_and_retry'),
      _ => error.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return Scaffold(
      key: LaravelTvLandingScreen.screenKey,
      backgroundColor: TvDesign.surfaceFor(context),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const TvPosterWall(),
          // Heavy behind the intro text, light enough on the right that the
          // wall reads around the actions panel.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  palette.scrim(0.94),
                  palette.scrim(0.84),
                  palette.scrim(0.5),
                ],
                stops: const <double>[0, 0.42, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  palette.scrim(0.2),
                  palette.scrim(0),
                  palette.scrim(0.85),
                ],
                stops: const <double>[0, 0.4, 1],
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 54, vertical: 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 650;
                return Row(
                  children: <Widget>[
                    // Compact screens give the actions half the width, so
                    // their labels stay on one line.
                    Expanded(
                      flex: compact ? 5 : 6,
                      child: _TvLandingIntro(compact: compact),
                    ),
                    SizedBox(width: compact ? 40 : 54),
                    Flexible(
                      flex: compact ? 5 : 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                palette.raisedSurface.withValues(alpha: 0.95),
                                palette.surface.withValues(alpha: 0.95),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: palette.hairline),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: palette.dark ? 0.44 : 0.12,
                                ),
                                blurRadius: 34,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 24 : 32),
                            child: FocusTraversalGroup(
                              policy: ReadingOrderTraversalPolicy(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    tr('tv_ready_to_watch'),
                                    style: TextStyle(
                                      color: palette.foreground,
                                      fontFamily: 'FigtreeBold',
                                      fontSize: compact ? 26 : 32,
                                      letterSpacing: -0.45,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 8 : 12),
                                  Text(
                                    tr('tv_landing_pitch'),
                                    style: TextStyle(
                                      color: palette.mutedText,
                                      fontSize: compact ? 16 : 19,
                                      height: 1.3,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 16 : 28),
                                  // The phone covers signing in, signing up
                                  // and Google without typing on the remote.
                                  _TvLandingAction(
                                    label: tr('tv_phone_sign_in'),
                                    icon: PhosphorIcons.qrCode(),
                                    autofocus: true,
                                    primary: true,
                                    compact: compact,
                                    enabled: !_isGoogleSigningIn &&
                                        !_isEnteringAsGuest,
                                    onActivate: () => _open(
                                      const TvPhoneSignInScreen(),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 8 : 12),
                                  _TvLandingAction(
                                    label: tr('tv_create_free_account'),
                                    icon: PhosphorIcons.userPlus(),
                                    compact: compact,
                                    enabled: !_isGoogleSigningIn &&
                                        !_isEnteringAsGuest,
                                    onActivate: () => _open(
                                      const TvAuthScreen.createAccount(),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 8 : 12),
                                  _TvLandingAction(
                                    label: tr('tv_sign_in'),
                                    icon: PhosphorIcons.signIn(),
                                    compact: compact,
                                    enabled: !_isGoogleSigningIn &&
                                        !_isEnteringAsGuest,
                                    onActivate: () =>
                                        _open(const TvAuthScreen.signIn()),
                                  ),
                                  SizedBox(height: compact ? 8 : 12),
                                  _TvLandingAction(
                                    label: _isGoogleSigningIn
                                        ? tr('tv_signing_in_with_google')
                                        : tr('continue_with_google'),
                                    icon: PhosphorIcons.googleLogo(),
                                    compact: compact,
                                    enabled: !_isGoogleSigningIn &&
                                        !_isEnteringAsGuest,
                                    onActivate: _continueWithGoogle,
                                  ),
                                  SizedBox(height: compact ? 12 : 20),
                                  _TvGuestLink(
                                    label: _isEnteringAsGuest
                                        ? tr('tv_starting_guest_session')
                                        : tr('tv_continue_as_guest'),
                                    caption: tr('tv_guest_caption'),
                                    enabled: !_isEnteringAsGuest &&
                                        !_isGoogleSigningIn,
                                    onActivate: _confirmGuest,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TvLandingIntro extends StatelessWidget {
  const _TvLandingIntro({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: compact ? 82 : 104,
          height: compact ? 82 : 104,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const AppLogo(),
        ),
        SizedBox(height: compact ? 22 : 30),
        Text(
          'FlixQuest TV',
          style: TextStyle(
            color: palette.foreground,
            fontFamily: 'FigtreeBold',
            fontSize: compact ? 44 : 58,
            height: 1,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            tr('tv_movies_series_and_your_watchlist_designed_for_the_big_screen'),
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: compact ? 20 : 24,
              height: 1.35,
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 32),
        for (final (icon, text) in <(IconData, String)>[
          (
            PhosphorIcons.devices(),
            tr('tv_your_list_and_history_stay_in_sync_across_your_signed_in_devices'),
          ),
          (PhosphorIcons.playCircle(), tr('tv_benefit_resume')),
          (PhosphorIcons.sparkle(), tr('tv_benefit_plus')),
        ])
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 10 : 14),
            child: Row(
              children: <Widget>[
                Icon(icon, color: palette.foreground, size: compact ? 22 : 26),
                const SizedBox(width: 14),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: palette.foreground,
                        fontFamily: 'FigtreeSB',
                        fontSize: compact ? 16 : 19,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Guest mode, kept quiet below the account options: a plain line with what
/// it leaves out, not a button that competes with them.
class _TvGuestLink extends StatefulWidget {
  const _TvGuestLink({
    required this.label,
    required this.caption,
    required this.enabled,
    required this.onActivate,
  });

  final String label;
  final String caption;
  final bool enabled;
  final VoidCallback onActivate;

  @override
  State<_TvGuestLink> createState() => _TvGuestLinkState();
}

class _TvGuestLinkState extends State<_TvGuestLink> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return TvFocusable(
      semanticLabel: '${widget.label}. ${widget.caption}',
      enabled: widget.enabled,
      onActivate: widget.onActivate,
      onFocusChanged: (hasFocus) {
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _focused ? palette.focusFill : Colors.transparent,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.label,
              style: TextStyle(
                color: _focused ? palette.onFocus : palette.secondaryText,
                fontFamily: 'FigtreeSB',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.caption,
              style: TextStyle(
                color: _focused ? palette.onFocusMuted : palette.mutedText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvLandingAction extends StatefulWidget {
  const _TvLandingAction({
    required this.label,
    required this.icon,
    required this.onActivate,
    this.autofocus = false,
    this.primary = false,
    this.enabled = true,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onActivate;
  final bool autofocus;
  final bool primary;
  final bool enabled;

  /// Shorter, so four actions fit a 540-high screen.
  final bool compact;

  @override
  State<_TvLandingAction> createState() => _TvLandingActionState();
}

/// Translucent at rest and white under focus, like every TV button; the main
/// action only rests a little brighter.
class _TvLandingActionState extends State<_TvLandingAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final foreground = _focused ? palette.onFocus : palette.foreground;
    return TvFocusable(
      semanticLabel: widget.label,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onActivate: widget.onActivate,
      onFocusChanged: (hasFocus) {
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1.02,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: widget.enabled ? 1 : 0.58,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: widget.compact ? 50 : 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _focused
                ? palette.focusFill
                : widget.primary
                    ? palette.idleFillStrong
                    : palette.idleFill,
            borderRadius: BorderRadius.circular(TvDesign.cardRadius),
          ),
          child: Row(
            children: <Widget>[
              Icon(widget.icon, color: foreground, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: foreground,
                    fontFamily: 'FigtreeSB',
                    fontSize: widget.compact ? 17 : 19,
                  ),
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(),
                color: _focused ? palette.onFocusMuted : palette.mutedText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TvLandingScreen extends StatelessWidget {
  const TvLandingScreen({super.key});
  static const screenKey = LaravelTvLandingScreen.screenKey;
  @override
  Widget build(BuildContext context) => const LaravelTvLandingScreen();
}
