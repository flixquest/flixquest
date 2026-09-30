// ignore_for_file: use_build_context_synchronously
import '/functions/function.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '/constants/app_constants.dart';
import '/models/profile_image_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../provider/settings_provider.dart';
import '../../services/globle_method.dart';
import '../../services/flixquest_auth_service.dart';
import '../../services/auth_navigation_service.dart';
import '../../services/bookmark_sync_service.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/account_form.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _passwordVerifyFocusNode = FocusNode();
  final ProfileImages profileImages = ProfileImages();

  int profileValue = 0;
  int selectedProfile = 0;
  bool _obscureText = true;
  String _emailAddress = '';
  String _password = '';
  String _fullName = '';
  String _userName = '';
  bool _isUserVerified = false;
  final _formKey = GlobalKey<FormState>();
  final FlixQuestAuthService _authService = FlixQuestAuthService();
  final GlobalMethods _globalMethods = GlobalMethods();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordVerifyFocusNode.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Future<void> submitForm() async {
    if (_isLoading) return;
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();
    if (!isValid) return;

    if (!await checkConnection()) {
      if (mounted) {
        GlobalMethods.showCustomScaffoldMessage(
          SnackBar(
            content: Text(
              tr('check_connection'),
              maxLines: 3,
              style: kTextSmallBodyStyle,
            ),
            duration: const Duration(seconds: 3),
          ),
          context,
        );
      }
      return;
    }

    if (!mounted) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.createAccount(
        fullName: _fullName,
        email: _emailAddress,
        username: _userName,
        password: _password,
        profileId: selectedProfile,
        verified: _isUserVerified,
      );
      if (!mounted) return;
      BookmarkSyncService.instance.autoSyncIfSignedIn();
      Provider.of<SettingsProvider>(context, listen: false)
          .analytics
          .trackSignup();
      await AuthNavigationService.returnToAppRoot(
        context,
        authenticatedUserId: credential.user!.uid,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'weak-password') {
        _globalMethods.authErrorHandle(tr('weak_password'), context);
      } else if (error.code == 'email-already-in-use') {
        _globalMethods.authErrorHandle(tr('email_exists'), context);
      } else if (error.code == 'username-already-in-use') {
        _globalMethods.authErrorHandle(tr('username_exists'), context);
      } else if (error.code == 'invalid-email') {
        _globalMethods.authErrorHandle(tr('invalid_email'), context);
      } else if (error.code == 'operation-not-allowed') {
        _globalMethods.authErrorHandle(tr('operation_not_allowed'), context);
      } else if (error.code == 'network-request-failed') {
        _globalMethods.authErrorHandle(tr('check_connection'), context);
      } else {
        _globalMethods.authErrorHandle(
          error.message ?? tr('error_occured'),
          context,
        );
      }
    } catch (error) {
      if (mounted) _globalMethods.authErrorHandle(error.toString(), context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget obscureToggle() => IconButton(
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText ? PhosphorIcons.eye() : PhosphorIcons.eyeSlash(),
          ),
        );
    return AccountFormPage(
      title: tr('signup'),
      logo: true,
      onLogoDoubleTap: () => setState(() => _isUserVerified = true),
      message: tr('signup_to_sync'),
      children: [
        Text(
          tr('choose_profile'),
          style: AppType.sectionHeader.copyWith(color: palette.foreground),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: profileImages.profile().length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final profile = profileImages.profile()[index];
              final selected = profileValue == profile.index;
              return Semantics(
                button: true,
                selected: selected,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() {
                    profileValue = profile.index;
                    selectedProfile = profile.index;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 72,
                    padding: EdgeInsets.all(selected ? 3 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: palette.foreground, width: 3)
                          : null,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/profiles/${profile.index}.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('name'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return tr('name_empty');
                  } else if (value.length > 40 || value.length < 2) {
                    return tr('name_short_long');
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                onEditingComplete: () =>
                    FocusScope.of(context).requestFocus(_emailFocusNode),
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.user()),
                  labelText: tr('full_name'),
                ),
                onSaved: (value) {
                  _fullName = value!;
                },
                onChanged: (value) {
                  _fullName = value;
                },
              ),
              const AccountFieldGap(),
              TextFormField(
                key: const ValueKey('email'),
                focusNode: _emailFocusNode,
                validator: (value) {
                  if (value!.isEmpty || !value.contains('@')) {
                    return tr('invalid_email');
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                onEditingComplete: () =>
                    FocusScope.of(context).requestFocus(_usernameFocusNode),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.envelopeSimple()),
                  labelText: tr('email_address'),
                ),
                onSaved: (value) {
                  _emailAddress = value!;
                },
                onChanged: (value) {
                  _emailAddress = value;
                },
              ),
              const AccountFieldGap(),
              TextFormField(
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('^[a-zA-Z0-9_]*')),
                ],
                key: const ValueKey('username'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return tr('username_empty');
                  } else if (value.length < 5 || value.length > 30) {
                    return tr('username_short_long');
                  } else if (!value.contains(RegExp('^[a-zA-Z0-9_]*'))) {
                    return tr('invalid_username');
                  }
                  return null;
                },
                focusNode: _usernameFocusNode,
                textInputAction: TextInputAction.next,
                onEditingComplete: () =>
                    FocusScope.of(context).requestFocus(_passwordFocusNode),
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.newUsername],
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.at()),
                  labelText: tr('username'),
                ),
                onSaved: (value) {
                  _userName = value!;
                },
                onChanged: (value) {
                  _userName = value;
                },
              ),
              const AccountFieldGap(),
              TextFormField(
                key: const ValueKey('Password'),
                validator: (value) {
                  if (value!.isEmpty || value.length < 7) {
                    return tr('invalid_password');
                  } else if (value == '12345678' ||
                      value == 'qwertyuiop' ||
                      value == 'password') {
                    return tr('lame_password');
                  }
                  return null;
                },
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.newPassword],
                focusNode: _passwordFocusNode,
                obscureText: _obscureText,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => FocusScope.of(context)
                    .requestFocus(_passwordVerifyFocusNode),
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.lock()),
                  suffixIcon: obscureToggle(),
                  labelText: tr('enter_password'),
                ),
                onSaved: (value) {
                  _password = value!;
                },
                onChanged: (value) {
                  _password = value;
                },
              ),
              const AccountFieldGap(),
              TextFormField(
                key: const ValueKey('VerifyPassword'),
                validator: (value) {
                  if (value != _password) {
                    return tr('password_mismatch');
                  }
                  return null;
                },
                obscureText: _obscureText,
                keyboardType: TextInputType.visiblePassword,
                focusNode: _passwordVerifyFocusNode,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submitForm(),
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.lock()),
                  suffixIcon: obscureToggle(),
                  labelText: tr('repeat_password'),
                ),
              ),
            ],
          ),
        ),
        AccountSubmitButton(
          label: tr('sign_up'),
          busy: _isLoading,
          onPressed: submitForm,
        ),
      ],
    );
  }
}
