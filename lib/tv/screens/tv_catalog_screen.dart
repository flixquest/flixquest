import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../controllers/tv_catalog_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../focus/tv_focusable.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_state_panel.dart';

class TvCatalogScreen extends StatefulWidget {
  const TvCatalogScreen({
    required this.kind,
    required this.metrics,
    required this.onOpenMedia,
    this.focusController,
    super.key,
  });

  final TvMediaKind kind;
  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final TvScreenFocusController? focusController;

  @override
  State<TvCatalogScreen> createState() => _TvCatalogScreenState();
}

class _TvCatalogScreenState extends State<TvCatalogScreen> {
  static const _controller = TvCatalogController();
  final TvContentGridController _gridFocusController =
      TvContentGridController();
  Future<List<TvMediaItem>>? _items;
  String? _configurationKey;
  String _sort = 'Discover';

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _gridFocusController.requestFocus);
  }

  @override
  void didUpdateWidget(TvCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _gridFocusController.requestFocus);
    }
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final key = '${widget.kind.name}|${settings.appLanguage}|'
        '${settings.enableProxy}|${dependencies.tmdbProxy}';
    if (_configurationKey != key) {
      _configurationKey = key;
      _items = _load(settings, dependencies);
    }
  }

  Future<List<TvMediaItem>> _load(
    SettingsProvider settings,
    AppDependencyProvider dependencies,
  ) {
    return widget.kind == TvMediaKind.movie
        ? _controller.loadMovies(settings: settings, dependencies: dependencies)
        : _controller.loadSeries(
            settings: settings, dependencies: dependencies);
  }

  void _retry() {
    setState(() {
      _items = _load(
        context.read<SettingsProvider>(),
        context.read<AppDependencyProvider>(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.kind == TvMediaKind.movie ? 'Movies' : 'Series';
    final icon = widget.kind == TvMediaKind.movie
        ? PhosphorIcons.filmSlate()
        : PhosphorIcons.television();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.metrics.contentPadding,
        0,
        widget.metrics.contentPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CatalogHeader(title: title, icon: icon),
          const SizedBox(height: 8),
          Row(children: [
            for (final sort in ['Discover', 'Top rated', 'Newest'])
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TvFocusable(
                  semanticLabel: '$sort $title',
                  selected: _sort == sort,
                  focusScale: 1,
                  borderRadius: BorderRadius.circular(4),
                  onActivate: () => setState(() => _sort = sort),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _sort == sort
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      sort,
                      style: TextStyle(
                        fontFamily: _sort == sort ? 'FigtreeSB' : 'Figtree',
                        fontSize: 16,
                        color: _sort == sort
                            ? TvDesign.foreground
                            : TvDesign.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          SizedBox(height: widget.metrics.compact ? 10 : 18),
          Expanded(
            child: FutureBuilder<List<TvMediaItem>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return TvStatePanel.error(onRetry: _retry);
                }
                final items = List<TvMediaItem>.of(
                    snapshot.data ?? const <TvMediaItem>[]);
                if (_sort == 'Top rated') {
                  items
                      .sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
                } else if (_sort == 'Newest') {
                  items.sort((a, b) =>
                      (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''));
                }
                if (items.isEmpty) {
                  return TvStatePanel(
                    title: 'No $title available',
                    message: 'Try again in a moment.',
                    icon: icon,
                    actionLabel: 'Retry',
                    onAction: _retry,
                  );
                }
                return TvContentGrid<TvMediaItem>(
                  controller: _gridFocusController,
                  scopeId: 'catalog-${widget.kind.name}-$_sort',
                  items: items,
                  itemId: (item) => item.stableId,
                  semanticLabel: (item) => item.title,
                  targetItemWidth: widget.metrics.mediaCardWidth,
                  itemAspectRatio: TvMediaCard.artworkAspectRatio,
                  itemDetailsExtent: TvMediaCard.detailsHeight,
                  itemBuilder: (_, item, width) =>
                      TvMediaCard(item: item, width: width),
                  onItemActivated: widget.onOpenMedia,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, color: colors.primary, size: 32),
        const SizedBox(width: 13),
        Text(
          title,
          style: TextStyle(
            color: colors.onSurface,
            fontFamily: 'FigtreeBold',
            fontSize: 28,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
