import 'package:flixquest/data/models/auth_session.dart';
import '../../legacy/firebase_auth/tv/screens/tv_auth_screen.dart' as legacy;
import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../provider/settings_provider.dart';
import '../../services/auth_navigation_service.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../widgets/tv_pill_button.dart';

enum TvAuthMode { signIn, createAccount }

class LaravelTvAuthScreen extends StatefulWidget {
  const LaravelTvAuthScreen({required this.mode, super.key});

  const LaravelTvAuthScreen.signIn({super.key}) : mode = TvAuthMode.signIn;

  const LaravelTvAuthScreen.createAccount({super.key})
      : mode = TvAuthMode.createAccount;

  final TvAuthMode mode;

  @override
  State<LaravelTvAuthScreen> createState() => _TvAuthScreenState();
}

class _TvAuthScreenState extends State<LaravelTvAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = FlixQuestAuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'TV full name');
  final _emailFocus = FocusNode(debugLabel: 'TV email');
  final _usernameFocus = FocusNode(debugLabel: 'TV username');
  final _passwordFocus = FocusNode(debugLabel: 'TV password');
  final _confirmPasswordFocus = FocusNode(debugLabel: 'TV confirm password');
  bool _submitting = false;
  final bool _obscurePassword = true;
  String? _error;
  int _profileId = 0;

  bool get _isSignIn => widget.mode == TvAuthMode.signIn;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      late final AuthSession credential;
      if (_isSignIn) {
        credential = await _authService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (mounted) {
          context.read<SettingsProvider>().analytics.trackLogin('email');
        }
      } else {
        credential = await _authService.createAccount(
          fullName: _nameController.text,
          email: _emailController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          profileId: _profileId,
        );
        if (mounted) {
          context.read<SettingsProvider>().analytics.trackSignup();
        }
      }
      if (mounted) {
        await AuthNavigationService.returnToAppRoot(
          context,
          authenticatedUserId: credential.user.id.toString(),
        );
      }
    } on AuthActionException catch (error) {
      if (mounted) setState(() => _error = _authMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to connect. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _authMessage(AuthActionException error) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' =>
        'The email or password is incorrect.',
      'user-not-found' => 'No account exists for that email.',
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'email-already-in-use' => 'That email is already registered.',
      'username-already-in-use' => 'That username is already in use.',
      'weak-password' => 'Use a password with at least 7 characters.',
      'network-request-failed' => 'Check your internet connection and retry.',
      _ => error.message,
    };
  }

  String _googleAuthMessage(AuthActionException error) {
    return switch (error.code) {
      'account-exists-with-different-credential' =>
        error.message,
      'network-request-failed' => 'Check your internet connection and retry.',
      'operation-not-allowed' => 'Google sign-in is currently unavailable.',
      'invalid-credential' => 'Google sign-in failed. Please try again.',
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
      return 'Check your internet connection and retry.';
    }
    final detail =
        (error.message?.isNotEmpty ?? false) ? error.message! : error.code;
    return 'Google sign-in is not available on this device '
        '($detail). Make sure Google Play services is installed and a '
        'Google account is set up, or sign in with your email and password.';
  }

  Future<void> _signInWithGoogle() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) return;
      if (mounted) {
        context.read<SettingsProvider>().analytics.trackLogin('google');
      }
      if (mounted) {
        await AuthNavigationService.returnToAppRoot(
          context,
          authenticatedUserId: credential.user.id.toString(),
        );
      }
    } on AuthActionException catch (error) {
      if (mounted) setState(() => _error = _googleAuthMessage(error));
    } on PlatformException catch (error) {
      if (mounted && !_isGoogleSignInCancel(error)) {
        setState(() => _error = _googlePlatformMessage(error));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to sign in with Google. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 52, vertical: 30),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 170,
                  child: _BackAction(onActivate: () => Navigator.pop(context)),
                ),
                const SizedBox(width: 36),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: SingleChildScrollView(
                        clipBehavior: Clip.hardEdge,
                        padding: const EdgeInsets.all(TvDesign.focusOutset),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                palette.raisedSurface,
                                palette.surface,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: palette.hairline),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: palette.dark ? 0.34 : 0.1,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 24 : 34),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(
                                        _isSignIn
                                            ? PhosphorIcons.signIn()
                                            : PhosphorIcons.userPlus(),
                                        color: palette.mutedText,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 13),
                                      Text(
                                        _isSignIn
                                            ? 'Sign in to FlixQuest'
                                            : 'Create your account',
                                        style: TextStyle(
                                          color: palette.foreground,
                                          fontFamily: 'FigtreeBold',
                                          fontSize: compact ? 28 : 34,
                                          letterSpacing: -0.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: compact ? 18 : 25),
                                  if (_isSignIn) ...<Widget>[
                                    TvFocusable(
                                      semanticLabel: 'Continue with Google',
                                      enabled: !_submitting,
                                      onActivate: _signInWithGoogle,
                                      focusScale: 1.02,
                                      borderRadius: BorderRadius.circular(11),
                                      child: Container(
                                        height: 56,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.raisedSurface,
                                          border: Border.all(
                                            color: palette.hairline,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Icon(
                                              PhosphorIcons.googleLogo(),
                                              color: palette.foreground,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 13),
                                            Expanded(
                                              child: Text(
                                                'Continue with Google',
                                                style: TextStyle(
                                                  color: palette.foreground,
                                                  fontFamily: 'FigtreeSB',
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              PhosphorIcons.caretRight(),
                                              color: palette.mutedText,
                                              size: 21,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: compact ? 20 : 26),
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Divider(
                                            color: palette.hairline,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: Text(
                                            'or',
                                            style: TextStyle(
                                              color: palette.mutedText,
                                              fontFamily: 'FigtreeSB',
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: palette.hairline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: compact ? 18 : 24),
                                  ],
                                  if (!_isSignIn) ...<Widget>[
                                    _TvAuthField(
                                      controller: _nameController,
                                      focusNode: _nameFocus,
                                      nextFocusNode: _emailFocus,
                                      label: 'Full name',
                                      icon: PhosphorIcons.user(),
                                      autofocus: true,
                                      validator: (value) => value == null ||
                                              value.trim().length < 2
                                          ? 'Enter your full name.'
                                          : null,
                                    ),
                                    const SizedBox(height: 13),
                                  ],
                                  _TvAuthField(
                                    controller: _emailController,
                                    focusNode: _emailFocus,
                                    nextFocusNode: _isSignIn
                                        ? _passwordFocus
                                        : _usernameFocus,
                                    label: 'Email address',
                                    icon: PhosphorIcons.envelopeSimple(),
                                    autofocus: _isSignIn,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) => value == null ||
                                            !value.trim().contains('@')
                                        ? 'Enter a valid email address.'
                                        : null,
                                  ),
                                  if (!_isSignIn) ...<Widget>[
                                    const SizedBox(height: 13),
                                    _TvAuthField(
                                      controller: _usernameController,
                                      focusNode: _usernameFocus,
                                      nextFocusNode: _passwordFocus,
                                      label: 'Username',
                                      icon: PhosphorIcons.at(),
                                      inputFormatters: <TextInputFormatter>[
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z0-9_]'),
                                        ),
                                      ],
                                      validator: (value) => value == null ||
                                              value.trim().length < 3
                                          ? 'Use at least 3 letters or numbers.'
                                          : null,
                                    ),
                                  ],
                                  const SizedBox(height: 13),
                                  _TvAuthField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    nextFocusNode: _isSignIn
                                        ? null
                                        : _confirmPasswordFocus,
                                    label: 'Password',
                                    icon: PhosphorIcons.lock(),
                                    obscureText: _obscurePassword,
                                    textInputAction: _isSignIn
                                        ? TextInputAction.done
                                        : TextInputAction.next,
                                    onSubmitted:
                                        _isSignIn ? (_) => _submit() : null,
                                    validator: (value) =>
                                        value == null || value.length < 7
                                            ? 'Use at least 7 characters.'
                                            : null,
                                  ),
                                  if (!_isSignIn) ...<Widget>[
                                    const SizedBox(height: 13),
                                    _TvAuthField(
                                      controller: _confirmPasswordController,
                                      focusNode: _confirmPasswordFocus,
                                      label: 'Confirm password',
                                      icon: PhosphorIcons.checkCircle(),
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _submit(),
                                      validator: (value) =>
                                          value != _passwordController.text
                                              ? 'Passwords do not match.'
                                              : null,
                                    ),
                                    const SizedBox(height: 18),
                                    _ProfilePicker(
                                      selectedId: _profileId,
                                      onSelected: (value) =>
                                          setState(() => _profileId = value),
                                    ),
                                  ],
                                  if (_error != null) ...<Widget>[
                                    const SizedBox(height: 16),
                                    Text(
                                      _error!,
                                      style: TextStyle(
                                        color: colors.error,
                                        fontFamily: 'FigtreeSB',
                                        fontSize: 17,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TvPillButton(
                                      label: _submitting
                                          ? 'Please wait…'
                                          : _isSignIn
                                              ? 'Sign in'
                                              : 'Create account',
                                      semanticLabel: _isSignIn
                                          ? 'Sign in'
                                          : 'Create account',
                                      icon: _isSignIn
                                          ? PhosphorIcons.signIn()
                                          : PhosphorIcons.userPlus(),
                                      enabled: !_submitting,
                                      prominent: true,
                                      height: 52,
                                      onActivate: _submit,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    );
  }
}

class _TvAuthField extends StatefulWidget {
  const _TvAuthField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    this.nextFocusNode,
    this.autofocus = false,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final String label;
  final IconData icon;
  final bool autofocus;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_TvAuthField> createState() => _TvAuthFieldState();
}

class _TvAuthFieldState extends State<_TvAuthField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focused != widget.focusNode.hasFocus) {
      setState(() => _focused = widget.focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: palette.raisedSurface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: _focused
              ? palette.foreground
              : palette.foreground.withValues(alpha: 0.09),
          width: _focused ? 3 : 1,
        ),
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        validator: widget.validator,
        onFieldSubmitted: (value) {
          if (widget.nextFocusNode != null) {
            widget.nextFocusNode!.requestFocus();
          } else {
            widget.onSubmitted?.call(value);
          }
        },
        style: TextStyle(color: palette.foreground, fontSize: 19),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(widget.icon, color: palette.mutedText),
          labelText: widget.label,
          labelStyle: TextStyle(color: palette.mutedText),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        ),
      ),
    );
  }
}

