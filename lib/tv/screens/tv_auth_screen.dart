import 'package:flixquest/data/models/auth_session.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/error/failure.dart';
import '../../presentation/session/firebase_session_bridge.dart';
import '../../provider/settings_provider.dart';
import '../../services/auth_navigation_service.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../widgets/tv_device_limit_picker.dart';
import '../widgets/tv_form_field_tile.dart';
import '../widgets/tv_form_keyboard.dart';
import '../widgets/tv_pill_button.dart';
import 'tv_phone_sign_in_screen.dart';

enum TvAuthMode { signIn, createAccount }

enum _Field { name, email, username, password }

/// Sign-in and sign-up on the TV, typed with FlixQuest's own keyboard
/// instead of the system one, which covers half the screen and hides which
/// field it is filling.
///
/// The fields sit on the left and the keyboard on the right. Whichever field
/// was last focused is the one being typed into; the keyboard's wide key
/// steps to the next field and, on the last, submits. Left off the keyboard
/// returns to that field.
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
  final _authService = FlixQuestAuthService();
  final _keyboard = GlobalKey<TvFormKeyboardState>();
  final Map<_Field, String> _values = <_Field, String>{
    for (final field in _Field.values) field: '',
  };
  final Map<_Field, FocusNode> _nodes = <_Field, FocusNode>{
    for (final field in _Field.values)
      field: FocusNode(debugLabel: 'TV auth ${field.name}'),
  };
  late _Field _active = _fields.first;
  bool _revealPassword = false;

  /// Field errors show only once a submit has been tried.
  bool _attempted = false;
  bool _submitting = false;
  String? _error;
  int _profileId = 0;

  static const _maxLength = 128;
  static final _usernameCharacter = RegExp(r'[a-zA-Z0-9_]');

  bool get _isSignIn => widget.mode == TvAuthMode.signIn;

  List<_Field> get _fields => _isSignIn
      ? const <_Field>[_Field.email, _Field.password]
      : const <_Field>[
          _Field.name,
          _Field.email,
          _Field.username,
          _Field.password,
        ];

  String get _submitLabel =>
      _isSignIn ? tr('tv_sign_in') : tr('tv_create_account');

  @override
  void initState() {
    super.initState();
    // Prefilled for 4.2.x accounts that need one manual sign-in.
    final hint = FirebaseSessionBridge.signInEmailHint;
    if (_isSignIn && hint != null) {
      _values[_Field.email] = hint;
      _active = _Field.password;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.currentState?.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _label(_Field field) => switch (field) {
        _Field.name => tr('full_name'),
        _Field.email => tr('email_address'),
        _Field.username => tr('username'),
        _Field.password => tr('password'),
      };

  IconData _icon(_Field field) => switch (field) {
        _Field.name => PhosphorIcons.user(),
        _Field.email => PhosphorIcons.envelopeSimple(),
        _Field.username => PhosphorIcons.at(),
        _Field.password => PhosphorIcons.lock(),
      };

  /// What the field needs, shown above the keyboard while it is typed into.
  String? _hint(_Field field) => switch (field) {
        _Field.username => tr('tv_use_at_least_3_letters_or_numbers'),
        _Field.password => tr('tv_use_at_least_7_characters'),
        _ => null,
      };

  String? _validate(_Field field) {
    final value = _values[field]!;
    return switch (field) {
      _Field.name =>
        value.trim().length < 2 ? tr('tv_enter_your_full_name') : null,
      _Field.email =>
        !value.contains('@') ? tr('tv_enter_a_valid_email_address') : null,
      _Field.username =>
        value.length < 3 ? tr('tv_use_at_least_3_letters_or_numbers') : null,
      _Field.password =>
        value.length < 7 ? tr('tv_use_at_least_7_characters') : null,
    };
  }

  bool _accepts(_Field field, String character) => switch (field) {
        _Field.username => _usernameCharacter.hasMatch(character),
        _Field.email => character.trim().isNotEmpty,
        _ => true,
      };

  void _type(String text) {
    if (_submitting) return;
    final typed =
        text.split('').where((character) => _accepts(_active, character));
    final value = _values[_active]! + typed.join();
    if (typed.isEmpty || value.length > _maxLength) return;
    setState(() => _values[_active] = value);
  }

  void _delete() {
    if (_submitting) return;
    setState(() =>
        _values[_active] = _values[_active]!.characters.skipLast(1).toString());
  }

  void _clear() {
    if (_submitting) return;
    setState(() => _values[_active] = '');
  }

  void _activate(_Field field) {
    if (field != _active) setState(() => _active = field);
  }

  /// The keyboard's wide key: the next field, or submit on the last.
  void _next() {
    final index = _fields.indexOf(_active);
    if (index == _fields.length - 1) {
      _submit();
    } else {
      _activate(_fields[index + 1]);
    }
  }

  bool _focusKeyboard() => _keyboard.currentState?.requestFocus() ?? false;

  bool _focusActiveField() {
    _nodes[_active]!.requestFocus();
    return true;
  }

  void _switchMode() {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => LaravelTvAuthScreen(
          mode: _isSignIn ? TvAuthMode.createAccount : TvAuthMode.signIn,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final invalid = _fields.where((field) => _validate(field) != null);
    if (invalid.isNotEmpty) {
      setState(() {
        _attempted = true;
        _active = invalid.first;
      });
      return;
    }
    setState(() {
      _attempted = true;
      _submitting = true;
      _error = null;
    });
    try {
      late final AuthSession credential;
      if (_isSignIn) {
        final session = await _authService.withinDeviceLimit(
          (replaceDeviceId) => _authService.signIn(
            email: _values[_Field.email]!,
            password: _values[_Field.password]!,
            replaceDeviceId: replaceDeviceId,
          ),
          pick: _pickDeviceToSignOut,
        );
        if (session == null) return;
        credential = session;
        if (mounted) {
          context.read<SettingsProvider>().analytics.trackLogin('email');
        }
      } else {
        credential = await _authService.createAccount(
          fullName: _values[_Field.name]!,
          email: _values[_Field.email]!,
          username: _values[_Field.username]!,
          password: _values[_Field.password]!,
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
        setState(() => _error = tr('tv_unable_to_connect_please_try_again'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<int?> _pickDeviceToSignOut(DeviceLimitFailure limit) async =>
      mounted ? showTvDeviceLimitPicker(context, limit) : null;

  String _authMessage(AuthActionException error) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' =>
        tr('tv_the_email_or_password_is_incorrect'),
      'user-not-found' => tr('tv_no_account_exists_for_that_email'),
      'invalid-email' => tr('tv_enter_a_valid_email_address'),
      'user-disabled' => tr('tv_this_account_has_been_disabled'),
      'email-already-in-use' => tr('tv_that_email_is_already_registered'),
      'username-already-in-use' => tr('tv_that_username_is_already_in_use'),
      'weak-password' => tr('tv_use_a_password_with_at_least_7_characters'),
      'network-request-failed' =>
        tr('tv_check_your_internet_connection_and_retry'),
      _ => error.message,
    };
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

  Future<void> _signInWithGoogle() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final credential = await _authService.withinDeviceLimit(
        (replaceDeviceId) =>
            _authService.signInWithGoogle(replaceDeviceId: replaceDeviceId),
        pick: _pickDeviceToSignOut,
      );
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
          () =>
              _error = tr('tv_unable_to_sign_in_with_google_please_try_again'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, -1),
            radius: 1.4,
            colors: <Color>[
              accent.withValues(alpha: palette.dark ? 0.16 : 0.08),
              palette.page.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 650;
              final keyboardWidth = <double>[
                constraints.maxWidth * 0.5,
                TvFormKeyboard.widthFor(
                  constraints.maxHeight - (compact ? 64 : 84),
                ),
                620,
              ].reduce((a, b) => a < b ? a : b);
              return Row(
                children: <Widget>[
                  Expanded(child: _form(context, compact)),
                  SizedBox(width: compact ? 32 : 48),
                  _keyboardPanel(context, keyboardWidth, compact),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, bool compact) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final fieldGap = compact ? 10.0 : 14.0;
    return FocusTraversalGroup(
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(TvDesign.focusOutset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _isSignIn
                  ? tr('tv_sign_in_to_flixquest')
                  : tr('tv_create_your_account'),
              style: TextStyle(
                color: palette.foreground,
                fontFamily: 'FigtreeBold',
                fontSize: compact ? 28 : 36,
                letterSpacing: -0.45,
                height: 1.1,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              _isSignIn
                  ? tr('tv_sign_in_subtitle')
                  : tr('tv_create_account_subtitle'),
              style: TextStyle(
                color: palette.mutedText,
                fontSize: compact ? 15 : 18,
                height: 1.3,
              ),
            ),
            SizedBox(height: compact ? 16 : 24),
            for (final field in _fields) ...<Widget>[
              TvFormFieldTile(
                focusNode: _nodes[field]!,
                label: _label(field),
                icon: _icon(field),
                value: _values[field]!,
                obscured: field == _Field.password && !_revealPassword,
                active: field == _active,
                compact: compact,
                error: _attempted ? _validate(field) : null,
                onFocused: () => _activate(field),
                onActivate: _focusKeyboard,
                trailing: field == _Field.password
                    ? TvRevealPasswordButton(
                        revealed: _revealPassword,
                        onActivate: () => setState(
                          () => _revealPassword = !_revealPassword,
                        ),
                        onExitTowardKeyboard: _focusKeyboard,
                      )
                    : null,
              ),
              SizedBox(height: fieldGap),
            ],
            if (!_isSignIn) ...<Widget>[
              _ProfilePicker(
                selectedId: _profileId,
                compact: compact,
                onSelected: (value) => setState(() => _profileId = value),
              ),
              SizedBox(height: fieldGap),
            ],
            if (_error != null) ...<Widget>[
              Text(
                _error!,
                style: TextStyle(
                  color: colors.error,
                  fontFamily: 'FigtreeSB',
                  fontSize: compact ? 15 : 17,
                ),
              ),
              SizedBox(height: fieldGap),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                TvPillButton(
                  label: _submitting ? tr('tv_please_wait') : _submitLabel,
                  semanticLabel: _submitLabel,
                  icon: _isSignIn
                      ? PhosphorIcons.signIn()
                      : PhosphorIcons.userPlus(),
                  enabled: !_submitting,
                  prominent: true,
                  height: compact ? 46 : 52,
                  onActivate: _submit,
                ),
                TvPillButton(
                  label: tr('continue_with_google'),
                  icon: PhosphorIcons.googleLogo(),
                  enabled: !_submitting,
                  height: compact ? 46 : 52,
                  onActivate: _signInWithGoogle,
                ),
                TvPillButton(
                  label: tr('tv_phone_sign_in'),
                  icon: PhosphorIcons.qrCode(),
                  enabled: !_submitting,
                  height: compact ? 46 : 52,
                  onActivate: () => Navigator.of(context)
                      .pushReplacement<void, void>(MaterialPageRoute<void>(
                          builder: (_) => const TvPhoneSignInScreen())),
                ),
              ],
            ),
            SizedBox(height: compact ? 14 : 20),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _SwitchModeLink(
                prompt: _isSignIn
                    ? tr('tv_new_to_flixquest')
                    : tr('tv_already_have_an_account'),
                action: _isSignIn ? tr('tv_create_account') : tr('tv_sign_in'),
                enabled: !_submitting,
                onActivate: _switchMode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyboardPanel(BuildContext context, double width, bool compact) {
    final palette = TvPalette.of(context);
    final hint = _hint(_active);
    final last = _active == _fields.last;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_icon(_active), color: palette.foreground, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _label(_active).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.foreground,
                    fontFamily: 'FigtreeBold',
                    fontSize: compact ? 14 : 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hint ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: compact ? 14 : 16,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          TvFormKeyboard(
            key: _keyboard,
            width: width,
            onType: _type,
            onDelete: _delete,
            onClear: _clear,
            onAction: _next,
            actionLabel: last
                ? (_submitting ? tr('tv_please_wait') : _submitLabel)
                : tr('tv_keyboard_next'),
            actionIcon: last
                ? (_isSignIn
                    ? PhosphorIcons.signIn()
                    : PhosphorIcons.userPlus())
                : PhosphorIcons.arrowRight(),
            // The fields sit on the keyboard's left, or its right in RTL.
            onExitLeft: rtl ? null : _focusActiveField,
            onExitRight: rtl ? _focusActiveField : null,
          ),
        ],
      ),
    );
  }
}

/// "New to FlixQuest? Create account": swaps sign-in and sign-up in place.
class _SwitchModeLink extends StatefulWidget {
  const _SwitchModeLink({
    required this.prompt,
    required this.action,
    required this.enabled,
    required this.onActivate,
  });

  final String prompt;
  final String action;
  final bool enabled;
  final VoidCallback onActivate;

  @override
  State<_SwitchModeLink> createState() => _SwitchModeLinkState();
}

class _SwitchModeLinkState extends State<_SwitchModeLink> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return TvFocusable(
      semanticLabel: '${widget.prompt} ${widget.action}',
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _focused ? palette.focusFill : Colors.transparent,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: '${widget.prompt} ',
                style: TextStyle(
                  color: _focused ? palette.onFocusMuted : palette.mutedText,
                ),
              ),
              TextSpan(
                text: widget.action,
                style: TextStyle(
                  color: _focused ? palette.onFocus : palette.foreground,
                  fontFamily: 'FigtreeBold',
                  decoration: _focused ? null : TextDecoration.underline,
                ),
              ),
            ],
          ),
          style: const TextStyle(fontFamily: 'FigtreeSB', fontSize: 17),
        ),
      ),
    );
  }
}

class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({
    required this.selectedId,
    required this.compact,
    required this.onSelected,
  });

  final int selectedId;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final size = compact ? 44.0 : 56.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          tr('tv_choose_a_profile_image'),
          style: TextStyle(
            color: palette.mutedText,
            fontFamily: 'FigtreeSB',
            fontSize: compact ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final id in const <int>[0, 1, 2, 3, 4])
              TvFocusable(
                semanticLabel: tr(
                  'tv_profile_image_semantics',
                  namedArgs: {'number': '${id + 1}'},
                ),
                selected: selectedId == id,
                onActivate: () => onSelected(id),
                focusScale: 1.08,
                borderRadius: BorderRadius.circular(size),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selectedId == id ? palette.foreground : null,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/profiles/$id.png',
                      width: size,
                      height: size,
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

class TvAuthScreen extends StatelessWidget {
  const TvAuthScreen({required this.mode, super.key});
  const TvAuthScreen.signIn({super.key}) : mode = TvAuthMode.signIn;
  const TvAuthScreen.createAccount({super.key})
      : mode = TvAuthMode.createAccount;
  final TvAuthMode mode;
  @override
  Widget build(BuildContext context) => LaravelTvAuthScreen(mode: mode);
}
