import '../../legacy/firebase_auth/screens/user/email_change.dart' as legacy;
import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';
import 'package:flixquest/data/models/auth_requests.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/globle_method.dart';

import 'package:flutter/material.dart';
import '../../mobile/widgets/account_form.dart';

class LaravelEmailChangeScreen extends StatefulWidget {
  const LaravelEmailChangeScreen({super.key});

  @override
  EmailChangeScreenState createState() => EmailChangeScreenState();
}

class EmailChangeScreenState extends State<LaravelEmailChangeScreen> {
  String currentEmail = '';
  String currentPassword = '';
  String newEmail = '';

  final _formKey = GlobalKey<FormState>();
  final FlixQuestAuthService _auth = FlixQuestAuthService();
  final GlobalMethods _globalMethods = GlobalMethods();
  bool _isLoading = false;
  final FocusNode _newEmailFocusNode = FocusNode();
  final FocusNode _emailVerifyFocusNode = FocusNode();


  String? uid;
  String? userId;
  String? userEmail;
  bool? isVerified;
  String? name;
  String? email;
  String? joinedAt;
  int? profileId;
  bool? userAnonymous;
  String? username;
  String? month;
  int? year;
  int? selectedProfile;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  void getUserData() {
    currentEmail = AuthRuntime.session.user?.email ?? '';
  }

  void _submitForm() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      await _auth.changeEmail(ChangeEmailRequest(currentPassword: currentPassword, email: newEmail));
      if (!mounted) return;
      GlobalMethods.showCustomScaffoldMessage(SnackBar(content: Text(tr('email_successful'))), context);
      Navigator.of(context).pop();
    } on AuthActionException catch (error) {
      if (mounted) _globalMethods.authErrorHandle(error.message, context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountFormPage(
      title: tr('change_email'),
      icon: PhosphorIcons.at(),
      heading: tr('change_email'),
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
                key: const ValueKey('email'),
                focusNode: _newEmailFocusNode,
                validator: (value) {
                  if (value!.isEmpty || !value.contains('@')) {
                    return tr('invalid_email');
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                onEditingComplete: () =>
                    FocusScope.of(context).requestFocus(_emailVerifyFocusNode),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.envelopeSimple()),
                  labelText: tr('new_email_address'),
                ),
                onSaved: (value) {
                  newEmail = value!;
                },
                onChanged: (value) {
                  newEmail = value;
                },
              ),
              const AccountFieldGap(),
              TextFormField(
                key: const ValueKey('verifyEmail'),
                focusNode: _emailVerifyFocusNode,
                validator: (value) {
                  if (value != newEmail) {
                    return tr('email_mismatch');
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  prefixIcon: Icon(PhosphorIcons.envelopeSimple()),
                  labelText: tr('repeat_new_email'),
                ),
              ),
            ],
          ),
        ),
        AccountSubmitButton(
          label: tr('change_email'),
          // Working until the account is known, then while it saves.
          busy: _isLoading || currentEmail.isEmpty,
          onPressed: _submitForm,
        ),
      ],
    );
  }
}

class EmailChangeScreen extends StatelessWidget {
  const EmailChangeScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthRuntime.enabled
      ? const LaravelEmailChangeScreen() : const legacy.EmailChangeScreen();
}
