import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../screens/common/update_screen.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../app/tv_shell_layout.dart';
import '../controllers/tv_home_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_browse_skeleton.dart';
import '../widgets/tv_browse_view.dart';
import '../widgets/tv_continue_watching_menu.dart';
import '../widgets/tv_media_card.dart' show TvMediaBadge;
import '../widgets/tv_state_panel.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({
    required this.metrics,
    required this.onOpenMedia,
    required this.onContinueWatching,
    this.focusController,
    super.key,
  });

  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final FutureOr<void> Function(TvMediaItem item) onContinueWatching;
  final TvScreenFocusController? focusController;

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  static const _controller = TvHomeController();

  Future<TvHomeData>? _homeData;
  String? _configurationKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final configurationKey = <Object>[
      settings.appLanguage,
      settings.enableProxy,
      dependencies.tmdbProxy,
    ].join('|');
    if (_configurationKey != configurationKey) {
      _configurationKey = configurationKey;
      _homeData = _controller.load(
        settings: settings,
        dependencies: dependencies,
      );
    }
  }

  void _retry() {
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    setState(() {
      _homeData = _controller.load(
        settings: settings,
        dependencies: dependencies,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Home is full bleed: only the browse view's artwork reaches the edges.
    final insets = TvShellInsets.of(context);
    return Column(children: [
      Padding(
        padding: insets.copyWith(bottom: 0),
        child: const UpdateBottom(television: true),
      ),
      Expanded(child: _buildFeed(context, insets)),
    ]);
  }

  Widget _buildFeed(BuildContext context, EdgeInsets insets) {
    final recent = context.watch<RecentProvider>();
    final continueWatching = <TvMediaItem>[
      ...recent.movies.map(TvMediaItem.fromRecentMovie),
      ...recent.episodes.map(TvMediaItem.fromRecentEpisode),
    ].where((item) => item.id >= 0).take(16).toList(growable: false);
    return FutureBuilder<TvHomeData>(
      future: _homeData,
      builder: (context, snapshot) => AnimatedSwitcher(
        // The page fades in over its skeleton rather than cutting to it.
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        child: KeyedSubtree(
          key: ValueKey<Object>(
            snapshot.connectionState != ConnectionState.done
                ? 'loading'
                : snapshot.hasError
                    ? 'error'
                    : snapshot.data?.hero?.stableId ?? 'empty',
          ),
          child: _buildState(snapshot, insets, continueWatching),
        ),
      ),
    );
  }

  Widget _buildState(
    AsyncSnapshot<TvHomeData> snapshot,
    EdgeInsets insets,
    List<TvMediaItem> continueWatching,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return TvBrowseSkeleton(metrics: widget.metrics);
    }
    if (snapshot.hasError) {
      return Padding(
        padding: insets,
        child: TvStatePanel.error(onRetry: _retry),
      );
    }
    final data = snapshot.data;
    if (data == null || data.isEmpty || data.hero == null) {
      return Padding(
        padding: insets,
        child: TvStatePanel(
          title: 'Nothing to show yet',
          message: 'FlixQuest could not find content for this region.',
          icon: PhosphorIcons.filmStrip(),
          actionLabel: 'Retry',
          onAction: _retry,
        ),
      );
    }

    final topTen = <String>{
      for (final item in <TvMediaItem>[...data.topMovies, ...data.topSeries])
        '${item.kind.name}:${item.id}',
    };
    return TvBrowseView(
      featured: data.hero!,
      metrics: widget.metrics,
      onOpenMedia: widget.onOpenMedia,
      focusController: widget.focusController,
      focusMemoryScope: 'tv-home-row',
      badgeFor: (item) => topTen.contains('${item.kind.name}:${item.id}')
          ? TvMediaBadge.top10
          : null,
      rows: <TvBrowseRow>[
        TvMediaRow(
          title: 'Continue watching',
          scopeId: 'home-continue-watching',
          items: continueWatching,
          onItemActivated: widget.onContinueWatching,
          onItemMenu: _removeFromContinueWatching,
          itemMenuHint: 'Hold OK to remove',
          showBadges: false,
        ),
        TvTopTenRow(
          title: 'Top 10 movies today',
          scopeId: 'home-top-movies',
          items: data.topMovies,
        ),
        _row('Trending movies', 'home-trending-movies', data.trendingMovies),
        _row('Popular movies', 'home-popular-movies', data.popularMovies),
        TvTopTenRow(
          title: 'Top 10 series today',
          scopeId: 'home-top-series',
          items: data.topSeries,
        ),
        _row('Trending series', 'home-trending-series', data.trendingSeries),
        _row('Popular series', 'home-popular-series', data.popularSeries),
      ],
    );
  }

  TvMediaRow _row(String title, String scopeId, List<TvMediaItem> items) =>
      TvMediaRow(
        title: title,
        scopeId: scopeId,
        items: items.take(16).toList(growable: false),
      );

  /// Drops an entry from the recently watched store, the way the phone UI's
  /// long press does.
  Future<void> _removeFromContinueWatching(TvMediaItem item) async {
    final removal = TvContinueWatchingRemoval.forItem(item);
    if (removal == null) return;
    final confirmed = await confirmRemoveFromContinueWatching(
      context: context,
      item: item,
    );
    if (!confirmed || !mounted) return;
    await removal.apply(context.read<RecentProvider>());
  }
}
