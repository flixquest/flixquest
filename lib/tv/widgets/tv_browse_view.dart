import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/tv_design.dart';
import '../app/tv_shell_layout.dart';
import '../controllers/tv_title_logos.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_focusable.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import 'tv_content_row.dart';
import 'tv_media_card.dart';
import 'tv_shortcut_tile.dart';
import 'tv_spotlight.dart';
import 'tv_top_ten_rank.dart';

sealed class TvBrowseRow {
  const TvBrowseRow({required this.title, required this.scopeId});

  final String title;
  final String scopeId;

  /// An empty row is left out of the page altogether.
  bool get isEmpty;
}

/// A row of titles, shown as artwork-only posters.
class TvMediaRow extends TvBrowseRow {
  const TvMediaRow({
    required super.title,
    required super.scopeId,
    required this.items,
    this.onItemActivated,
    this.onItemMenu,
    this.itemMenuHint,
    this.showBadges = true,
  });

  final List<TvMediaItem> items;

  /// Whether the cards carry [TvBrowseView.badgeFor]'s corner labels; a row
  /// that says the same thing itself, such as Continue watching, leaves them
  /// out.
  final bool showBadges;

  /// Replaces the view's `onOpenMedia` for this row's items.
  final ValueChanged<TvMediaItem>? onItemActivated;
  final ValueChanged<TvMediaItem>? onItemMenu;
  final String? itemMenuHint;

  @override
  bool get isEmpty => items.isEmpty;
}

/// The ten most watched titles, each poster led by its rank.
class TvTopTenRow extends TvBrowseRow {
  TvTopTenRow({
    required super.title,
    required super.scopeId,
    required List<TvMediaItem> items,
  }) : items = items.take(10).toList(growable: false);

  final List<TvMediaItem> items;

  @override
  bool get isEmpty => items.isEmpty;
}

/// A row of tiles leading elsewhere, such as streaming services or genres.
class TvShortcutRow extends TvBrowseRow {
  const TvShortcutRow({
    required super.title,
    required super.scopeId,
    required this.shortcuts,
    this.onShortcutMenu,
    this.menuHint,
  });

  final List<TvBrowseShortcut> shortcuts;

  /// Holding OK on a tile, such as removing a recent search.
  final ValueChanged<TvBrowseShortcut>? onShortcutMenu;
  final String? menuHint;

  @override
  bool get isEmpty => shortcuts.isEmpty;
}

/// A Netflix-style browse page: the focused title fills the backdrop and the
/// spotlight above the rows, and the focused row holds one position on screen
/// while the rows move under it.
///
/// It starts on the billboard, with [featured] and its More info button. Down
/// enters the rows; Up from the first row or Back returns to the billboard.
///
/// The backdrop fills the view; everything else keeps to [TvShellInsets], so
/// as a full-bleed shell screen the artwork runs under the rail.
class TvBrowseView extends StatefulWidget {
  const TvBrowseView({
    required this.featured,
    required this.rows,
    required this.metrics,
    required this.onOpenMedia,
    required this.focusMemoryScope,
    this.focusController,
    this.badgeFor,
    this.showBillboard = true,
    super.key,
  });

  final TvMediaItem featured;
  final List<TvBrowseRow> rows;
  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;

  /// Focus-memory scope holding the row that last had focus, so returning to
  /// the page lands where the user left off.
  final String focusMemoryScope;
  final TvScreenFocusController? focusController;

  /// The page's own label for a card, such as [TvMediaBadge.top10]. Cards it
  /// leaves unlabelled are marked [TvMediaBadge.recent] when they are.
  final String? Function(TvMediaItem item)? badgeFor;

  /// Without the billboard the page is only rows: [featured] fills the
  /// spotlight until a card has focus, entering lands in the rows, and Up off
  /// the first row and Back are left to the screen around the view.
  final bool showBillboard;

  @override
  State<TvBrowseView> createState() => _TvBrowseViewState();
}

class _TvBrowseViewState extends State<TvBrowseView> {
  static const _motion = Duration(milliseconds: 260);

  /// Where the first row starts on the billboard, as a fraction of the height:
  /// low enough to leave the billboard its room, high enough to show the row.
  static const _billboardRowsTop = 0.7;

  /// Clearance around the spotlight's clip for the button's focus ring and
  /// scale.
  static const _focusRingRoom = 8.0;

