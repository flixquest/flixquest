import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../screens/common/update_screen.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../controllers/tv_home_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_browse_view.dart';
import '../widgets/tv_continue_watching_menu.dart';
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
  final ValueChanged<TvMediaItem> onContinueWatching;
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

        return TvBrowseView(
          featured: data.hero!,
          metrics: widget.metrics,
          onOpenMedia: widget.onOpenMedia,
          focusController: widget.focusController,
          focusMemoryScope: 'tv-home-row',
          rows: <TvBrowseRow>[
            TvBrowseRow(
              title: 'Continue watching',
              scopeId: 'home-continue-watching',
              items: continueWatching,
              onItemActivated: widget.onContinueWatching,
              onItemMenu: _removeFromContinueWatching,
              itemMenuHint: 'Hold OK to remove',
            ),
            _row(
                'Trending movies', 'home-trending-movies', data.trendingMovies),
            _row('Popular movies', 'home-popular-movies', data.popularMovies),
            _row(
                'Trending series', 'home-trending-series', data.trendingSeries),
            _row('Popular series', 'home-popular-series', data.popularSeries),
          ],
        );
      },
    );
  }

  TvBrowseRow _row(String title, String scopeId, List<TvMediaItem> items) =>
      TvBrowseRow(
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
