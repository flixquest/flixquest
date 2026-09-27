import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../constants/app_constants.dart';
import '../../services/globle_method.dart';
import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../../services/in_app_messaging_service.dart';
import '../../services/recently_watched_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/provider/settings_provider.dart';
import '../../provider/wellness_provider.dart';
import '../../mobile/widgets/account_form.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  DeleteAccountScreenState createState() => DeleteAccountScreenState();
}

class DeleteAccountScreenState extends State<DeleteAccountScreen> {
  String confirmationText = '';
  User? user;
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalMethods _globalMethods = GlobalMethods();
  bool _isLoading = false;
  DocumentSnapshot? userDoc;
  String? uid;
  String? username;
  final FocusNode deleteFN = FocusNode();

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
      username = userDoc!.get('username');
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

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .delete()
            .then((value) async {
          await FirebaseFirestore.instance
              .collection('bookmarks')
              .doc(uid)
              .delete()
              .then((value) async {
            await WellnessProvider.instance.deleteAccountData(uid!);
            await RecentlyWatchedSyncService.instance.deleteAccountData(uid!);
            await FirebaseFirestore.instance
                .collection('bookmarks-v2.0')
                .doc(uid)
                .delete()
                .then((value) async {
              await FirebaseFirestore.instance
                  .collection('usernames')
                  .doc(username)
                  .delete()
                  .then((value) async {
                await user!.delete().then((value) async {
                  await FlixQuestAuthService.signOutGoogle();
                  if (!context.mounted) {
                    return;
                  }
                  if (mounted) {
                    Provider.of<SettingsProvider>(context, listen: false)
                        .analytics
                        .trackAccountDeleted();
                    Provider.of<SettingsProvider>(context, listen: false)
                        .analytics
                        .resetUser();
                    await AuthNavigationService.returnToSignedOutRoot(context);
                    final rootContext =
                        InAppMessagingService.navigatorKey.currentContext;
                    if (rootContext != null && rootContext.mounted) {
                      GlobalMethods.showCustomScaffoldMessage(
                        SnackBar(
                          content: Text(
                            tr('account_deleted_successfully'),
                            maxLines: 3,
                            style: kTextSmallBodyStyle,
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                        rootContext,
                      );
                    }
                  }
                });
              });
            });
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
      title: tr('delete_account'),
      icon: PhosphorIcons.trash(),
      heading: tr('delete_account'),
      message: tr('delete_notice'),
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            key: const ValueKey('deleteText'),
            validator: (value) {
              if (value != 'DELETE' && value != 'delete') {
                return tr('must_type_delete');
              }
              return null;
            },
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              errorMaxLines: 3,
              prefixIcon: Icon(PhosphorIcons.textT()),
              labelText: tr('type_delete'),
            ),
          ),
        ),
        AccountSubmitButton(
          label: tr('delete_account'),
          icon: PhosphorIcons.trash(),
          destructive: true,
          // Working until the account is known, then while it's removed.
          busy: _isLoading || userDoc == null,
          onPressed: _submitForm,
        ),
      ],
    );
  }
}
