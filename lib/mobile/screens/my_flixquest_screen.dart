import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../catalog/continue_watching.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../models/offline_download.dart';
import '../../provider/bookmark_provider.dart';
import '../../provider/offline_download_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/about.dart';
import '../../screens/common/bookmark_screen.dart';
import '../../screens/common/downloads_screen.dart';
import '../../screens/common/server_status_screen.dart';
import '../../screens/common/settings.dart' as app_settings;
import '../../screens/common/sync_screen.dart';
import '../../screens/common/update_screen.dart';
import '../../screens/user/edit_profile.dart';
import '../../screens/wellness/wellness_screen.dart';
import '../../services/auth_navigation_service.dart';
import '../../services/flixquest_auth_service.dart';
import '../widgets/media_rows.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import '../widgets/section_header.dart';

/// The phone library and account tab. Local media is useful immediately and
/// remote profile data only enhances the header when it is available.
class MyFlixQuestScreen extends StatefulWidget {
  const MyFlixQuestScreen({super.key});

  @override
  State<MyFlixQuestScreen> createState() => _MyFlixQuestScreenState();
}

class _MyFlixQuestScreenState extends State<MyFlixQuestScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    try {
      _user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      _user = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadLocalLibrary());
    });
  }

  Future<void> _loadLocalLibrary() async {
    final downloads = context.read<OfflineDownloadProvider>();
    final bookmarks = context.read<BookmarkProvider>();
    final recent = context.read<RecentProvider>();
    if (downloads.downloads.isEmpty && !downloads.loading) {
      try {
        await downloads.refresh();
      } catch (_) {
        // The existing local snapshot, even an empty one, is still usable.
      }
    }
    await Future.wait<void>(<Future<void>>[
      _quietly(bookmarks.fetchBookmarks),
      _quietly(recent.fetchMovies),
      _quietly(recent.fetchEpisodes),
    ]);
  }

  Future<void> _quietly(Future<void> Function() load) async {
    try {
      await load();
    } catch (_) {
      // My FlixQuest is an offline-first surface. A stale local section is
      // preferable to an error replacing the whole page.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final recent = context.watch<RecentProvider>();
    final bookmarks = context.watch<BookmarkProvider>();
    final downloads = context.watch<OfflineDownloadProvider>().downloads;
    final continueWatching = continueWatchingItems(
      movies: recent.movies,
      episodes: recent.episodes,
      upNext: recent.upNext,
    );
    final saved = <MediaItem>[
      ...bookmarks.movies.map(MediaItem.fromMovie),
      ...bookmarks.tvShows.map(MediaItem.fromSeries),
    ];

    return ColoredBox(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            top: AppSpace.md,
            bottom: 112 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
              child: Text(
                tr('my_flixquest'),
                style: AppType.scaled(context, AppType.pageTitle).copyWith(
                  color: palette.foreground,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
              child: _ProfileHeader(
                user: _user,
                onProfile: () => _push(const ProfileEdit()),
                onSignIn: _leaveGuestSession,
              ),
            ),
            if (continueWatching.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpace.xxl),
              ContinueRow(
                title: tr('continue_watching'),
                items: continueWatching,
              ),
            ],
            if (saved.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpace.xxl),
              PosterRow(
                title: tr('my_list'),
                items: saved,
                onSeeAll: () => _push(const BookmarkScreen()),
              ),
            ],
            const SizedBox(height: AppSpace.xxl),
            SectionHeader(
              title: tr('downloads'),
              onSeeAll: () => _push(const DownloadsScreen()),
            ),
            if (downloads.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpace.gutter(context),
                  vertical: AppSpace.md,
                ),
                child: Text(
                  tr('no_downloads_yet'),
                  style: AppType.body.copyWith(color: palette.mutedText),
                ),
              )
            else
              for (final download in downloads.take(3))
                _DownloadSummaryRow(
                  download: download,
                  onTap: () => _push(const DownloadsScreen()),
                ),
            const SizedBox(height: AppSpace.xxl),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
              child: WellnessPreviewCard(
                onTap: () => _push(const WellnessScreen()),
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            ListRow(
              icon: PhosphorIcons.slidersHorizontal(),
              label: tr('settings'),
              onTap: () => _push(const app_settings.Settings()),
            ),
            ListRow(
              icon: PhosphorIcons.arrowsDownUp(),
              label: tr('sync'),
              onTap: () => _push(const SyncScreen()),
            ),
            ListRow(
              icon: PhosphorIcons.database(),
              label: tr('check_server'),
              onTap: () => _push(const ServerStatusScreen()),
            ),
            ListRow(
              icon: PhosphorIcons.arrowCircleUp(),
              label: tr('check_for_update'),
              onTap: () => _push(const UpdateScreen(isForced: false)),
            ),
            ListRow(
              icon: PhosphorIcons.shareNetwork(),
              label: tr('shared_the_app'),
              showsNext: false,
              onTap: _shareApp,
            ),
            ListRow(
              icon: PhosphorIcons.info(),
              label: tr('about'),
              onTap: () => _push(const AboutPage()),
            ),
            // A guest has nothing to sign out of; the header offers sign-in.
            if (_isSignedIn)
              ListRow(
                icon: PhosphorIcons.signOut(),
                label: tr('sign_out'),
                destructive: true,
                showsNext: false,
                onTap: _confirmSignOut,
              ),
          ],
        ),
      ),
    );
  }

  bool get _isSignedIn {
    final user = _user;
    return user != null && !user.isAnonymous;
  }

  Future<void> _shareApp() async {
    context.read<SettingsProvider>().analytics.trackShare(shareType: 'App');
    await Share.share(tr('share_text'));
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showConfirmDialog(
      context,
      icon: PhosphorIcons.signOut(),
      title: tr('sign_out'),
      message: tr('want_to_sign_out'),
      confirmLabel: tr('sign_out'),
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final analytics = context.read<SettingsProvider>().analytics;
    analytics.trackSignOut();
    analytics.resetUser();
    await _signOut();
  }

  /// Guests sign in by discarding the anonymous account, as the old profile
  /// page did.
  Future<void> _leaveGuestSession() async {
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {
      // A guest session can still be cleared locally when offline.
    }
    await _signOut();
  }

  Future<void> _signOut() async {
    await FlixQuestAuthService.signOutGoogle();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    await AuthNavigationService.returnToSignedOutRoot(context);
  }

  void _push(Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onProfile,
    required this.onSignIn,
  });

  final User? user;
  final VoidCallback onProfile;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    final guest = user == null || user.isAnonymous;
    final fallback = _ProfileSnapshot(
      name: guest ? tr('guest') : _fallbackName(user),
      photoUrl: guest ? '' : user.photoURL ?? '',
      profileId: 0,
    );
    if (guest) {
      return _ProfileHeaderContent(
        profile: fallback,
        status: tr('guest'),
        actionLabel: tr('login_signup'),
        actionIcon: PhosphorIcons.signIn(),
        onAction: onSignIn,
      );
    }
    return StreamBuilder<_ProfileSnapshot>(
      initialData: fallback,
      stream: _profileUpdates(user.uid, fallback),
      builder: (context, snapshot) => _ProfileHeaderContent(
        profile: snapshot.data ?? fallback,
        status: tr('signed_in'),
        actionLabel: tr('profile'),
        actionIcon: PhosphorIcons.user(),
        onAction: onProfile,
      ),
    );
  }

  static String _fallbackName(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user.email ?? '';
    final localPart = email.split('@').first.trim();
    return localPart.isEmpty ? tr('not_available') : localPart;
  }

  Stream<_ProfileSnapshot> _profileUpdates(
    String uid,
    _ProfileSnapshot fallback,
  ) async* {
    try {
      await for (final document in FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()) {
        final data = document.data();
        if (data == null) continue;
        yield _ProfileSnapshot(
          name: data['name']?.toString().trim().isNotEmpty == true
              ? data['name'].toString()
              : fallback.name,
          photoUrl: data['photoUrl']?.toString() ?? fallback.photoUrl,
          profileId: data['profileId'] ?? fallback.profileId,
        );
      }
    } catch (_) {
      // Keep the Firebase Auth fallback when profile metadata is unavailable.
    }
  }
}

