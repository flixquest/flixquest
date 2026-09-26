import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../controllers/bookmark_database_controller.dart';
import '../../functions/function.dart';
import '../../models/movie.dart';
import '../../models/tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../services/bookmark_sync_service.dart';
import '../../services/globle_method.dart';
import '../../services/recently_watched_sync_service.dart';
import '../../ui_components/app_ui_components.dart';
import '../../widgets/common_widgets.dart';
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
    if (timestamp == null) return 'Never';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isSignedIn = user != null && !user.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(PhosphorIcons.caretLeft()),
        ),
        title: Text(tr('sync')),
        actions: [
          ValueListenableBuilder<SyncStatus>(
            valueListenable: BookmarkSyncService.instance.statusNotifier,
            builder: (context, status, _) {
              final isSyncing =
                  status == SyncStatus.syncing || _isActionRunning;
              return IconButton(
                tooltip: tr('sync'),
                onPressed: isSignedIn && !isSyncing ? _runFullSync : null,
                icon: isSyncing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(PhosphorIcons.arrowsClockwise()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: !isSignedIn
            ? SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: AppResponsiveContent(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppUI.pagePadding(context),
                    vertical: 16,
                  ),
                  child: _buildAutoSyncBanner(context, false, user),
                ),
              )
            : NestedScrollView(
                physics: const BouncingScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: AppResponsiveContent(
                        padding: EdgeInsets.fromLTRB(
                          AppUI.pagePadding(context),
                          16,
                          AppUI.pagePadding(context),
                          14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAutoSyncBanner(context, true, user),
                            const SizedBox(height: 14),
                            _buildMetricsOverview(context),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SegmentedTabsHeaderDelegate(
                        controller: _tabController,
                        tabs: [
                          AppSegmentedTab(
                            label: tr('movies'),
                            icon: PhosphorIcons.filmStrip(),
                          ),
                          AppSegmentedTab(
                            label: tr('tv_series'),
                            icon: PhosphorIcons.television(),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMoviesTab(context),
                    _buildTvTab(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAutoSyncBanner(
    BuildContext context,
    bool isSignedIn,
    User? user,
  ) {
    final colors = Theme.of(context).colorScheme;

    if (!isSignedIn) {
      return Card(
        margin: EdgeInsets.zero,
        color: colors.errorContainer.withValues(alpha: .35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.error.withValues(alpha: .3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: .15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.cloudSlash(),
                      color: colors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Sync Unavailable',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontFamily: 'FigtreeSB'),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Signed-out mode',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tr('bookmark_feature_notice'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    ).then((_) => _fetchData());
                  },
                  icon: Icon(PhosphorIcons.signIn(), size: 18),
                  label: Text(tr('account')),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<DateTime?>(
      valueListenable: BookmarkSyncService.instance.lastSyncedNotifier,
      builder: (context, lastSynced, _) {
        return ValueListenableBuilder<SyncStatus>(
          valueListenable: BookmarkSyncService.instance.statusNotifier,
          builder: (context, status, _) {
            final isSyncing = status == SyncStatus.syncing || _isActionRunning;

            return Card(
              margin: EdgeInsets.zero,
              color: colors.primaryContainer.withValues(alpha: .45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: .35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            PhosphorIcons.cloudCheck(
                              PhosphorIconsStyle.fill,
                            ),
                            color: colors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Auto-Sync Active',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontFamily: 'FigtreeSB',
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          colors.primary.withValues(alpha: .2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'FigtreeSB',
                                        fontWeight: FontWeight.bold,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? user?.uid ?? 'Account Active',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your movie and TV show bookmarks automatically synchronize across all signed-in devices when changed.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.clock(),
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Last synced: ${_formatLastSynced(lastSynced)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: isSyncing ? null : _runFullSync,
                          icon: isSyncing
                              ? const SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(PhosphorIcons.arrowsClockwise(), size: 15),
                          label: Text(
                            isSyncing ? tr('sync') : 'Sync Now',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricsOverview(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: tr('movies'),
            cloudCount: _cloudMovies.length,
            localCount: _localMovieCount,
            icon: PhosphorIcons.filmStrip(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: tr('tv_series'),
            cloudCount: _cloudTvShows.length,
            localCount: _localTvCount,
            icon: PhosphorIcons.television(),
          ),
        ),
      ],
    );
  }

  Widget _buildMoviesTab(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cloudMovies.isEmpty) {
      return AppEmptyState(
        icon: PhosphorIcons.filmStrip(),
        title: tr('no_movies_online'),
        message: tr('online_movie_sync'),
        action: ElevatedButton.icon(
          onPressed: _pushLocalToCloud,
          icon: Icon(PhosphorIcons.cloudArrowUp()),
          label: Text(tr('online_movie_sync')),
        ),
      );
    }

    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;

    return AppResponsiveContent(
      padding: EdgeInsets.symmetric(
        horizontal: AppUI.pagePadding(context),
      ),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppUI.mediaGridColumns(context),
                childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
                crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
                mainAxisSpacing: 16,
              ),
              itemCount: _cloudMovies.length,
              itemBuilder: (context, index) {
                final movie = _cloudMovies[index];
                return _CloudMediaGridCard(
                  title: movie.title ?? tr('not_available'),
                  posterPath: movie.posterPath,
                  rating: movie.voteAverage?.toDouble(),
                  proxyUrl: proxy,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovieDetailPage(
                          movie: movie,
                          heroId: 'sync_movie_${movie.id}',
                        ),
                      ),
                    ).then((_) => _fetchData());
                  },
                  onDelete: () => _deleteMovieFromCloud(index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isActionRunning ? null : _pullCloudToLocal,
                    icon: Icon(PhosphorIcons.cloudArrowDown(), size: 18),
                    label: Text(
                      tr('offline_movie_sync'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isActionRunning ? null : _pushLocalToCloud,
                    icon: Icon(PhosphorIcons.cloudArrowUp(), size: 18),
                    label: Text(
                      tr('online_movie_sync'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTvTab(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cloudTvShows.isEmpty) {
      return AppEmptyState(
        icon: PhosphorIcons.television(),
        title: tr('no_tv_online'),
        message: tr('online_tv_sync'),
        action: ElevatedButton.icon(
          onPressed: _pushLocalToCloud,
          icon: Icon(PhosphorIcons.cloudArrowUp()),
          label: Text(tr('online_tv_sync')),
        ),
      );
    }

    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;

    return AppResponsiveContent(
      padding: EdgeInsets.symmetric(
        horizontal: AppUI.pagePadding(context),
      ),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppUI.mediaGridColumns(context),
                childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
                crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
                mainAxisSpacing: 16,
              ),
              itemCount: _cloudTvShows.length,
              itemBuilder: (context, index) {
                final tv = _cloudTvShows[index];
                return _CloudMediaGridCard(
                  title: tv.name ?? tr('not_available'),
                  posterPath: tv.posterPath,
                  rating: tv.voteAverage?.toDouble(),
                  proxyUrl: proxy,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TVDetailPage(
                          tvSeries: tv,
                          heroId: 'sync_tv_${tv.id}',
                        ),
                      ),
                    ).then((_) => _fetchData());
                  },
                  onDelete: () => _deleteTvFromCloud(index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isActionRunning ? null : _pullCloudToLocal,
                    icon: Icon(PhosphorIcons.cloudArrowDown(), size: 18),
                    label: Text(
                      tr('offline_tv_sync'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isActionRunning ? null : _pushLocalToCloud,
                    icon: Icon(PhosphorIcons.cloudArrowUp(), size: 18),
                    label: Text(
                      tr('online_tv_sync'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SegmentedTabsHeaderDelegate({
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<AppSegmentedTab> tabs;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: AppResponsiveContent(
        padding: EdgeInsets.symmetric(
          horizontal: AppUI.pagePadding(context),
        ),
        child: AppSegmentedTabs(
          controller: controller,
          tabs: tabs,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 54.0;

  @override
  double get minExtent => 54.0;

  @override
  bool shouldRebuild(covariant _SegmentedTabsHeaderDelegate oldDelegate) {
    return oldDelegate.controller != controller || oldDelegate.tabs != tabs;
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFamily: 'FigtreeSB',
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$cloudCount',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'FigtreeSB',
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                  ),
                  Text(
                    'Cloud',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              Container(
                height: 24,
                width: 1,
                color: colors.outlineVariant.withValues(alpha: .5),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$localCount',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'FigtreeSB',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Local',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CloudMediaGridCard extends StatelessWidget {
  const _CloudMediaGridCard({
    required this.title,
    required this.posterPath,
    required this.rating,
    required this.proxyUrl,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String? posterPath;
  final double? rating;
  final String proxyUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final imageUrl = posterPath == null
        ? ''
        : buildImageUrl(
                TMDB_BASE_IMAGE_URL, proxyUrl, settings.enableProxy, context) +
            settings.imageQuality +
            posterPath!;

    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: AppUI.posterAspectRatio,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppUI.cardRadius),
                    child: posterPath == null
                        ? Image.asset(
                            'assets/images/na_logo.png',
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            cacheManager: cacheProp(),
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                scrollingImageShimmer(settings.appTheme),
                            errorWidget: (_, __, ___) => Image.asset(
                              'assets/images/na_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  right: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppRatingBadge(rating: rating, compact: true),
                      SizedBox.square(
                        dimension: 28,
                        child: IconButton.filledTonal(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: tr('delete'),
                          onPressed: onDelete,
                          icon: Icon(PhosphorIcons.trash(), size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.mediaGridTitleGap),
          SizedBox(
            width: double.infinity,
            height: AppUI.mediaGridTitleHeight,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'FigtreeSB',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
