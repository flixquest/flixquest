import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../constants/app_constants.dart';
import '../../services/globle_method.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui_components/app_ui_components.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(tr('change_email'))),
      body: userDoc == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : AppResponsiveContent(
              maxWidth: 560,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
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
                      child: Icon(PhosphorIcons.at(),
                          size: 32,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        tr('change_email'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        tr('process_stuck'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: TextFormField(
                                key: const ValueKey('email'),
                                focusNode: _newEmailFocusNode,
                                validator: (value) {
                                  if (value!.isEmpty || !value.contains('@')) {
                                    return tr('invalid_email');
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () => FocusScope.of(context)
                                    .requestFocus(_emailVerifyFocusNode),
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  errorMaxLines: 3,
                                  filled: true,
                                  prefixIcon:
                                      Icon(PhosphorIcons.envelopeSimple()),
                                  labelText: tr('new_email_address'),
                                ),
                                onSaved: (value) {
                                  newEmail = value!;
                                },
                                onChanged: (value) {
                                  newEmail = value;
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: TextFormField(
                                key: const ValueKey('verifyEmail'),
                                validator: (value) {
                                  if (value != newEmail) {
                                    return tr('email_mismatch');
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  errorMaxLines: 3,
                                  filled: true,
                                  prefixIcon:
                                      Icon(PhosphorIcons.envelopeSimple()),
                                  labelText: tr('repeat_new_email'),
                                ),
                              ),
                            ),
                          ],
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
                                  minimumSize: const WidgetStatePropertyAll(
                                      Size(200, 50)),
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                  )),
                              onPressed: () {
                                _submitForm();
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tr('change_email'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 17),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  Icon(
                                    PhosphorIcons.arrowsClockwise(),
                                    size: 18,
                                  )
                                ],
                              )),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
