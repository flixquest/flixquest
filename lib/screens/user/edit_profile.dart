import 'package:flixquest/data/models/app_user.dart';
import '../../legacy/firebase_auth/screens/user/edit_profile.dart' as legacy;
import 'package:flixquest/presentation/session/auth_runtime.dart';
import 'package:flixquest/services/flixquest_auth_service.dart';
import 'package:flixquest/data/models/auth_requests.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '/screens/user/delete_account.dart';
import '/screens/user/email_change.dart';
import '/screens/user/password_change.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/provider/settings_provider.dart';
import '../../models/profile_image_list.dart';
import '../../services/globle_method.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../mobile/widgets/account_form.dart';
import '../../mobile/widgets/page_kit.dart';

class LaravelProfileEdit extends StatefulWidget {
  const LaravelProfileEdit({super.key});

  @override
  State<LaravelProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<LaravelProfileEdit> {
  final FlixQuestAuthService _auth = FlixQuestAuthService();
  String? uid;
  String? userId;
  String? userEmail;
  bool? isVerified;
  String? name;
  String? email;
  String? joinedAt;
  DateTime? createdAt;
  int? profileId;
  bool? userAnonymous;
  String? username;
  String? photoUrl;
  bool _avatarChanged = false;
  String? month;
  int? year;
  int? selectedProfile;
  String _fullName = '';
  String _userName = '';
  final ProfileImages profileImages = ProfileImages();
  late final List<Profile> _profileList = profileImages.profile();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final GlobalMethods _globalMethods = GlobalMethods();
  AppUser? userProfile;
  final ScrollController _profileScrollController = ScrollController();

  void getData() {
    final user = AuthRuntime.session.user;
    if (user == null) {
      setState(() => userAnonymous = true);
      return;
    }
    setState(() {
      userAnonymous = false;
      uid = user.id.toString(); userId = uid;
      name = user.name; email = user.email; userEmail = user.email;
      joinedAt = user.joinedAt.toIso8601String(); createdAt = user.createdAt;
      month = DateFormat('MMMM').format(user.joinedAt); year = user.joinedAt.year;
      isVerified = user.isVerified; profileId = user.profileId;
      username = user.username; photoUrl = user.photoUrl;
      userProfile = user;
    });
    if (profileId != null && profileId! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_profileScrollController.hasClients) {
          final double offset = (profileId! * (72.0 + 14.0)).clamp(
            0.0, _profileScrollController.position.maxScrollExtent);
          _profileScrollController.jumpTo(offset);
        }
      });
    }
  }

  @override
  void dispose() {
    _profileScrollController.dispose();
    super.dispose();
  }

  void updateProfile() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      if (_userName.trim().toLowerCase() != username &&
          !await _auth.usernameAvailable(_userName)) {
        throw const AuthActionException(code: 'username-already-in-use', message: 'That username is already in use.');
      }
      await _auth.updateProfile(UpdateProfileRequest(name: _fullName.trim(),
          username: _userName.trim().toLowerCase(), profileId: profileId,
          photoUrl: _avatarChanged ? '' : photoUrl));
      if (!mounted) return;
      context.read<SettingsProvider>().analytics.trackProfileUpdated();
      Navigator.pop(context);
    } on AuthActionException catch (error) {
      if (mounted) _globalMethods.authErrorHandle(error.message, context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final loading = userAnonymous == null;
    return AccountFormPage(
      title: tr('edit_profile'),
      children: [
        Text(
          tr('profile_picture'),
          style: AppType.sectionHeader.copyWith(color: palette.foreground),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          tr('choose_profile'),
          style: AppType.body.copyWith(color: palette.mutedText),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            controller: _profileScrollController,
            padding: const EdgeInsets.symmetric(vertical: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _profileList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final profile = _profileList[index];
              final selected = profileId == profile.index;
              return Semantics(
                selected: selected,
                button: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() {
                    profileId = profile.index;
                    selectedProfile = profile.index;
                    _avatarChanged = true;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 72,
                    height: 72,
                    padding: EdgeInsets.all(selected ? 3 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: palette.foreground, width: 3)
                          : null,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/profiles/${profile.index}.png',
                        width: 66,
                        height: 66,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.md),
        // The fields take the account's details, so they wait for them.
        SkeletonSwitcher(
          loading: loading,
          skeleton: const SkeletonPulse(
            child: Column(
              children: [
                SkeletonBlock(height: 56),
                AccountFieldGap(),
                SkeletonBlock(height: 56),
              ],
            ),
          ),
          child: loading
              ? const SizedBox.shrink()
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: name,
                        key: const ValueKey('name'),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return tr('name_empty');
                          } else if (value.length > 40 || value.length < 2) {
                            return tr('name_short_long');
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.name,
                        decoration: InputDecoration(
                          errorMaxLines: 3,
                          prefixIcon: Icon(PhosphorIcons.user()),
                          labelText: tr('full_name'),
                        ),
                        onSaved: (value) {
                          _fullName = value!;
                        },
                        onChanged: (value) {
                          _fullName = value;
                        },
                      ),
                      const AccountFieldGap(),
                      TextFormField(
                        initialValue: username,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp('^[a-zA-Z0-9_]*')),
                        ],
                        key: const ValueKey('username'),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return tr('username_empty');
                          } else if (value.length < 5 || value.length > 30) {
                            return tr('username_short_long');
                          } else if (!value
                              .contains(RegExp('^[a-zA-Z0-9_]*'))) {
                            return tr('invalid_username');
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          errorMaxLines: 3,
                          prefixIcon: Icon(PhosphorIcons.at()),
                          labelText: tr('username'),
                        ),
                        onSaved: (value) {
                          _userName = value!;
                        },
                        onChanged: (value) {
                          _userName = value;
                        },
                      ),
                    ],
                  ),
                ),
        ),
        AccountSubmitButton(
          label: tr('confirm'),
          busy: _isLoading || loading,
          onPressed: updateProfile,
        ),
        const SizedBox(height: AppSpace.xxl),
        Divider(color: palette.hairline, height: 1),
        ListRow(
          flush: true,
          icon: PhosphorIcons.lockKey(),
          label: tr('change_password'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PasswordChangeScreen()),
          ),
        ),
        ListRow(
          flush: true,
          icon: PhosphorIcons.at(),
          label: tr('change_email'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmailChangeScreen()),
          ),
        ),
        ListRow(
          flush: true,
          icon: PhosphorIcons.trash(),
          label: tr('delete_account'),
          destructive: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
          ),
        ),
      ],
    );
  }
}

class ProfileEdit extends StatelessWidget {
  const ProfileEdit({super.key});
  @override
  Widget build(BuildContext context) => AuthRuntime.enabled
      ? const LaravelProfileEdit() : const legacy.ProfileEdit();
}
