import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/playback_action.dart';

import '../focus/tv_focus_memory.dart';
import '../focus/tv_focusable.dart';
import '../app/tv_design.dart';

typedef TvContentItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
);

typedef TvContentItemLeadingBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

class TvContentRow<T> extends StatefulWidget {
  const TvContentRow({
    required this.title,
    required this.scopeId,
    required this.items,
    required this.itemId,
    required this.semanticLabel,
    required this.itemBuilder,
    required this.onItemActivated,
    this.onItemMenu,
    this.itemMenuHint,
    this.onItemFocused,
    this.itemLeadingBuilder,
    this.pinFocusedItem = false,
    this.autofocus = false,
    this.itemSpacing = 14,
    this.itemFocusScale = 1.04,
    this.itemFocusRadius = TvDesign.cardRadius + 2,
    this.controller,
    super.key,
  });

  final String title;
  final String scopeId;
  final List<T> items;
  final String Function(T item) itemId;
  final String Function(T item) semanticLabel;
  final TvContentItemBuilder<T> itemBuilder;
  final FutureOr<void> Function(T item) onItemActivated;

  /// Secondary action for an item, reached by holding OK or by the remote's menu
  /// key. A remote has no room for an on-card button the way touch does, so the
  /// hold is the row's stand-in for a long press.
  final ValueChanged<T>? onItemMenu;

  /// Spelled out next to the title while the row has focus, because a hold is
  /// invisible until someone is told about it. Ignored without [onItemMenu].
  final String? itemMenuHint;

  final ValueChanged<T>? onItemFocused;

  /// Draws something ahead of each item that is not part of it and takes no
  /// focus, such as a Top 10 rank. A pinned row lines this up with the leading
  /// edge instead of the item.
  final TvContentItemLeadingBuilder<T>? itemLeadingBuilder;

  /// Scrolls the focused item to the row's leading edge, the way Netflix rows
  /// move, instead of only keeping it in view. The row then owns its scrolling
  /// and leaves any vertical scrollable around it alone.
  final bool pinFocusedItem;

  final bool autofocus;
  final double itemSpacing;

  /// How much the focused item grows. A pinned row grows it from its leading
  /// edge, so the item stays lined up with the row title.
  final double itemFocusScale;

  /// Corner radius of the focus outline around each item.
  final double itemFocusRadius;
  final TvContentRowController? controller;

  @override
  State<TvContentRow<T>> createState() => _TvContentRowState<T>();
}

class TvContentRowController {
  _TvContentRowState<dynamic>? _state;

  /// Focuses [itemId] when the row has it, else the remembered item or the
  /// first one, and returns whether focus moved.
  bool requestFocus([String? itemId]) =>
      _state?._focusPreferredItem(itemId) ?? false;
}

class _TvContentRowState<T> extends State<TvContentRow<T>> {
  /// Matches Android's long-press timeout, so a deliberate press still resumes
  /// playback instead of tripping the secondary action.
  static const _holdDuration = Duration(milliseconds: 500);

  static const _itemFocusPadding = 4.0;

  /// Lines the title up with the artwork rather than the focus ring around it.
  static const _titleInset = TvDesign.focusOutset + _itemFocusPadding;

