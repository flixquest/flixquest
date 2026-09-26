import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/tv_design.dart';
import '../controllers/tv_catalog_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_state_panel.dart';

class TvLibraryScreen extends StatefulWidget {
  const TvLibraryScreen({
    required this.metrics,
    required this.onOpenMedia,
    this.revision = 0,
    this.focusController,
    super.key,
  });

  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;

  /// Bumped when a bookmark may have changed; the list reloads in place so
  /// the card the user came back to can take focus again.
  final int revision;
  final TvScreenFocusController? focusController;

  @override
  State<TvLibraryScreen> createState() => _TvLibraryScreenState();
}

class _TvLibraryScreenState extends State<TvLibraryScreen> {
  static const _controller = TvCatalogController();
  final TvContentGridController _gridFocusController =
      TvContentGridController();
  late Future<List<TvMediaItem>> _items;

  @override
  void initState() {
    super.initState();
    _items = _controller.loadLibrary();
    widget.focusController?.attach(this, _gridFocusController.requestFocus);
  }

  @override
  void didUpdateWidget(TvLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _gridFocusController.requestFocus);
    }
    if (oldWidget.revision != widget.revision) {
      _items = _controller.loadLibrary();
    }
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    super.dispose();
  }

  void _refresh() {
    setState(() => _items = _controller.loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          Row(
            children: <Widget>[
              Icon(PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
                  color: colors.primary, size: 32),
              const SizedBox(width: 13),
              Text(
                'My List',
                style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: 'FigtreeSB',
                  fontSize: 34,
                ),
              ),
            ],
          ),
          SizedBox(height: widget.metrics.compact ? 10 : 18),
          Expanded(
            child: FutureBuilder<List<TvMediaItem>>(
              future: _items,
              builder: (context, snapshot) {
                // A reload keeps the previous list on screen (FutureBuilder
                // carries its data over) so the grid and its focus survive.
                if (snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return TvStatePanel.error(onRetry: _refresh);
                }
                final items = snapshot.data ?? const <TvMediaItem>[];
                if (items.isEmpty) {
                  return TvStatePanel(
                    title: 'Your list is empty',
                    message:
                        'Bookmark a movie or series and it will appear here.',
                    icon: PhosphorIcons.bookmarkSimple(),
                    actionLabel: 'Refresh',
                    onAction: _refresh,
                  );
                }
                return TvContentGrid<TvMediaItem>(
                  controller: _gridFocusController,
                  scopeId: 'tv-library',
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