class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({required this.selectedId, required this.onSelected});

  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Choose a profile image',
          style: TextStyle(
            color: palette.foreground,
            fontFamily: 'FigtreeSB',
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 13,
          runSpacing: 13,
          children: <Widget>[
            for (final id in const <int>[0, 1, 2, 3, 4])
              TvFocusable(
                semanticLabel: 'Profile image ${id + 1}',
                onActivate: () => onSelected(id),
                focusScale: 1.04,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  padding: EdgeInsets.all(selectedId == id ? 3 : 0),
                  decoration: BoxDecoration(
                    color: selectedId == id ? palette.foreground : null,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/images/profiles/$id.png',
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BackAction extends StatelessWidget {
  const _BackAction({required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return TvFocusable(
      semanticLabel: 'Back',
      onActivate: onActivate,
      focusScale: 1.025,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: palette.raisedSurface,
          border: Border.all(
            color: palette.foreground.withValues(alpha: 0.09),
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PhosphorIcons.caretLeft(), color: palette.foreground),
            const SizedBox(width: 8),
            Text(
              'Back',
              style: TextStyle(
                color: palette.foreground,
                fontFamily: 'FigtreeSB',
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TvAuthScreen extends StatelessWidget {
  const TvAuthScreen({required this.mode, super.key});
  const TvAuthScreen.signIn({super.key}) : mode = TvAuthMode.signIn;
  const TvAuthScreen.createAccount({super.key}) : mode = TvAuthMode.createAccount;
  final TvAuthMode mode;
  @override
  Widget build(BuildContext context) => AuthRuntime.enabled
      ? LaravelTvAuthScreen(mode: mode)
      : legacy.TvAuthScreen(mode: mode == TvAuthMode.signIn ? legacy.TvAuthMode.signIn : legacy.TvAuthMode.createAccount);
}
