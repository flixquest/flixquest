import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../controllers/bookmark_database_controller.dart';
import '../../models/movie.dart';
import '../../models/tv.dart';
import '../../provider/settings_provider.dart';
import '../../services/bookmark_sync_service.dart';
import '../../services/globle_method.dart';
import '../../services/recently_watched_sync_service.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../mobile/widgets/details_parts.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import '../../mobile/widgets/poster_card.dart';
import '../movie/movie_detail.dart';
import '../tv/tv_detail.dart';
import '../user/login_screen.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MovieDatabaseController _movieDb = MovieDatabaseController();
  final TVDatabaseController _tvDb = TVDatabaseController();

  static const _contentWidth = 760.0;

  late final TabController _tabController;

  List<Movie> _cloudMovies = [];
  List<TV> _cloudTvShows = [];
  int _localMovieCount = 0;
  int _localTvCount = 0;

  bool _isLoading = true;
  bool _isActionRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();

    BookmarkSyncService.instance.statusNotifier
        .addListener(_onSyncStatusChanged);
  }

  @override
  void dispose() {
    BookmarkSyncService.instance.statusNotifier
        .removeListener(_onSyncStatusChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (!mounted) return;
    final status = BookmarkSyncService.instance.statusNotifier.value;
    if (status == SyncStatus.success) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _cloudMovies = [];
          _cloudTvShows = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = _firestore.collection('bookmarks-v2.0').doc(user.uid);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        await docRef.set({
          'movies': <Map<String, dynamic>>[],
          'tvShows': <Map<String, dynamic>>[],
        });
      }

      final docData = docSnapshot.data() ?? {};
      final rawMovies = List.from(docData['movies'] ?? []);
      final rawTvs = List.from(docData['tvShows'] ?? []);

      final loadedMovies = <Movie>[];
      for (final item in rawMovies) {
        if (item is Map<String, dynamic>) {
          loadedMovies.add(Movie.fromJson(item));
        }
      }

      final loadedTvs = <TV>[];
      for (final item in rawTvs) {
        if (item is Map<String, dynamic>) {
          loadedTvs.add(TV.fromJson(item));
        }
      }

      final localMovieCount = await _movieDb.getCount();
      final localTvCount = await _tvDb.getCount();

      if (mounted) {
        setState(() {
          _cloudMovies = loadedMovies;
          _cloudTvShows = loadedTvs;
          _localMovieCount = localMovieCount;
          _localTvCount = localTvCount;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runFullSync() async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);
    final stopwatch = Stopwatch()..start();

    final results = await Future.wait(<Future<bool>>[
      BookmarkSyncService.instance.syncNow(force: true),
      RecentlyWatchedSyncService.instance.syncNow(force: true),
    ]);
    // This screen reports on bookmarks, so only their outcome drives the
    // message; a failed recents merge is retried by the next sync.
    final success = results.first;
    if (mounted) {
      context.read<SettingsProvider>().analytics.trackCloudSync(
            action: 'full_sync',
            itemCount: _localMovieCount +
                _localTvCount +
                _cloudMovies.length +
                _cloudTvShows.length,
            outcome: success ? 'success' : 'error',
            durationMs: stopwatch.elapsedMilliseconds,
          );
    }

    if (mounted) {
      setState(() => _isActionRunning = false);
      _fetchData();
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(
          content: Text(
            success ? tr('finished_sync_online') : tr('error_occured'),
            style: const TextStyle(fontFamily: 'FigtreeSB'),
          ),
          duration: const Duration(seconds: 2),
        ),
        context,
      );
    }
  }

  Future<void> _pushLocalToCloud() async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);
    final stopwatch = Stopwatch()..start();

    final success = await BookmarkSyncService.instance.pushLocalToCloud();
    if (mounted) {
      context.read<SettingsProvider>().analytics.trackCloudSync(
            action: 'push_to_cloud',
            itemCount: _localMovieCount + _localTvCount,
            outcome: success ? 'success' : 'error',
            durationMs: stopwatch.elapsedMilliseconds,
          );
    }

    if (mounted) {
      setState(() => _isActionRunning = false);
      _fetchData();
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(
          content: Text(
            success ? tr('finished_sync_online') : tr('error_occured'),
            style: const TextStyle(fontFamily: 'FigtreeSB'),
          ),
          duration: const Duration(seconds: 2),
        ),
        context,
      );
    }
  }

  Future<void> _pullCloudToLocal() async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);
    final stopwatch = Stopwatch()..start();

    final success = await BookmarkSyncService.instance.pullCloudToLocal();
    if (mounted) {
      context.read<SettingsProvider>().analytics.trackCloudSync(
            action: 'pull_to_local',
            itemCount: _cloudMovies.length + _cloudTvShows.length,
            outcome: success ? 'success' : 'error',
            durationMs: stopwatch.elapsedMilliseconds,
          );
    }

    if (mounted) {
      setState(() => _isActionRunning = false);
      _fetchData();
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(
          content: Text(
            success ? tr('finished_sync_local') : tr('error_occured'),
            style: const TextStyle(fontFamily: 'FigtreeSB'),
          ),
          duration: const Duration(seconds: 2),
        ),
        context,
      );
    }
  }

  Future<void> _deleteMovieFromCloud(int index) async {
    final movie = _cloudMovies[index];
    if (movie.id == null) return;

    final success =
        await BookmarkSyncService.instance.deleteMovieFromCloud(movie.id!);
    if (mounted) {
      context.read<SettingsProvider>().analytics.trackCloudSync(
            action: 'delete_cloud_movie',
            itemCount: 1,
            outcome: success ? 'success' : 'error',
          );
    }
    if (success && mounted) {
      setState(() {
        _cloudMovies.removeAt(index);
      });
    }
  }

  Future<void> _deleteTvFromCloud(int index) async {
    final tv = _cloudTvShows[index];
    if (tv.id == null) return;

    final success =
        await BookmarkSyncService.instance.deleteTVFromCloud(tv.id!);
    if (mounted) {
      context.read<SettingsProvider>().analytics.trackCloudSync(
            action: 'delete_cloud_tv',
            itemCount: 1,
            outcome: success ? 'success' : 'error',
          );
    }
    if (success && mounted) {
      setState(() {
        _cloudTvShows.removeAt(index);
      });
    }
  }

  String _formatLastSynced(DateTime? timestamp) {
    if (timestamp == null) return tr('never');
    final diff = DateTime.now().difference(timestamp);
    String ago(String key, int n) =>
        tr(key, namedArgs: <String, String>{'n': '$n'});
    if (diff.inSeconds < 45) return tr('just_now');
    if (diff.inMinutes < 60) return ago('n_minutes_ago', diff.inMinutes);
    if (diff.inHours < 24) return ago('n_hours_ago', diff.inHours);
    return ago('n_days_ago', diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final user = _auth.currentUser;
    final isSignedIn = user != null && !user.isAnonymous;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('sync')),
      body: !isSignedIn
          ? EmptyState(
              icon: PhosphorIcons.cloudSlash(),
              title: tr('auto_sync_off'),
              message: tr('bookmark_feature_notice'),
              actionLabel: tr('login_signup'),
              actionIcon: PhosphorIcons.signIn(),
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ).then((_) => _fetchData()),
            )
          : AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) => CustomScrollView(
                slivers: [
                  SliverReadableWidth(
                    maxWidth: _contentWidth,
                    slivers: [
                      SliverToBoxAdapter(child: _buildStatus(context, user)),
                      SliverToBoxAdapter(child: _buildMetricsOverview(context)),
                      SliverToBoxAdapter(child: _buildKindSwitch(context)),
                      ..._buildTitles(
                        context,
                        series: _tabController.index == 1,
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: AppSpace.xxxl +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  /// Whether sync is on, when it last ran, and Sync now.
  Widget _buildStatus(BuildContext context, User user) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.xs, gutter, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.hero),
        ),
        child: ValueListenableBuilder<DateTime?>(
          valueListenable: BookmarkSyncService.instance.lastSyncedNotifier,
          builder: (context, lastSynced, _) =>
              ValueListenableBuilder<SyncStatus>(
            valueListenable: BookmarkSyncService.instance.statusNotifier,
            builder: (context, status, _) {
              final syncing = status == SyncStatus.syncing || _isActionRunning;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.idleFill,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIcons.cloudCheck(),
                          color: palette.foreground,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('auto_sync_on'),
                              style: AppType.cardTitle.copyWith(
                                fontSize: 16,
                                color: palette.foreground,
                              ),
                            ),
                            Text(
                              user.email ?? user.uid,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.metadata.copyWith(
                                fontSize: 13,
                                color: palette.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    tr('auto_sync_description'),
                    style: AppType.body.copyWith(color: palette.mutedText),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('last_synced_at', namedArgs: <String, String>{
                            'time': _formatLastSynced(lastSynced),
                          }),
                          style: AppType.metadata.copyWith(
                            fontSize: 13,
                            color: palette.mutedText,
                          ),
                        ),
                      ),
                      PillButton(
                        busy: syncing,
                        icon: PhosphorIcons.arrowsClockwise(),
                        label: tr('sync_now'),
                        onPressed: _runFullSync,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsOverview(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
      child: Row(
        children: [
          Expanded(
            child: _MetricTile(
              label: tr('movies'),
              cloudCount: _cloudMovies.length,
              localCount: _localMovieCount,
              icon: PhosphorIcons.filmStrip(),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: _MetricTile(
              label: tr('tv_series'),
              cloudCount: _cloudTvShows.length,
              localCount: _localTvCount,
              icon: PhosphorIcons.television(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKindSwitch(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.xxl, gutter, AppSpace.md),
      child: SegmentSwitch<int>(
        segments: [
          Segment(0, tr('movies'), icon: PhosphorIcons.filmStrip()),
          Segment(1, tr('tv_series'), icon: PhosphorIcons.television()),
        ],
        selected: _tabController.index,
        onChanged: (index) => _tabController.animateTo(index),
      ),
    );
  }

  /// The saved titles of one kind as a poster grid, each with a button to
  /// take it off the cloud, then the two ways to sync them.
  List<Widget> _buildTitles(BuildContext context, {required bool series}) {
    final gutter = AppSpace.gutter(context);
    const spacing = 10.0;
    final content = math.min(MediaQuery.sizeOf(context).width, _contentWidth);
    final columns = content >= AppBreakpoints.tablet ? 4 : 3;
    final width = (content - gutter * 2 - spacing * (columns - 1)) / columns;
    final actions = SliverPadding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.lg, gutter, 0),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: PillButton(
                icon: PhosphorIcons.cloudArrowDown(),
                label: tr(series ? 'offline_tv_sync' : 'offline_movie_sync'),
                onPressed: _isActionRunning ? null : _pullCloudToLocal,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: PillButton(
                primary: true,
                busy: _isActionRunning,
                icon: PhosphorIcons.cloudArrowUp(),
                label: tr(series ? 'online_tv_sync' : 'online_movie_sync'),
                onPressed: _pushLocalToCloud,
              ),
            ),
          ],
        ),
      ),
    );
    if (_isLoading) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverToBoxAdapter(
            child: SkeletonPulse(
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var i = 0; i < 6; i++)
                    SkeletonBlock(
                      width: width,
                      height: width / PosterCard.aspectRatio,
                    ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    final items = series
        ? _cloudTvShows.map(MediaItem.fromSeries).toList()
        : _cloudMovies.map(MediaItem.fromMovie).toList();
    if (items.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverToBoxAdapter(
            child: DetailsMessage(
              message: tr(series ? 'no_tv_online' : 'no_movies_online'),
            ),
          ),
        ),
        actions,
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: PosterCard.aspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => Stack(
            children: [
              PosterCard(
                item: items[index],
                width: width,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => series
                        ? TVDetailPage(
                            tvSeries: _cloudTvShows[index],
                            heroId: 'sync_tv_${items[index].id}',
                          )
                        : MovieDetailPage(
                            movie: _cloudMovies[index],
                            heroId: 'sync_movie_${items[index].id}',
                          ),
                  ),
                ).then((_) => _fetchData()),
              ),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: Material(
                  color: const Color(0x8C000000),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: tr('remove_from_cloud'),
                    visualDensity: VisualDensity.compact,
                    color: const Color(0xFFFFFFFF),
                    onPressed: () => series
                        ? _deleteTvFromCloud(index)
                        : _deleteMovieFromCloud(index),
                    icon: Icon(PhosphorIcons.trash(), size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions,
    ];
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.cloudCount,
    required this.localCount,
    required this.icon,
  });

  final String label;
  final int cloudCount;
  final int localCount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget count(int value, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: AppType.sectionHeader.copyWith(
                fontFamily: AppType.bold,
                color: palette.foreground,
              ),
            ),
            Text(
              label,
              style: AppType.metadata.copyWith(color: palette.mutedText),
            ),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.mutedText),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle.copyWith(color: palette.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(child: count(cloudCount, tr('cloud'))),
              Expanded(child: count(localCount, tr('on_this_device'))),
            ],
          ),
        ],
      ),
    );
  }
}
