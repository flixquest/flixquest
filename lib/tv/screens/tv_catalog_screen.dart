import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../widgets/common_widgets.dart'
    show AppStreamingService, appStreamingServices;
import '../app/tv_design.dart';
import '../app/tv_shell_layout.dart';
import '../controllers/tv_catalog_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_browse_view.dart';
import '../widgets/tv_shortcut_tile.dart';
import '../widgets/tv_state_panel.dart';

/// The Movies or Series destination: a browse page of rows, with the phone
/// app's streaming services and the genres as rows of shortcuts.
class TvCatalogScreen extends StatefulWidget {
  const TvCatalogScreen({
    required this.kind,
    required this.metrics,
    required this.onOpenMedia,
    required this.onOpenCollection,
    this.focusController,
    super.key,
  });

  final TvMediaKind kind;
  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final ValueChanged<TvCollection> onOpenCollection;
  final TvScreenFocusController? focusController;

  @override
  State<TvCatalogScreen> createState() => _TvCatalogScreenState();
}

class _TvCatalogScreenState extends State<TvCatalogScreen> {
  static const _controller = TvCatalogController();
  Future<TvCatalogData>? _data;
  String? _configurationKey;

  bool get _isMovie => widget.kind == TvMediaKind.movie;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final key = '${widget.kind.name}|${settings.appLanguage}|'
        '${settings.enableProxy}|${dependencies.tmdbProxy}';
    if (_configurationKey != key) {
      _configurationKey = key;
      _data = _load(settings, dependencies);
    }
  }

  Future<TvCatalogData> _load(
    SettingsProvider settings,
    AppDependencyProvider dependencies,
  ) {
    return _controller.loadCatalog(
      kind: widget.kind,
      settings: settings,
      dependencies: dependencies,
    );
  }

  void _retry() {
    setState(() {
      _data = _load(
        context.read<SettingsProvider>(),
        context.read<AppDependencyProvider>(),
      );
    });
  }

  void _openService(AppStreamingService service) {
    widget.onOpenCollection(_controller.serviceCollection(
      kind: widget.kind,
      service: service,
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // A full-bleed screen: only the browse view's artwork reaches the edges.
    final insets = TvShellInsets.of(context);
    return FutureBuilder<TvCatalogData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: insets,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data;
        final featured = data?.featured;
        if (snapshot.hasError || data == null || featured == null) {
          return Padding(
            padding: insets,
            child: TvStatePanel(
              title: _isMovie ? 'No movies to show' : 'No series to show',
              message: 'FlixQuest could not load this page. Try again.',
              icon: _isMovie
                  ? PhosphorIcons.filmSlate()
                  : PhosphorIcons.television(),
              actionLabel: 'Retry',
              onAction: _retry,
            ),
          );
        }
        return TvBrowseView(
          featured: featured,
          rows: _rows(data),
          metrics: widget.metrics,
          onOpenMedia: widget.onOpenMedia,
          focusController: widget.focusController,
          focusMemoryScope: 'tv-${widget.kind.name}-row',
        );
      },
    );
  }

  List<TvBrowseRow> _rows(TvCatalogData data) {
    final kind = widget.kind.name;
    final noun = _isMovie ? 'movies' : 'series';
    return <TvBrowseRow>[
      TvMediaRow(
        title: 'Trending now',
        scopeId: '$kind-trending',
        items: data.trending,
      ),
      TvMediaRow(
        title: 'Popular $noun',
        scopeId: '$kind-popular',
        items: data.popular,
      ),
      TvShortcutRow(
        title: 'Streaming services',
        scopeId: '$kind-services',
        shortcuts: <TvBrowseShortcut>[
          for (final service in appStreamingServices)
            TvBrowseShortcut(
              id: 'service-${service.providerId}',
              title: service.name,
              facts: const <String>['Streaming service'],
              description:
                  'The most popular $noun streaming on ${service.name}.',
              logoAsset: service.imagePath,
              onActivate: () => _openService(service),
            ),
        ],
      ),
      TvMediaRow(
        title: 'Top rated',
        scopeId: '$kind-top-rated',
        items: data.topRated,
      ),
      TvMediaRow(
        title: _isMovie ? 'Coming soon' : 'New episodes',
        scopeId: '$kind-fresh',
        items: data.fresh,
      ),
      TvShortcutRow(
        title: 'Genres',
        scopeId: '$kind-genres',
        shortcuts: <TvBrowseShortcut>[
          for (final genre in data.genres)
            TvBrowseShortcut(
              id: 'genre-${genre.genreID}',
              title: genre.genreName!,
              facts: const <String>['Genre'],
              description: 'Popular ${genre.genreName!.toLowerCase()} $noun, '
                  'the most watched first.',
              onActivate: () => widget.onOpenCollection(
                _controller.genreCollection(
                  kind: widget.kind,
                  genre: genre,
                  settings: context.read<SettingsProvider>(),
                  dependencies: context.read<AppDependencyProvider>(),
                ),
              ),
            ),
        ],
      ),
      for (final shelf in data.serviceShelves)
        TvMediaRow(
          title: 'Popular on ${shelf.service.name}',
          scopeId: '$kind-on-${shelf.service.providerId}',
          items: shelf.items,
        ),
    ];
  }
}
