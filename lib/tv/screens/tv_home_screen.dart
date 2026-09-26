import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../screens/common/update_screen.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../controllers/tv_home_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_content_row.dart';
import '../widgets/tv_continue_watching_menu.dart';
import '../widgets/tv_hero.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_state_panel.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({
    required this.metrics,
    required this.onOpenMedia,
    required this.onContinueWatching,
    super.key,
  });

  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final ValueChanged<TvMediaItem> onContinueWatching;

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
  Widget build(BuildContext context) => Column(children: [
        const UpdateBottom(television: true),
        Expanded(child: _buildFeed(context)),
      ]);

  Widget _buildFeed(BuildContext context) {
    final recent = context.watch<RecentProvider>();
    final continueWatching = <TvMediaItem>[
      ...recent.movies.map(TvMediaItem.fromRecentMovie),
      ...recent.episodes.map(TvMediaItem.fromRecentEpisode),
    ].where((item) => item.id >= 0).take(16).toList(growable: false);
    return FutureBuilder<TvHomeData>(
      future: _homeData,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _TvHomeLoading();
        }
        if (snapshot.hasError) {
          return TvStatePanel.error(onRetry: _retry);
        }
        final data = snapshot.data;
        if (data == null || data.isEmpty || data.hero == null) {
          return TvStatePanel(
            title: 'Nothing to show yet',
            message: 'FlixQuest could not find content for this region.',
            icon: PhosphorIcons.filmStrip(),
            actionLabel: 'Retry',
            onAction: _retry,
          );
        }

        // Keep every row mounted so directional focus can discover content
        // below the viewport. A lazy ListView cannot focus a row until pointer
        // scrolling builds it, which strands TV remotes at the screen bottom.
        return SingleChildScrollView(
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.only(
            bottom: widget.metrics.contentPadding + TvDesign.focusOutset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TvHero(
                item: data.hero!,
                compact: widget.metrics.compact,
                onOpenDetails: () => widget.onOpenMedia(data.hero!),
              ),
              SizedBox(height: widget.metrics.compact ? 4 : 8),
              _mediaRow(
                'Continue watching',
                'home-continue-watching',
                continueWatching,
                onItemActivated: widget.onContinueWatching,
                onItemMenu: (item) => _removeFromContinueWatching(
                  item,
                  continueWatching.length,
                ),
                itemMenuHint: 'Hold OK to remove',
              ),
              _mediaRow('Trending movies', 'home-trending-movies',
                  data.trendingMovies),
              _mediaRow(
                  'Popular movies', 'home-popular-movies', data.popularMovies),
              _mediaRow('Trending series', 'home-trending-series',
                  data.trendingSeries),
              _mediaRow(
                  'Popular series', 'home-popular-series', data.popularSeries),
            ],
          ),
        );
      },
    );
  }

  /// Drops an entry from the recently watched store, the way the phone UI's
  /// long press does.
  Future<void> _removeFromContinueWatching(
    TvMediaItem item,
    int rowLength,
  ) async {
    final removal = TvContinueWatchingRemoval.forItem(item);
    if (removal == null) return;
    final confirmed = await confirmRemoveFromContinueWatching(
      context: context,
      item: item,
    );
    if (!confirmed || !mounted) return;
    await removal.apply(context.read<RecentProvider>());
    if (!mounted || rowLength > 1) return;
    // The row unmounts along with its last card and takes focus with it, so
    // hand the remote the hero instead of leaving it with nothing to steer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).nextFocus();
    });
  }

  Widget _mediaRow(String title, String scopeId, List<TvMediaItem> items,
      {ValueChanged<TvMediaItem>? onItemActivated,
      ValueChanged<TvMediaItem>? onItemMenu,
      String? itemMenuHint}) {
    if (items.isEmpty) return const SizedBox.shrink();
    final visibleItems = items.take(16).toList(growable: false);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.metrics.compact ? 16 : 24),
      child: TvContentRow<TvMediaItem>(
        title: title,
        scopeId: scopeId,
        items: visibleItems,
        itemId: (item) => item.stableId,
        semanticLabel: (item) => item.title,
        itemBuilder: (_, item) => TvMediaCard(
          item: item,
          width: widget.metrics.mediaCardWidth,
        ),
        onItemActivated: onItemActivated ?? widget.onOpenMedia,
        onItemMenu: onItemMenu,
        itemMenuHint: itemMenuHint,
      ),
    );
  }
}

class _TvHomeLoading extends StatelessWidget {
  const _TvHomeLoading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 18),
          Text(
            'Loading FlixQuest',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 19,
            ),
          ),
        ],
      ),
    );
  }
}
