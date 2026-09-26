import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/globle_method.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui_components/app_ui_components.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String _emailAddress = '';
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
            .sendPasswordResetEmail(email: _emailAddress.trim().toLowerCase())
            .then((value) {
          if (mounted) {
            _globalMethods.checkMessage(tr('reset_sent'), context);
          }
        });
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          if (e.code == 'user-not-found') {
            _globalMethods.authErrorHandle(tr('no_account'), context);
          } else {
            _globalMethods.authErrorHandle(e.toString(), context);
          }
        }
        // print('error occured ${error.message}');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('reset_password'))),
      body: AppResponsiveContent(
        maxWidth: 560,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(PhosphorIcons.envelopeOpen(),
                  size: 32, color: Theme.of(context).colorScheme.primary),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                tr('forgot_password'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Form(
                key: _formKey,
                child: TextFormField(
                  key: const ValueKey('email'),
                  validator: (value) {
                    if (value!.isEmpty || !value.contains('@')) {
                      return tr('invalid_email');
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    prefixIcon: Icon(PhosphorIcons.envelopeSimple()),
                    labelText: tr('email_address'),
                  ),
                  onSaved: (value) {
                    _emailAddress = value!;
                  },
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ButtonStyle(
                          minimumSize:
                              const WidgetStatePropertyAll(Size(200, 50)),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          )),
                      onPressed: _submitForm,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tr('reset_password'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 17),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Icon(PhosphorIcons.arrowsClockwise(),
                            size: 18,
                          )
                        ],
                      )),
            ),
          ],
        ),
      ),
    );
  }
}
