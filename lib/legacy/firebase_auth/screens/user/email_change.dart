import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../constants/app_constants.dart';
import '../../../../services/globle_method.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../mobile/widgets/account_form.dart';

class EmailChangeScreen extends StatefulWidget {
  const EmailChangeScreen({super.key});

  @override
  EmailChangeScreenState createState() => EmailChangeScreenState();
}

class EmailChangeScreenState extends State<EmailChangeScreen> {
  String currentEmail = '';
  String newEmail = '';
  User? user;
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalMethods _globalMethods = GlobalMethods();
  bool _isLoading = false;
  final FocusNode _newEmailFocusNode = FocusNode();
  final FocusNode _emailVerifyFocusNode = FocusNode();
  Timestamp? createdAt;
  DocumentSnapshot? userDoc;
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

  void getUserData() async {
    User? user = _auth.currentUser;
    uid = user!.uid;
    userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    setState(() {
      name = userDoc!.get('name');
      email = userDoc!.get('email');
      joinedAt = userDoc!.get('joinedAt');
      month = DateFormat('MMMM')
          .format(DateTime(0, DateTime.parse(joinedAt!).month));
      year = DateTime.parse(joinedAt!).year;
      isVerified = userDoc!.get('verified');
      profileId = userDoc!.get('profileId');
      username = userDoc!.get('username');
      createdAt = userDoc!.get('createdAt');
      userEmail = userDoc!.get('email');
      userId = userDoc!.get('id');
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

        await user!.verifyBeforeUpdateEmail(newEmail).then((value) async {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'createdAt': createdAt,
            'email': newEmail,
            'id': userId,
            'joinedAt': joinedAt,
            'name': name,
            'profileId': profileId,
            'username': username!.trim().toLowerCase(),
            'verified': isVerified
          }).then((value) {
            if (!context.mounted) {
              return;
            }
            GlobalMethods.showCustomScaffoldMessage(
                SnackBar(
                  content: Text(
                    tr('email_successful'),
                    maxLines: 3,
                    style: kTextSmallBodyStyle,
                  ),
                  duration: const Duration(seconds: 4),
                ),
                context.mounted ? context : null);
          });
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
          busy: _isLoading || userDoc == null,
          onPressed: _submitForm,
        ),
      ],
    );
  }
}