  /// How much of the next row shows under the focused one, as a fraction of
  /// a row: its title and the top of its artwork, so the page reads as rows
  /// to move through rather than a single strip.
  static const _nextRowPeek = 0.4;

  /// The focused card grows from its leading edge by this much.
  static const _cardFocusScale = 1.1;

  /// Clears the grown card's trailing edge from the next card.
  static const _cardSpacing = 18.0;

  static final _backKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
  };

  final FocusNode _featuredFocus = FocusNode(debugLabel: 'TV browse featured');
  final Map<String, TvContentRowController> _rowControllers =
      <String, TvContentRowController>{};
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final GlobalKey _columnKey = GlobalKey();

  /// Only the spotlight and backdrop follow each card, so moving along a row
  /// does not rebuild every row. A shortcut tile changes the spotlight and
  /// leaves the backdrop on the last title.
  late final ValueNotifier<TvSpotlightData> _spotlight =
      ValueNotifier<TvSpotlightData>(_featuredSpotlight);
  late final ValueNotifier<TvMediaItem> _backdrop =
      ValueNotifier<TvMediaItem>(widget.featured);

  TvSpotlightData get _featuredSpotlight => TvSpotlightData.forItem(
        widget.featured,
        featured: widget.showBillboard,
      );

  void _showItem(TvMediaItem item) {
    _spotlight.value = TvSpotlightData.forItem(item);
    _backdrop.value = item;
  }

  String? _badgeFor(TvMediaItem item) =>
      widget.badgeFor?.call(item) ?? TvMediaBadge.recencyOf(item);

  /// How many cards past the focused one have their logo looked up ahead of
  /// time, so moving along a row finds logos ready rather than swapping text
  /// for artwork a moment after each move.
  static const _logoLookahead = 3;

  TvTitleLogos? _logos;
  Timer? _logoPrefetch;

  void _prefetchLogos(List<TvMediaItem> items, TvMediaItem focused) {
    final logos = _logos;
    if (logos == null) return;
    _logoPrefetch?.cancel();
    _logoPrefetch = Timer(const Duration(milliseconds: 400), () {
      final index = items.indexOf(focused);
      for (final item in items.skip(index + 1).take(_logoLookahead)) {
        logos.resolve(item);
      }
    });
  }

  void _showShortcut(TvBrowseShortcut shortcut) {
    _spotlight.value = TvSpotlightData(
      id: 'shortcut:${shortcut.id}',
      title: shortcut.title,
      facts: shortcut.facts,
      overview: shortcut.description,
    );
  }

  /// The row holding focus, or null on the billboard.
  String? _focusedRowId;
  double _focusedRowTop = 0;
  double _focusedRowExtent = 0;

  List<TvBrowseRow> get _rows =>
      widget.rows.where((row) => !row.isEmpty).toList(growable: false);

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _requestEntryFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logos = TvTitleLogoScope.maybeOf(context);
    if (identical(logos, _logos)) return;
    _logos = logos;
    // The billboard's own lookup starts with it; the first row's opening
    // cards are where Down lands.
    final first = _rows.firstOrNull;
    final opening = switch (first) {
      TvMediaRow(:final items) || TvTopTenRow(:final items) => items,
      _ => const <TvMediaItem>[],
    };
    for (final item in opening.take(_logoLookahead)) {
      logos?.resolve(item);
    }
  }

  @override
  void didUpdateWidget(TvBrowseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _requestEntryFocus);
    }
    // Rows gone for good leave their controllers and keys behind otherwise;
    // Search replaces its rows with every query.
    final scopeIds = widget.rows.map((row) => row.scopeId).toSet();
    _rowControllers.removeWhere((id, _) => !scopeIds.contains(id));
    _rowKeys.removeWhere((id, _) => !scopeIds.contains(id));

    if (_focusedRowId == null) {
      _spotlight.value = _featuredSpotlight;
      _backdrop.value = widget.featured;
    }

    final focusedRowId = _focusedRowId;
    if (focusedRowId == null) return;
    if (!_rows.any((row) => row.scopeId == focusedRowId)) {
      _recoverFromRemovedRow(
        oldWidget.rows
            .where((row) => !row.isEmpty)
            .toList(growable: false)
            .indexWhere((row) => row.scopeId == focusedRowId),
      );
      return;
    }
    // A row can appear or grow above the focused one (Continue watching after
    // playback), which moves it within the column; follow it once laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusedRowId == focusedRowId) {
        _handleRowFocused(focusedRowId);
      }
    });
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _logoPrefetch?.cancel();
    _featuredFocus.dispose();
    _spotlight.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  /// The focused row emptied out (its last card was removed) and took focus
  /// with it, so hand the remote the row that moved into its place.
  void _recoverFromRemovedRow(int removedIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focused = FocusManager.instance.primaryFocus;
      if (focused != null && focused is! FocusScopeNode) {
        // Focus is elsewhere (Search's keyboard): start the new rows afresh.
        if (_focusedRowId != null &&
            !_rows.any((r) => r.scopeId == _focusedRowId)) {
          setState(() => _focusedRowId = null);
          _spotlight.value = _featuredSpotlight;
          _backdrop.value = widget.featured;
        }
        return;
      }
      final rows = _rows;
      if (rows.isEmpty || removedIndex < 0) {
        if (widget.showBillboard) _featuredFocus.requestFocus();
        return;
      }
      _focusRow(rows[removedIndex.clamp(0, rows.length - 1)].scopeId);
    });
  }

  bool _requestEntryFocus() {
    final rowId =
        TvFocusMemoryScope.maybeOf(context)?.recall(widget.focusMemoryScope);
    if (rowId != null && _focusRow(rowId)) return true;
    if (!widget.showBillboard) {
      final first = _rows.firstOrNull;
      return first != null && _focusRow(first.scopeId);
    }
    if (_featuredFocus.context == null) return false;
    _featuredFocus.requestFocus();
    return true;
  }

  bool _focusRow(String scopeId) =>
      _rowControllers[scopeId]?.requestFocus() ?? false;

  void _handleFeaturedFocused() {
    TvFocusMemoryScope.maybeOf(context)?.forget(widget.focusMemoryScope);
    _spotlight.value = _featuredSpotlight;
    _backdrop.value = widget.featured;
    if (_focusedRowId != null) setState(() => _focusedRowId = null);
  }

  void _handleRowFocused(String scopeId) {
    TvFocusMemoryScope.maybeOf(context)
        ?.remember(scopeId: widget.focusMemoryScope, itemId: scopeId);
    // Measured in the column's own coordinates, which the slide does not move.
    final column = _columnKey.currentContext?.findRenderObject();
    final row = _rowKeys[scopeId]?.currentContext?.findRenderObject();
    var top = _focusedRowTop;
    var extent = _focusedRowExtent;
    if (column is RenderBox && row is RenderBox && row.hasSize) {
      top = row.localToGlobal(Offset.zero, ancestor: column).dy;
      extent = row.size.height;
    }
    if (_focusedRowId == scopeId &&
        top == _focusedRowTop &&
        extent == _focusedRowExtent) {
      return;
    }
    setState(() {
      _focusedRowId = scopeId;
      _focusedRowTop = top;
      _focusedRowExtent = extent;
    });
  }

  /// Rows are stepped explicitly rather than by geometry, so each row returns
  /// to the card it was left on, the way Netflix rows do.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final rows = _rows;
    if (_featuredFocus.hasFocus) {
      if (key == LogicalKeyboardKey.arrowDown && rows.isNotEmpty) {
        _focusRow(rows.first.scopeId);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final index = rows.indexWhere((row) => row.scopeId == _focusedRowId);
    if (index < 0) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (index + 1 < rows.length) _focusRow(rows[index + 1].scopeId);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (index > 0) {
        _focusRow(rows[index - 1].scopeId);
      } else if (widget.showBillboard) {
        _featuredFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (widget.showBillboard &&
        _backKeys.contains(key) &&
        event is KeyDownEvent) {
      _featuredFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.metrics.compact;
    final insets = TvShellInsets.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final innerHeight = height - insets.vertical;
        final rows = _rows;
        final focusedIndex =
            rows.indexWhere((row) => row.scopeId == _focusedRowId);
        // Without a billboard the page is always laid out for browsing.
        final browsing = focusedIndex >= 0 || !widget.showBillboard;
        final rowsTop = insets.top +
            (browsing
                ? (innerHeight - _focusedRowExtent * (1 + _nextRowPeek))
                    .clamp(innerHeight * 0.3, innerHeight * 0.5)
                : innerHeight * _billboardRowsTop);
        final rowsShift = rowsTop - (focusedIndex >= 0 ? _focusedRowTop : 0);

        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _handleKey,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ValueListenableBuilder<TvMediaItem>(
                  valueListenable: _backdrop,
                  builder: (_, item, __) => TvBackdrop(item: item),
                ),
                AnimatedPositioned(
                  duration: _motion,
                  curve: Curves.easeOutCubic,
                  left: insets.left + TvDesign.focusOutset + 4 - _focusRingRoom,
                  top: insets.top + widget.metrics.contentPadding,
                  width: ((constraints.maxWidth - insets.horizontal) * 0.46)
                      .clamp(0.0, compact ? 430.0 : 580.0),
                  bottom:
                      height - rowsTop + (compact ? 10 : 16) - _focusRingRoom,
                  child: _buildSpotlight(browsing: browsing),
                ),
                // Rows run to the trailing edge; only their leading edge is cut,
                // where pinned rows scroll earlier cards away under the rail.
                Positioned(
                  left: insets.left,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    clipper: const TvLeadingEdgeClipper(),
                    child: _buildRows(
                      rows: rows,
                      focusedIndex: focusedIndex,
                      shift: rowsShift,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpotlight({required bool browsing}) {
    final compact = widget.metrics.compact;
    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.only(
          left: _focusRingRoom,
          bottom: _focusRingRoom,
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ValueListenableBuilder<TvSpotlightData>(
                valueListenable: _spotlight,
                builder: (_, data, __) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.bottomLeft,
                    children: <Widget>[
                      ...previous,
                      if (current != null) current
                    ],
                  ),
                  child: TvSpotlightInfo(
                    key: ValueKey<String>('${data.id}|$browsing'),
                    data: data,
                    featured: !browsing,
                    compact: compact,
                  ),
                ),
              ),
              // Stays mounted while browsing so Up and Back can focus it; it is
              // only folded away.
              if (widget.showBillboard)
                FocusTraversalGroup(
                  policy: _BillboardTraversalPolicy(),
                  // Faded rather than clipped, so nothing cuts the focus ring.
                  child: AnimatedOpacity(
                    duration: _motion,
                    opacity: browsing ? 0 : 1,
                    child: AnimatedAlign(
                      duration: _motion,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topLeft,
                      heightFactor: browsing ? 0 : 1,
                      child: Padding(
                        padding: EdgeInsets.only(top: compact ? 12 : 16),
                        child: _MoreInfoButton(
                          focusNode: _featuredFocus,
                          title: widget.featured.title,
                          onFocused: _handleFeaturedFocused,
                          onActivate: () => widget.onOpenMedia(widget.featured),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRows({
    required List<TvBrowseRow> rows,
    required int focusedIndex,
    required double shift,
  }) {
    final rowGap = widget.metrics.compact ? 16.0 : 24.0;
    // Every row stays mounted so any of them can take focus, and the column
    // is slid rather than scrolled so focus never drags a scrollable along.
    return OverflowBox(
      alignment: Alignment.topLeft,
      minHeight: 0,
      maxHeight: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: shift),
        duration: _motion,
        curve: Curves.easeOutCubic,
        builder: (_, dy, child) =>
            Transform.translate(offset: Offset(0, dy), child: child),
        child: Column(
          key: _columnKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < rows.length; index++)
              _buildRow(
                rows[index],
                // Rows scrolled past would sit under the spotlight text.
                visible: index >= focusedIndex,
                // Browsing, the rows below step back behind the focused one.
                dimmed: focusedIndex >= 0 && index > focusedIndex,
                bottomGap: rowGap,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    TvBrowseRow row, {
    required bool visible,
    required bool dimmed,
    required double bottomGap,
  }) {
    return AnimatedOpacity(
      key: _rowKeys.putIfAbsent(row.scopeId, GlobalKey.new),
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomGap),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (hasFocus) {
            if (hasFocus) _handleRowFocused(row.scopeId);
          },
          child: switch (row) {
            TvMediaRow() => _buildMediaRow(row, dimmed: dimmed),
            TvTopTenRow() => _buildTopTenRow(row, dimmed: dimmed),
            TvShortcutRow() => _buildShortcutRow(row, dimmed: dimmed),
          },
        ),
      ),
    );
  }

  TvContentRowController _controllerFor(TvBrowseRow row) =>
      _rowControllers.putIfAbsent(row.scopeId, TvContentRowController.new);

  Widget _buildMediaRow(TvMediaRow row, {required bool dimmed}) {
    return TvContentRow<TvMediaItem>(
      controller: _controllerFor(row),
      title: row.title,
      scopeId: row.scopeId,
      items: row.items,
      itemId: (item) => item.stableId,
      semanticLabel: (item) => item.title,
      // The spotlight names the focused card, so cards are artwork only.
      itemBuilder: (_, item) => TvMediaCard(
        item: item,
        width: widget.metrics.mediaCardWidth,
        artworkOnly: true,
        dimmed: dimmed,
        badge: row.showBadges ? _badgeFor(item) : null,
      ),
      itemSpacing: _cardSpacing,
      itemFocusScale: _cardFocusScale,
      onItemActivated: row.onItemActivated ?? widget.onOpenMedia,
      onItemFocused: (item) {
        _showItem(item);
        _prefetchLogos(row.items, item);
      },
      onItemMenu: row.onItemMenu,
      itemMenuHint: row.itemMenuHint,
      pinFocusedItem: true,
    );
  }

  Widget _buildTopTenRow(TvTopTenRow row, {required bool dimmed}) {
    final width = widget.metrics.mediaCardWidth;
    return TvContentRow<TvMediaItem>(
      controller: _controllerFor(row),
      title: row.title,
      scopeId: row.scopeId,
      items: row.items,
      itemId: (item) => item.stableId,
      semanticLabel: (item) =>
          'Number ${row.items.indexOf(item) + 1}, ${item.title}',
      // The rank already says it; a Top 10 badge here would repeat it.
      itemBuilder: (_, item) => TvMediaCard(
        item: item,
        width: width,
        artworkOnly: true,
        dimmed: dimmed,
      ),
      itemLeadingBuilder: (_, item, index) => TvTopTenRank(
        rank: index + 1,
        cardWidth: width,
        // The poster plus the focus padding around it in the row.
        height: width / TvMediaCard.artworkAspectRatio + 8,
        bottomInset: 4,
        dimmed: dimmed,
      ),
      itemSpacing: _cardSpacing,
      itemFocusScale: _cardFocusScale,
      onItemActivated: widget.onOpenMedia,
      onItemFocused: (item) {
        _showItem(item);
        _prefetchLogos(row.items, item);
      },
      pinFocusedItem: true,
    );
  }

  Widget _buildShortcutRow(TvShortcutRow row, {required bool dimmed}) {
    // Wider than a poster: a landscape tile of roughly the same area.
    final width = widget.metrics.mediaCardWidth * 1.45;
    return TvContentRow<TvBrowseShortcut>(
      controller: _controllerFor(row),
      title: row.title,
      scopeId: row.scopeId,
      items: row.shortcuts,
      itemId: (shortcut) => shortcut.id,
      semanticLabel: (shortcut) => shortcut.title,
      itemBuilder: (_, shortcut) => TvShortcutTile(
        shortcut: shortcut,
        width: width,
        tint: row.shortcuts.indexOf(shortcut),
        dimmed: dimmed,
      ),
      itemSpacing: _cardSpacing,
      itemFocusScale: _cardFocusScale,
      onItemActivated: (shortcut) => shortcut.onActivate(),
      onItemMenu: row.onShortcutMenu,
      itemMenuHint: row.menuHint,
      onItemFocused: _showShortcut,
      pinFocusedItem: true,
    );
  }
}

class _MoreInfoButton extends StatelessWidget {
  const _MoreInfoButton({
    required this.focusNode,
    required this.title,
    required this.onFocused,
    required this.onActivate,
  });

  final FocusNode focusNode;
  final String title;
  final VoidCallback onFocused;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      semanticLabel: 'More information about $title',
      onFocusChanged: (hasFocus) {
        if (hasFocus) onFocused();
      },
      onActivate: onActivate,
      focusScale: 1.035,
      borderRadius: BorderRadius.circular(5),
      scrollAlignment: null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xf2ffffff),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PhosphorIcons.info(), color: Colors.black, size: 19),
            const SizedBox(width: 8),
            const Text(
              'More info',
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'FigtreeSB',
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Down from the billboard is the view's to route; Left and Right have nothing
/// beside the button, and searching for something would find cards scrolled
/// off the rows' leading edge rather than the rail. Up still reaches whatever
/// sits above the view.
class _BillboardTraversalPolicy extends ReadingOrderTraversalPolicy {
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (direction != TraversalDirection.up) return false;
    return super.inDirection(currentNode, direction);
  }
}
