import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../functions/function.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../provider/settings_provider.dart';
import '../../services/globle_method.dart';
import '../../services/flixquest_auth_service.dart';
import '../../widgets/google_sign_in_button.dart';
import '../user/login_screen.dart';
import '../user/signup_screen.dart';
import '../../widgets/app_logo.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _authService = FlixQuestAuthService();
  bool _loadingAnonymous = false;
  bool _loadingGoogle = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/grid_final.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0xF0000000)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 760;
                      const intro = _Intro();
                      final actions = _actionsCard(settings);
                      return Flex(
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (wide) Expanded(child: intro) else intro,
                          SizedBox(width: wide ? 56 : 0, height: wide ? 0 : 36),
                          if (wide)
                            SizedBox(width: 390, child: actions)
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: actions,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(SettingsProvider settings) {
    final palette = AppPalette.of(context);
    final busy = _loadingGoogle || _loadingAnonymous;
    Widget wide(Widget child) => SizedBox(width: double.infinity, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('login_signup'),
              style: AppType.sectionHeader.copyWith(
                fontFamily: AppType.bold,
                fontSize: 22,
                color: palette.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('unlimited_on_cinemax'),
              style: AppType.body.copyWith(color: palette.mutedText),
            ),
            const SizedBox(height: 24),
            wide(
              PillButton(
                primary: true,
                height: 50,
                label: tr('log_in'),
                onPressed: busy ? null : () => _push(const LoginScreen()),
              ),
            ),
            const SizedBox(height: 12),
            wide(
              PillButton(
                height: 50,
                label: tr('sign_up'),
                onPressed: busy ? null : () => _push(const SignupScreen()),
              ),
            ),
            const SizedBox(height: 12),
            GoogleSignInButton(
              loading: _loadingGoogle,
              enabled: !_loadingAnonymous,
              onPressed: () => _continueWithGoogle(settings),
            ),
            const SizedBox(height: 12),
            wide(
              PillButton(
                height: 50,
                busy: _loadingAnonymous,
                icon: PhosphorIcons.userCircleDashed(),
                label: tr('continue_anonymously'),
                onPressed: _loadingGoogle
                    ? null
                    : () => _continueAnonymously(settings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continueAnonymously(SettingsProvider settings) async {
    if (_loadingGoogle) return;
    setState(() => _loadingAnonymous = true);
    try {
      if (!await checkConnection()) {
        if (mounted) _showError(tr('check_connection'));
        return;
      }
      await _authService.signInAnonymously();
      settings.analytics.trackLogin('anonymous');
      // UserState's auth stream owns the handheld/TV destination.
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _loadingAnonymous = false);
    }
  }

  Future<void> _continueWithGoogle(SettingsProvider settings) async {
    if (_loadingAnonymous) return;
    setState(() => _loadingGoogle = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) return;
      settings.analytics.trackLogin('google');
      // UserState's auth stream swaps this landing screen for the app shell.
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_googleAuthMessage(error));
    } on PlatformException catch (error) {
      if (mounted && !_isGoogleSignInCancel(error)) {
        _showError(_googlePlatformMessage(error));
      }
    } catch (_) {
      if (mounted) _showError(tr('google_signin_failed'));
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  String _googleAuthMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'account-exists-with-different-credential' =>
        tr('google_email_conflict'),
      'network-request-failed' => tr('check_connection'),
      'invalid-credential' ||
      'invalid-email' =>
        tr('invalid_credential'),
      'user-disabled' => tr('banned_user'),
      _ => error.message ?? tr('error_occured'),
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
      return tr('check_connection');
    }
    final detail = (error.message?.isNotEmpty ?? false)
        ? error.message!
        : error.code;
    return '${tr('google_signin_failed')}\n$detail';
  }

  void _showError(String message) {
    GlobalMethods.showCustomScaffoldMessage(
      SnackBar(content: Text(message, maxLines: 3)),
      context,
    );
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Hero(
            tag: 'logo_shadow',
            child: const AppLogo(),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          tr('thousands_of'),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'FigtreeBold',
            fontSize: 40,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${tr('trending_movies')} • ${tr('popular_tv_shows')}',
          style: const TextStyle(color: Colors.white70, fontSize: 17),
        ),
      ],
    );
  }
}
