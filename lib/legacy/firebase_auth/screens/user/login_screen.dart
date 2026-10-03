import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../constants/app_constants.dart';
import '../../../../functions/function.dart';
import 'forgot_password.dart';
import '../../../../provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../../services/globle_method.dart';
import '../../services/flixquest_auth_service.dart';
import '../../../../services/bookmark_sync_service.dart';
import '../../../../services/auth_navigation_service.dart';
import '../../../../mobile/widgets/account_form.dart';
import '../../../../widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FocusNode passwordFocusNode = FocusNode();
  bool obscureText = true;
  String emailAddress = '';
  String password = '';
  final formKey = GlobalKey<FormState>();
  final FlixQuestAuthService authService = FlixQuestAuthService();
  GlobalMethods globalMethods = GlobalMethods();
  bool isLoading = false;
  bool _googleLoading = false;

  // @override
  // void dispose() {
  //   passwordFocusNode.dispose();
  //   super.dispose();
  // }

  Future<void> submitForm() async {
    if (isLoading || _googleLoading) return;
    final isValid = formKey.currentState!.validate();
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
    setState(() => isLoading = true);
    formKey.currentState!.save();
    try {
      final credential =
          await authService.signIn(email: emailAddress, password: password);
      if (!mounted) return;
      BookmarkSyncService.instance.autoSyncIfSignedIn();
      Provider.of<SettingsProvider>(context, listen: false)
          .analytics
          .trackLogin('email');
      await AuthNavigationService.returnToAppRoot(
        context,
        authenticatedUserId: credential.user!.uid,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        globalMethods.authErrorHandle(tr('invalid_credential'), context);
      } else if (error.code == 'invalid-email') {
        globalMethods.authErrorHandle(tr('invalid_email'), context);
      } else if (error.code == 'user-disabled') {
        globalMethods.authErrorHandle(tr('banned_user'), context);
      } else if (error.code == 'user-not-found') {
        globalMethods.authErrorHandle(tr('user_not_found'), context);
      } else if (error.code == 'network-request-failed') {
        globalMethods.authErrorHandle(tr('check_connection'), context);
      } else {
        globalMethods.authErrorHandle(
          error.message ?? tr('error_occured'),
          context,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> signInWithGoogle() async {
    if (isLoading || _googleLoading) return;
    if (!mounted) return;
    setState(() => _googleLoading = true);
    try {
      final credential = await authService.signInWithGoogle();
      if (credential == null) return;
      if (!mounted) return;
      BookmarkSyncService.instance.autoSyncIfSignedIn();
      Provider.of<SettingsProvider>(context, listen: false)
          .analytics
          .trackLogin('google');
      await AuthNavigationService.returnToAppRoot(
        context,
        authenticatedUserId: credential.user!.uid,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'account-exists-with-different-credential') {
        globalMethods.authErrorHandle(tr('google_email_conflict'), context);
      } else if (error.code == 'invalid-credential') {
        globalMethods.authErrorHandle(tr('invalid_credential'), context);
      } else if (error.code == 'user-disabled') {
        globalMethods.authErrorHandle(tr('banned_user'), context);
      } else if (error.code == 'network-request-failed') {
        globalMethods.authErrorHandle(tr('check_connection'), context);
      } else {
        globalMethods.authErrorHandle(
          error.message ?? tr('error_occured'),
          context,
        );
      }
    } on PlatformException catch (error) {
      if (!mounted || _isGoogleSignInCancel(error)) return;
      globalMethods.authErrorHandle(_googlePlatformMessage(error), context);
    } catch (_) {
      if (mounted) {
        globalMethods.authErrorHandle(tr('google_signin_failed'), context);
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return AccountFormPage(
      title: tr('login'),
      logo: true,
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('email'),
                validator: (value) {
                  if (value!.isEmpty || !value.contains('@')) {
                    return tr('invalid_email');
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                onEditingComplete: () =>
                    FocusScope.of(context).requestFocus(passwordFocusNode),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  prefixIcon: Icon(PhosphorIcons.envelopeSimple()),
                  labelText: tr('email_address'),
                ),
                onSaved: (value) {
                  emailAddress = value!;
                },
              ),
              const AccountFieldGap(),
              TextFormField(
                key: const ValueKey('Password'),
                validator: (value) {
                  if (value!.isEmpty || value.length < 7) {
                    return tr('weak_password');
                  }
                  return null;
                },
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.password],
                focusNode: passwordFocusNode,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submitForm(),
                decoration: InputDecoration(
                  prefixIcon: Icon(PhosphorIcons.lock()),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => obscureText = !obscureText),
                    icon: Icon(obscureText
                        ? PhosphorIcons.eye()
                        : PhosphorIcons.eyeSlash()),
                  ),
                  labelText: tr('password'),
                ),
                onSaved: (value) {
                  password = value!;
                },
                obscureText: obscureText,
              ),
            ],
          ),
        ),
        AccountSubmitButton(
          label: tr('login'),
          busy: isLoading,
          onPressed: _googleLoading ? null : submitForm,
        ),
        AccountLink(
          label: tr('forgot_password'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
          ),
        ),
        const AccountOrDivider(),
        GoogleSignInButton(
          loading: _googleLoading,
          enabled: !isLoading,
          onPressed: signInWithGoogle,
        ),
      ],
    );
  }
}
