import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/settings_provider.dart';
import '../../services/flixquest_auth_service.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import 'tv_auth_screen.dart';
import '../../widgets/app_logo.dart';

class TvLandingScreen extends StatefulWidget {
  const TvLandingScreen({super.key});

  static const screenKey = Key('tv-landing-screen');

  @override
  State<TvLandingScreen> createState() => _TvLandingScreenState();
}

class _TvLandingScreenState extends State<TvLandingScreen> {
  final _authService = FlixQuestAuthService();
  bool _isEnteringAsGuest = false;
  bool _isGoogleSigningIn = false;

  Future<void> _continueWithGoogle() async {
    if (_isEnteringAsGuest || _isGoogleSigningIn) return;

    setState(() => _isGoogleSigningIn = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      Provider.of<SettingsProvider>(context, listen: false)
          .analytics
          .trackLogin('google');
      // UserState owns the destination. Its auth stream replaces this landing
      // screen with TvHomeShell when the Google session becomes active.
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showError(_googleAuthMessage(error));
      }
    } on PlatformException catch (error) {
      if (mounted && !_isGoogleSignInCancel(error)) {
        _showError(_googlePlatformMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showError('Unable to sign in with Google. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isGoogleSigningIn = false);
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
      // UserState owns the destination. Its auth stream replaces this landing
      // screen with TvHomeShell when the anonymous session becomes active.
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showError(_authMessage(error));
      }
    } catch (_) {
      if (mounted) {
        _showError('Unable to continue as guest. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isEnteringAsGuest = false);
    }
  }

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

  String _googleAuthMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'account-exists-with-different-credential' =>
        'That email is already used by an email-and-password account. '
            'Sign in with your email and password instead.',
      'network-request-failed' => 'Check your internet connection and retry.',
      'operation-not-allowed' => 'Google sign-in is currently unavailable.',
      'invalid-credential' => 'Google sign-in failed. Please try again.',
      _ => error.message ?? 'Unable to sign in with Google.',
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
      return 'Check your internet connection and retry.';
    }
    final detail =
        (error.message?.isNotEmpty ?? false) ? error.message! : error.code;
    return 'Google sign-in is not available on this device '
        '($detail). Make sure Google Play services is installed and a '
        'Google account is set up, or sign in with your email and password.';
  }

  String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'operation-not-allowed' => 'Guest access is currently unavailable.',
      'network-request-failed' => 'Check your internet connection and retry.',
      _ => error.message ?? 'Unable to continue as guest.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: TvLandingScreen.screenKey,
      backgroundColor: TvDesign.surfaceFor(context),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/grid_final.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            opacity: const AlwaysStoppedAnimation<double>(0.3),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Color(0xff0d0e0d),
                  Color(0xf20d0e0d),
                  Color(0xa60d0e0d),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x12000000),
                  Color(0x28000000),
                  Color(0xc9000000),
                ],
                stops: <double>[0, 0.55, 1],
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
                    Expanded(
                      flex: 6,
                      child: _TvLandingIntro(compact: compact),
                    ),
                    const SizedBox(width: 54),
                    Flexible(
                      flex: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xf2171817),
                                Color(0xf20e0f0e),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.44),
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
                                    'Ready to watch?',
                                    style: TextStyle(
                                      color: TvDesign.foreground,
                                      fontFamily: 'FigtreeBold',
                                      fontSize: compact ? 26 : 32,
                                      letterSpacing: -0.45,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 8 : 12),
                                  Text(
                                    'Use your remote to choose how you want to continue.',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: compact ? 16 : 19,
                                      height: 1.3,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 20 : 28),
                                  _TvLandingAction(
                                    label: 'Sign in',
                                    icon: PhosphorIcons.signIn(),
                                    autofocus: true,
                                    primary: true,
                                    enabled: !_isGoogleSigningIn &&
                                        !_isEnteringAsGuest,
                                    onActivate: () =>
                                        _open(const TvAuthScreen.signIn()),
                                  ),
                                  const SizedBox(height: 12),
                                  _TvLandingAction(
                                    label: 'Create account',
                                    icon: PhosphorIcons.userPlus(),
                                    enabled: !_isGoogleSigningIn &&
                                        !_isEnteringAsGuest,
                                    onActivate: () => _open(
                                      const TvAuthScreen.createAccount(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _TvLandingAction(
                                    label: _isGoogleSigningIn
                                        ? 'Signing in with Google…'
                                        : 'Continue with Google',
                                    icon: PhosphorIcons.googleLogo(),
                                    enabled: !_isGoogleSigningIn &&
                                        !_isEnteringAsGuest,
                                    onActivate: _continueWithGoogle,
                                  ),
                                  const SizedBox(height: 12),
                                  _TvLandingAction(
                                    label: _isEnteringAsGuest
                                        ? 'Starting guest session…'
                                        : 'Continue as guest',
                                    icon: PhosphorIcons.userCircle(),
                                    enabled: !_isEnteringAsGuest &&
                                        !_isGoogleSigningIn,
                                    onActivate: _continueAsGuest,
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
            color: Colors.white,
            fontFamily: 'FigtreeBold',
            fontSize: compact ? 44 : 58,
            height: 1,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Movies, series, and your watchlist—designed for the big screen.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 20 : 24,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _TvLandingAction extends StatelessWidget {
  const _TvLandingAction({
    required this.label,
    required this.icon,
    required this.onActivate,
    this.autofocus = false,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onActivate;
  final bool autofocus;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TvFocusable(
      semanticLabel: label,
      autofocus: autofocus,
      enabled: enabled,
      onActivate: onActivate,
      focusScale: 1.025,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.58,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: primary
                ? LinearGradient(
                    colors: <Color>[
                      colors.primary,
                      Color.lerp(
                        colors.primary,
                        colors.primaryContainer,
                        0.3,
                      )!,
                    ],
                  )
                : null,
            color: primary ? null : TvDesign.raisedSurface,
            border: Border.all(
              color: primary
                  ? colors.primary.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: primary ? colors.onPrimary : colors.onSurface,
                size: 25,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: primary ? colors.onPrimary : colors.onSurface,
                    fontFamily: 'FigtreeSB',
                    fontSize: 20,
                  ),
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(),
                color: primary ? colors.onPrimary : colors.onSurfaceVariant,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
