import '../../legacy/firebase_auth/screens/user/forgot_password.dart' as legacy;
import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/globle_method.dart';

import 'package:flutter/material.dart';
import '../../mobile/widgets/account_form.dart';

class LaravelForgotPasswordScreen extends StatefulWidget {
  const LaravelForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<LaravelForgotPasswordScreen> {
  String _emailAddress = '';
  final _formKey = GlobalKey<FormState>();
  final FlixQuestAuthService _auth = FlixQuestAuthService();
  final GlobalMethods _globalMethods = GlobalMethods();
  bool _isLoading = false;
  void _submitForm() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();
    if (isValid) {
      setState(() {
        _isLoading = true;
      });
      _formKey.currentState!.save();
      try {
        await _auth
            .forgotPassword(_emailAddress)
            .then((value) {
          if (mounted) {
            _globalMethods.checkMessage(tr('reset_sent'), context);
          }
        });
      } on AuthActionException catch (e) {
        if (mounted) {
          if (e.code == 'user-not-found') {
            _globalMethods.authErrorHandle(tr('no_account'), context);
          } else {
            _globalMethods.authErrorHandle(e.toString(), context);
          }
        }
        // print('error occured ${error.message}');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountFormPage(
      title: tr('reset_password'),
      icon: PhosphorIcons.envelopeOpen(),
      heading: tr('forgot_password'),
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            key: const ValueKey('email'),
            validator: (value) {
              if (value!.isEmpty || !value.contains('@')) {
                return tr('invalid_email');
              }
              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitForm(),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              prefixIcon: Icon(PhosphorIcons.envelopeSimple()),
              labelText: tr('email_address'),
            ),
            onSaved: (value) {
              _emailAddress = value!;
            },
          ),
        ),
        AccountSubmitButton(
          label: tr('reset_password'),
          icon: PhosphorIcons.paperPlaneTilt(),
          busy: _isLoading,
          onPressed: _submitForm,
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthRuntime.enabled
      ? const LaravelForgotPasswordScreen() : const legacy.ForgotPasswordScreen();
}