class _ProfileHeaderContent extends StatelessWidget {
  const _ProfileHeaderContent({
    required this.profile,
    required this.status,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final _ProfileSnapshot profile;
  final String status;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The pill may take everything but the avatar and its gaps, so it
        // stays against the far end and gives way only when it must.
        final maxPill = (constraints.maxWidth -
                _ProfileAvatar.size -
                AppSpace.lg -
                AppSpace.md)
            .clamp(0.0, double.infinity);
        return Row(
          children: <Widget>[
            _ProfileAvatar(profile: profile),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sectionHeader.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxPill),
              child: PillButton(
                label: actionLabel,
                icon: actionIcon,
                onPressed: onAction,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  static const size = 64.0;

  final _ProfileSnapshot profile;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget asset() => Image.asset(
          'assets/images/profiles/${profile.profileId}.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/profiles/0.png',
            fit: BoxFit.cover,
          ),
        );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.hairline),
      ),
      child: ClipOval(
        child: profile.photoUrl.trim().isEmpty
            ? asset()
            : Image.network(
                profile.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => asset(),
              ),
      ),
    );
  }
}

class _ProfileSnapshot {
  const _ProfileSnapshot({
    required this.name,
    required this.photoUrl,
    required this.profileId,
  });

  final String name;
  final String photoUrl;
  final Object profileId;
}

class _DownloadSummaryRow extends StatelessWidget {
  const _DownloadSummaryRow({required this.download, required this.onTap});

  final OfflineDownload download;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final failed = download.state == OfflineDownloadState.failed;
    // Always determinate: a failed or queued item must not look busy.
    final progress = download.isComplete
        ? 1.0
        : (download.progress / 100).clamp(0.0, 1.0).toDouble();
    return ListRow(
      icon: PhosphorIcons.downloadSimple(),
      label: download.title,
      subtitle: tr('download_status_${download.state.name}'),
      onTap: onTap,
      trailing: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              download.isComplete ? '100%' : '${download.progress.round()}%',
              style: AppType.metadata.copyWith(
                color: failed
                    ? Theme.of(context).colorScheme.error
                    : palette.mutedText,
              ),
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              backgroundColor: palette.idleFill,
            ),
          ],
        ),
      ),
    );
  }
}
