import 'package:provider/provider.dart';
import '/provider/settings_provider.dart';
import '../../legacy/firebase_auth/screens/user/password_change.dart' as legacy;
import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/globle_method.dart';

import 'package:flutter/material.dart';
import '../../mobile/widgets/account_form.dart';

class LaravelPasswordChangeScreen extends StatefulWidget {
  const LaravelPasswordChangeScreen({super.key});

  @override
  PasswordChangeScreenState createState() => PasswordChangeScreenState();
}

class PasswordChangeScreenState extends State<LaravelPasswordChangeScreen> {
  String currentPassword = '';
  String newPassword = '';
  bool _obscureText = true;

  final _formKey = GlobalKey<FormState>();
  final FlixQuestAuthService _auth = FlixQuestAuthService();
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

  void getUserData() {
    _emailAddress = AuthRuntime.session.user?.email;
  }

  void _submitForm() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    final analytics = context.read<SettingsProvider>().analytics;
    try {
      await _auth.changePassword(ChangePasswordRequest(currentPassword: currentPassword, password: newPassword));
      analytics.trackPasswordChanged();
      if (!mounted) return;
      GlobalMethods.showCustomScaffoldMessage(SnackBar(content: Text(tr('password_changed'))), context);
      Navigator.of(context).pop();
    } on AuthActionException catch (error) {
      if (mounted) _globalMethods.authErrorHandle(error.message, context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                key: const ValueKey('currentPassword'),
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (value) => AuthRuntime.session.user?.provider != 'google' &&
                    (value == null || value.isEmpty) ? 'Enter your current password.' : null,
                onSaved: (value) => currentPassword = value ?? '',
              ),
              const AccountFieldGap(),
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

class PasswordChangeScreen extends StatelessWidget {
  const PasswordChangeScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthRuntime.enabled
      ? const LaravelPasswordChangeScreen() : const legacy.PasswordChangeScreen();
}
