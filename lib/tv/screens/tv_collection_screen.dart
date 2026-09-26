import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/tv_design.dart';
import '../controllers/tv_catalog_controller.dart';
import '../focus/tv_focusable.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_state_panel.dart';

/// Every title in a [TvCollection] (one streaming service, or one genre) as a
/// grid that loads further pages as focus nears the end.
///
/// There is no spotlight here, so the cards keep their titles and facts.
class TvCollectionScreen extends StatefulWidget {
  const TvCollectionScreen({
    required this.collection,
    required this.onOpenMedia,
    super.key,
  });

  final TvCollection collection;
  final ValueChanged<TvMediaItem> onOpenMedia;

  @override
  State<TvCollectionScreen> createState() => _TvCollectionScreenState();
}

class _TvCollectionScreenState extends State<TvCollectionScreen> {
  /// How close to the end focus gets before the next page is fetched: about
  /// two grid rows, so it usually lands before the remote reaches it.
  static const _prefetchDistance = 12;

  final List<TvMediaItem> _items = <TvMediaItem>[];
  final Set<String> _ids = <String>{};
  int _loadedPages = 0;
  bool _loading = false;
  bool _ended = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_loading || _ended) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.collection.loadPage(_loadedPages + 1);
      if (!mounted) return;
      setState(() {
        _loadedPages++;
        // TMDB's discover pages can repeat a title across a page boundary,
        // and the grid needs every id once.
        _items.addAll(page.where((item) => _ids.add(item.stableId)));
        _ended = page.isEmpty;
      });
    } catch (error) {
      // A later page failing leaves the loaded ones in place; the next focus
      // near the end tries it again.
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleItemFocused(TvMediaItem item) {
    final index = _items.indexOf(item);
    if (index >= _items.length - _prefetchDistance) _loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = TvShellMetrics.fromConstraints(constraints);
          return Padding(
            padding: EdgeInsets.all(metrics.safeInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Header(collection: widget.collection, metrics: metrics),
                SizedBox(height: metrics.compact ? 10 : 18),
                Expanded(child: _buildBody(metrics)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(TvShellMetrics metrics) {
    if (_items.isEmpty) {
      if (_error != null) {
        return TvStatePanel.error(onRetry: _loadNextPage);
      }
      if (_ended) {
        return TvStatePanel(
          title: 'Nothing here yet',
          message: 'No titles are listed for ${widget.collection.title} '
              'right now.',
          icon: PhosphorIcons.filmStrip(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return TvContentGrid<TvMediaItem>(
      scopeId: 'collection-${widget.collection.id}',
      items: _items,
      autofocus: true,
      itemId: (item) => item.stableId,
      semanticLabel: (item) => item.title,
      targetItemWidth: metrics.mediaCardWidth,
      itemAspectRatio: TvMediaCard.artworkAspectRatio,
      itemDetailsExtent: TvMediaCard.detailsHeight,
      itemBuilder: (_, item, width) => TvMediaCard(
        item: item,
        width: width,
        badge: TvMediaBadge.recencyOf(item),
      ),
      onItemActivated: widget.onOpenMedia,
      onItemFocused: _handleItemFocused,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.collection, required this.metrics});

  final TvCollection collection;
  final TvShellMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final logo = collection.logoAsset;
    return Row(
      children: <Widget>[
        TvFocusable(
          semanticLabel: 'Back',
          onActivate: () => Navigator.of(context).maybePop(),
          focusScale: 1.03,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: palette.raisedSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(PhosphorIcons.caretLeft(), size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Back',
                  style: TextStyle(fontFamily: 'FigtreeSB', fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        if (logo != null) ...<Widget>[
          Container(
            height: metrics.compact ? 48 : 60,
            width: (metrics.compact ? 48 : 60) * 16 / 9,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              // The same dark plate as the service's tile: most logos are drawn
              // for one, in every theme.
              color: const Color(0xff1e1f22),
              borderRadius: BorderRadius.circular(TvDesign.cardRadius),
            ),
            child: Image.asset(logo, fit: BoxFit.contain),
          ),
          const SizedBox(width: 18),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                collection.kicker,
                style: TextStyle(
                  color: colors.primary,
                  fontFamily: 'FigtreeSB',
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                collection.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground,
                  fontFamily: 'FigtreeBold',
                  fontSize: metrics.compact ? 30 : 38,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