  static const _activationKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  ];

  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  final Map<String, GlobalKey> _leadingKeys = <String, GlobalKey>{};
  final ScrollController _scrollController = ScrollController();
  late final _pinnedPolicy = _PinnedRowTraversalPolicy(_stepFrom);
  final GlobalKey _trackKey = GlobalKey();
  bool _scheduledInitialFocus = false;
  bool _rowHasFocus = false;
  Timer? _holdTimer;
  String? _holdItemId;
  bool _holdReached = false;
  String? _startingItemId;

  Future<void> _activateItem(T item) async {
    if (_startingItemId != null) return;
    await PlaybackAction.run(context, () async {
      setState(() => _startingItemId = widget.itemId(item));
      try {
        await widget.onItemActivated(item);
      } finally {
        if (mounted) setState(() => _startingItemId = null);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
    widget.controller?._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleInitialFocus();
  }

  @override
  void didUpdateWidget(TvContentRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      if (identical(oldWidget.controller?._state, this)) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    if (oldWidget.scopeId != widget.scopeId) {
      _cancelHold();
      for (final node in _focusNodes.values) {
        node.dispose();
      }
      _focusNodes.clear();
      _syncFocusNodes();
      _scheduledInitialFocus = false;
      _scheduleInitialFocus();
      return;
    }

    // Note the focused id before the sync disposes it: an item can leave the
    // row while it holds focus (a removal), and dropping focus on the floor
    // leaves the remote with nothing to steer.
    final focusedId = _focusedItemId();
    _syncFocusNodes();
    if (focusedId != null && !_focusNodes.containsKey(focusedId)) {
      _cancelHold();
      final oldIds =
          oldWidget.items.map(oldWidget.itemId).toList(growable: false);
      _restoreFocusNear(oldIds.indexOf(focusedId));
    }
    if (oldWidget.autofocus != widget.autofocus) {
      _scheduledInitialFocus = false;
      _scheduleInitialFocus();
    }
  }

  void _syncFocusNodes() {
    final ids = widget.items.map(widget.itemId).toList(growable: false);
    assert(ids.toSet().length == ids.length,
        'TV content row item IDs must be unique within a row.');
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      _focusNodes.putIfAbsent(
        id,
        () => FocusNode(
          debugLabel: '${widget.scopeId}:$id',
          // Sits on the row's own node, which makes it the leaf handler: it
          // runs before TvFocusable's ActivateIntent shortcut, so OK can be
          // held back until the key is released.
          onKeyEvent: (node, event) => _handleItemKey(id, event),
        ),
      );
    }
    final currentIds = ids.toSet();
    final removedIds =
        _focusNodes.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in removedIds) {
      _focusNodes.remove(id)?.dispose();
      _leadingKeys.remove(id);
    }
  }

  String? _focusedItemId() {
    for (final entry in _focusNodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return null;
  }

  T? _itemForId(String id) {
    for (final item in widget.items) {
      if (widget.itemId(item) == id) return item;
    }
    return null;
  }

  void _restoreFocusNear(int removedIndex) {
    final ids = widget.items.map(widget.itemId).toList(growable: false);
    if (ids.isEmpty) return;
    final targetIndex = removedIndex.clamp(0, ids.length - 1);
    final node = _focusNodes[ids[targetIndex]];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || node == null) return;
      if (node.context != null && node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  void _scheduleInitialFocus() {
    if (_scheduledInitialFocus || widget.items.isEmpty) {
      return;
    }
    // Only an explicit autofocus takes focus on mount; see TvContentGrid.
    if (!widget.autofocus) {
      return;
    }
    final memory = TvFocusMemoryScope.maybeOf(context);
    final rememberedId = memory?.recall(widget.scopeId);
    _scheduledInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final firstId = widget.itemId(widget.items.first);
      final targetNode = _focusNodes[rememberedId] ?? _focusNodes[firstId];
      targetNode?.requestFocus();
    });
  }

  bool _focusPreferredItem([String? itemId]) {
    if (widget.items.isEmpty) return false;
    final rememberedId =
        TvFocusMemoryScope.maybeOf(context)?.recall(widget.scopeId);
    final node = _focusNodes[itemId] ??
        _focusNodes[rememberedId] ??
        _focusNodes[widget.itemId(widget.items.first)];
    if (node == null || node.context == null || !node.canRequestFocus) {
      return false;
    }
    node.requestFocus();
    return true;
  }

  @override
  void dispose() {
    if (identical(widget.controller?._state, this)) {
      widget.controller?._state = null;
    }
    _cancelHold();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleItemKey(String id, KeyEvent event) {
    if (widget.onItemMenu == null) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.contextMenu) {
      if (event is KeyDownEvent) {
        _cancelHold();
        _openMenu(id);
      }
      return KeyEventResult.handled;
    }

    if (!_activationKeys.contains(key)) {
      // A D-pad move (or anything else) abandons a hold in progress.
      _cancelHold();
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      _startHold(id);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) {
      // Remotes report a held OK as repeats; the timer already tracks it, and
      // swallowing them keeps the repeats from activating the item.
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      // A release whose press this card never saw (OK held down while the D-pad
      // moved focus) must not act on the card it lands on.
      if (_holdItemId != id) return KeyEventResult.ignored;
      final reached = _holdReached;
      _cancelHold();
      // Acting on release rather than at the timer keeps the still-held key
      // from leaking repeats into whatever the menu opens.
      if (reached) {
        _openMenu(id);
      } else {
        final item = _itemForId(id);
        if (item != null) unawaited(_activateItem(item));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openMenu(String id) {
    final item = _itemForId(id);
    if (item != null) widget.onItemMenu?.call(item);
  }

  void _startHold(String id) {
    _cancelHold();
    _holdItemId = id;
    _holdTimer = Timer(_holdDuration, () {
      _holdTimer = null;
      _holdReached = true;
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdItemId = null;
    _holdReached = false;
  }

  /// Moves focus [delta] items along from [node], or reports that the row
  /// ends there.
  bool _stepFrom(FocusNode node, int delta) {
    final ids = widget.items.map(widget.itemId).toList(growable: false);
    final index = ids.indexWhere((id) => identical(_focusNodes[id], node));
    final target = index + delta;
    if (index < 0 || target < 0 || target >= ids.length) return false;
    final targetNode = _focusNodes[ids[target]];
    if (targetNode == null || targetNode.context == null) return false;
    targetNode.requestFocus();
    return true;
  }

  void _pinItem(String id) {
    final itemBox =
        (_leadingKeys[id]?.currentContext ?? _focusNodes[id]?.context)
            ?.findRenderObject();
    final trackBox = _trackKey.currentContext?.findRenderObject();
    if (itemBox is! RenderBox ||
        trackBox is! RenderBox ||
        !_scrollController.hasClients) {
      return;
    }
    // The track's leading padding already clears the focus ring, so an item's
    // offset along the track is the scroll that puts it at the leading edge.
    final position = _scrollController.position;
    final target = itemBox
        .localToGlobal(Offset.zero, ancestor: trackBox)
        .dx
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return;
    unawaited(_scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    ));
  }

  void _handleItemFocusChanged({required String id, required bool hasFocus}) {
    if (!hasFocus && _holdItemId == id) _cancelHold();
    final rowHasFocus = _focusNodes.values.any((node) => node.hasFocus);
    if (_rowHasFocus != rowHasFocus && mounted) {
      setState(() => _rowHasFocus = rowHasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final memory = TvFocusMemoryScope.maybeOf(context);
    final onItemMenu = widget.onItemMenu;
    final hint = onItemMenu == null ? null : widget.itemMenuHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const SizedBox(width: _titleInset),
            Flexible(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: palette.foreground,
                  fontFamily: 'FigtreeSB',
                  fontSize: 21,
                  letterSpacing: -0.15,
                ),
              ),
            ),
            if (hint != null)
              Expanded(
                child: AnimatedOpacity(
                  opacity: _rowHasFocus ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontFamily: 'Figtree',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        FocusTraversalGroup(
          policy: widget.pinFocusedItem
              ? _pinnedPolicy
              : ReadingOrderTraversalPolicy(),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            // A pinned row scrolls earlier items clear of its leading edge, so
            // it can leave the grown focused item and its shadow unclipped.
            clipBehavior: widget.pinFocusedItem ? Clip.none : Clip.hardEdge,
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: TvDesign.focusOutset,
            ),
            child: Row(
              key: _trackKey,
              children: <Widget>[
                for (var index = 0; index < widget.items.length; index++) ...[
                  if (widget.itemLeadingBuilder case final leading?)
                    KeyedSubtree(
                      key: _leadingKeys.putIfAbsent(
                        widget.itemId(widget.items[index]),
                        GlobalKey.new,
                      ),
                      child: leading(context, widget.items[index], index),
                    ),
                  Builder(
                    builder: (context) {
                      final item = widget.items[index];
                      final id = widget.itemId(item);
                      return TvFocusable(
                        key: ValueKey<String>('${widget.scopeId}:$id'),
                        focusNode: _focusNodes[id],
                        semanticLabel: widget.semanticLabel(item),
                        onFocusChanged: (hasFocus) {
                          if (hasFocus) {
                            memory?.remember(
                              scopeId: widget.scopeId,
                              itemId: id,
                            );
                            widget.onItemFocused?.call(item);
                            if (widget.pinFocusedItem) _pinItem(id);
                          }
                          _handleItemFocusChanged(id: id, hasFocus: hasFocus);
                        },
                        onActivate: () => unawaited(_activateItem(item)),
                        onLongPress:
                            onItemMenu == null ? null : () => onItemMenu(item),
                        padding: const EdgeInsets.all(_itemFocusPadding),
                        scrollAlignment: widget.pinFocusedItem ? null : 0.6,
                        focusScale: widget.itemFocusScale,
                        focusAlignment: widget.pinFocusedItem
                            ? Alignment.centerLeft
                            : Alignment.center,
                        borderRadius: BorderRadius.circular(
                          widget.itemFocusRadius,
                        ),
                        child: Stack(
                          children: <Widget>[
                            widget.itemBuilder(context, item),
                            if (_startingItemId == id)
                              const Positioned.fill(
                                child: ColoredBox(
                                  color: Color(0x66000000),
                                  child: Center(
                                    child: SizedBox.square(
                                      dimension: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (index != widget.items.length - 1)
                    SizedBox(width: widget.itemSpacing),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps Left and Right on a pinned row's own cards.
///
/// A pinned row scrolls earlier cards off past its leading edge, where
/// geometric traversal would find them, or another row's, before the rail.
/// Off either end there is no move, so Left from the first card reaches
/// whatever the row's parent does with an unhandled Left.
class _PinnedRowTraversalPolicy extends ReadingOrderTraversalPolicy {
  _PinnedRowTraversalPolicy(this._step);

  final bool Function(FocusNode node, int delta) _step;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    return switch (direction) {
      TraversalDirection.left => _step(currentNode, -1),
      TraversalDirection.right => _step(currentNode, 1),
      _ => super.inDirection(currentNode, direction),
    };
  }
}

/// Clips only the leading edge, where a pinned row scrolls earlier items
/// away, and leaves the focused item's growth and shadow free to spill past
/// the other three.
class TvLeadingEdgeClipper extends CustomClipper<Rect> {
  const TvLeadingEdgeClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -size.height, size.width * 2, size.height * 2);

  @override
  bool shouldReclip(TvLeadingEdgeClipper oldClipper) => false;
}
