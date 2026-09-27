import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../constants/app_constants.dart';
import '../../services/globle_method.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/provider/settings_provider.dart';
import '../../mobile/widgets/account_form.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  PasswordChangeScreenState createState() => PasswordChangeScreenState();
}

class PasswordChangeScreenState extends State<PasswordChangeScreen> {
  String currentPassword = '';
  String newPassword = '';
  bool _obscureText = true;
  User? user;
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalMethods _globalMethods = GlobalMethods();
  bool _isLoading = false;
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _passwordVerifyFocusNode = FocusNode();
  String? _emailAddress;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  void getUserData() async {
    User? user = _auth.currentUser;
    setState(() {
      _emailAddress = user!.email;
    });
  }

  void _submitForm() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();
    if (isValid) {
      setState(() {
        _isLoading = true;
      });
      _formKey.currentState!.save();
      try {
        user = _auth.currentUser;

        await user!.updatePassword(newPassword).then((value) {
          if (!mounted) return;
          Provider.of<SettingsProvider>(context, listen: false)
              .analytics
              .trackPasswordChanged();
          GlobalMethods.showCustomScaffoldMessage(
              SnackBar(
                content: Text(
                  tr('password_changed'),
                  maxLines: 3,
                  style: kTextSmallBodyStyle,
                ),
                duration: const Duration(seconds: 4),
              ),
              context.mounted ? context : null);
        });
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          if (e.code == 'user-mismatch') {
            _globalMethods.authErrorHandle(tr('user_mismatch'), context);
          } else if (e.code == 'user-not-found') {
            _globalMethods.authErrorHandle(tr('user_not_found'), context);
          } else if (e.code == 'invalid-credential') {
            _globalMethods.authErrorHandle(tr('invalid_credential'), context);
          } else if (e.code == 'invalid-email') {
            _globalMethods.authErrorHandle(tr('invalid_email'), context);
          } else if (e.code == 'wrong-password:') {
            _globalMethods.authErrorHandle(tr('wrong_password'), context);
          } else if (e.code == 'weak-password') {
            _globalMethods.authErrorHandle(tr('weak_password'), context);
          } else if (e.code == 'requires-recent-login') {
            _globalMethods.authErrorHandle(
                tr('requires_recent_login'), context);
          }
        }
        // print('error occured ${error.message}');
      } finally {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget obscureToggle() => IconButton(
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText ? PhosphorIcons.eye() : PhosphorIcons.eyeSlash(),
          ),
        );
    return AccountFormPage(
      title: tr('change_password'),
      icon: PhosphorIcons.lockKey(),
      heading: tr('change_password'),
      message: tr('process_stuck'),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('newPassword'),
                validator: (value) {
                  if (value!.isEmpty || value.length < 7) {
                    return tr('weak_password');
                  }
                  if (value == '123456' ||
                      value == '12345678' ||
                      value == 'password') {
                    return tr('lame_password');
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                focusNode: _newPasswordFocusNode,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.newPassword],
                obscureText: _obscureText,
                onEditingComplete: () => FocusScope.of(context)
                    .requestFocus(_passwordVerifyFocusNode),
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.lock()),
                  suffixIcon: obscureToggle(),
                  labelText: tr('enter_new_pass'),
                ),
                onChanged: (value) {
                  setState(() {
                    newPassword = value;
                  });
                },
                onSaved: (value) {
                  newPassword = value!;
                },
              ),
              const AccountFieldGap(),
              TextFormField(
                key: const ValueKey('verifyPassword'),
                validator: (value) {
                  if (value != newPassword) {
                    return tr('password_mismatch');
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                focusNode: _passwordVerifyFocusNode,
                keyboardType: TextInputType.visiblePassword,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.lock()),
                  suffixIcon: obscureToggle(),
                  labelText: tr('repeat_new_password'),
                ),
              ),
            ],
          ),
        ),
        AccountSubmitButton(
          label: tr('change_password'),
          // Working until the account is known, then while it saves.
          busy: _isLoading || _emailAddress == null,
          onPressed: _submitForm,
        ),
      ],
    );
  }
}
