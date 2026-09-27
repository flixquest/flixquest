import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../provider/bookmark_provider.dart';
import '../../provider/app_dependency_provider.dart';
import '../../services/bookmark_sync_service.dart';
import '../../services/globle_method.dart';
import '../movie/bookmark_movies_tab.dart';
import '../tv/bookmark_tv_tab.dart';
import '/screens/common/sync_screen.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  int _selectedKind = 0;

  @override
  void initState() {
    super.initState();
    getData();
    _triggerAutoSync();
  }

  void _triggerAutoSync() async {
    if (BookmarkSyncService.instance.canSync) {
      await BookmarkSyncService.instance.autoSyncIfSignedIn();
      if (mounted) {
        context.read<BookmarkProvider>().fetchBookmarks();
      }
    }
  }

  void getData() async {
    user = _auth.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bookmarkProvider = Provider.of<BookmarkProvider>(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: widget.embedded
          ? null
          : PageAppBar(
              title: tr('bookmarks'),
              actions: <Widget>[
                IconButton(
                  tooltip: tr('sync'),
                  color: palette.mutedText,
                  onPressed: _syncBookmarks,
                  icon: Icon(PhosphorIcons.arrowsClockwise()),
                ),
              ],
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.embedded)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter(context),
                  AppSpace.lg,
                  AppSpace.gutter(context),
                  AppSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('bookmarks'),
                        style: AppType.scaled(context, AppType.pageTitle)
                            .copyWith(color: palette.foreground),
                      ),
                    ),
                    PillButton(
                      label: tr('sync'),
                      icon: PhosphorIcons.arrowsClockwise(),
                      onPressed: _syncBookmarks,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context)),
              child: SegmentSwitch<int>(
                selected: _selectedKind,
                onChanged: (value) => setState(() => _selectedKind = value),
                segments: <Segment<int>>[
                  Segment<int>(0, tr('movies'), icon: PhosphorIcons.filmStrip()),
                  Segment<int>(1, tr('tv_series'),
                      icon: PhosphorIcons.television()),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            RemoteHostedAdsBanner(
              placement: 'bookmarks',
              loadAds: () => ScraperApi(
                context.read<AppDependencyProvider>().flixquestAPIURL,
              ).getAds(),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedKind,
                children: <Widget>[
                  MovieBookmark(movieList: bookmarkProvider.movies),
                  TVBookmark(tvList: bookmarkProvider.tvShows),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _syncBookmarks() {
    if (user == null || user!.isAnonymous) {
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(
          content: Text(
            tr('bookmark_feature_notice'),
            style: kTextVerySmallBodyStyle,
            maxLines: 6,
          ),
        ),
        context,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyncScreen()),
    ).then((_) {
      if (!mounted) return;
      context.read<BookmarkProvider>().fetchBookmarks();
    });
  }
}
