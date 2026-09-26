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
import '../../ui_components/app_ui_components.dart';

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
    return Scaffold(
        appBar: AppBar(title: Text(tr('delete_account'))),
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
                              .error
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(PhosphorIcons.trash(),
                            size: 32,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          tr('delete_account'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          tr('delete_notice'),
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
                                  key: const ValueKey('deleteText'),
                                  validator: (value) {
                                    if (value != 'DELETE' &&
                                        value != 'delete') {
                                      return tr('must_type_delete');
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                      errorMaxLines: 3,
                                      filled: true,
                                      prefixIcon: Icon(PhosphorIcons.textT()),
                                      labelText: tr('type_delete')),
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 25),
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        style: ButtonStyle(
                                            backgroundColor:
                                                WidgetStatePropertyAll(
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .error),
                                            foregroundColor:
                                                WidgetStatePropertyAll(
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onError),
                                            minimumSize:
                                                const WidgetStatePropertyAll(
                                                    Size(200, 50)),
                                            shape: WidgetStateProperty.all(
                                              RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10.0),
                                              ),
                                            )),
                                        onPressed: () {
                                          _submitForm();
                                        },
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              tr('delete_account'),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 17),
                                            ),
                                            const SizedBox(
                                              width: 5,
                                            ),
                                            Icon(
                                              PhosphorIcons.trash(),
                                              size: 18,
                                            )
                                          ],
                                        )),
                              ),
                            ],
                          ),
                        ),
                      )
                    ]))));
  }
}
