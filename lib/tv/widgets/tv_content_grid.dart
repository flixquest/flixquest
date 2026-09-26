import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tv_design.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_focusable.dart';

typedef TvGridItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  double itemWidth,
);

class TvContentGrid<T> extends StatefulWidget {
  const TvContentGrid({
    required this.scopeId,
    required this.items,
    required this.itemId,
    required this.semanticLabel,
    required this.itemBuilder,
    required this.onItemActivated,
    required this.targetItemWidth,
    this.autofocus = false,
    this.itemExtent,
    this.itemAspectRatio = 16 / 9,
    this.itemDetailsExtent = 60,
    this.onItemMenu,
    this.onItemFocused,
    this.controller,
    this.padding = const EdgeInsets.all(TvDesign.focusOutset),
    this.horizontalSpacing = 22,
    this.verticalSpacing = 24,
    super.key,
  });

  final String scopeId;
  final List<T> items;
  final String Function(T item) itemId;
  final String Function(T item) semanticLabel;
  final TvGridItemBuilder<T> itemBuilder;
  final ValueChanged<T> onItemActivated;
  final double targetItemWidth;
  final bool autofocus;
  final double? itemExtent;
  final double itemAspectRatio;
  final double itemDetailsExtent;
  final ValueChanged<T>? onItemMenu;

  /// Called as each item takes focus, e.g. to load more before the end.
  final ValueChanged<T>? onItemFocused;
  final TvContentGridController? controller;
  final EdgeInsets padding;
  final double horizontalSpacing;
  final double verticalSpacing;

  @override
  State<TvContentGrid<T>> createState() => _TvContentGridState<T>();
}

class TvContentGridController {
  _TvContentGridState<dynamic>? _state;
  bool _pendingRequest = false;
  FocusNode? _pendingOrigin;

  /// Focuses the remembered item, or the first one, and returns whether focus
  /// moved. A grid that is not mounted yet (its screen is still loading) takes
  /// the request once it is, unless focus has moved on in the meantime.
  bool requestFocus() {
    final state = _state;
    if (state == null) {
      _pendingRequest = true;
      _pendingOrigin = FocusManager.instance.primaryFocus;
      return false;
    }
    return state._focusPreferredItem();
  }

  void _attach(_TvContentGridState<dynamic> state) {
    _state = state;
    if (!_pendingRequest) return;
    _pendingRequest = false;
    final origin = _pendingOrigin;
    _pendingOrigin = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!identical(_state, state) || !state.mounted) return;
      final focused = FocusManager.instance.primaryFocus;
      // A scope means nothing concrete holds focus, so there is nothing to
      // take it away from.
      if (focused != origin && focused is! FocusScopeNode) return;
      state._focusPreferredItem();
    });
  }

  void _detach(_TvContentGridState<dynamic> state) {
    if (identical(_state, state)) _state = null;
  }
}

class _TvContentGridState<T> extends State<TvContentGrid<T>> {
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  final ScrollController _scrollController = ScrollController();
  bool _scheduledInitialFocus = false;
  int _columnCount = 1;
  double _itemHeight = 126;
  Timer? _holdTimer;
  bool _holdReached = false;
  String? _heldId;

  KeyEventResult _handleActivation(String id, KeyEvent event) {
    if (widget.onItemMenu == null) return KeyEventResult.ignored;
    if (![
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.gameButtonA
    ].contains(event.logicalKey)) {
      _heldId = null;
      _holdTimer?.cancel();
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _heldId = id;
      _holdTimer?.cancel();
      _holdReached = false;
      _holdTimer =
          Timer(const Duration(milliseconds: 500), () => _holdReached = true);
    } else if (event is KeyUpEvent && _heldId == id) {
      _holdTimer?.cancel();
      _heldId = null;
      final item = widget.items.firstWhere((item) => widget.itemId(item) == id);
      if (_holdReached) {
        widget.onItemMenu!(item);
      } else {
        widget.onItemActivated(item);
      }
    }
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
    widget.controller?._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleInitialFocus();
  }

  @override
  void didUpdateWidget(TvContentGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.scopeId != widget.scopeId) {
      for (final node in _focusNodes.values) {
        node.dispose();
      }
      _focusNodes.clear();
      _scheduledInitialFocus = false;
    }
    _syncFocusNodes();
    _scheduleInitialFocus();
  }

  void _syncFocusNodes() {
    final ids = widget.items.map(widget.itemId).toList(growable: false);
    assert(
      ids.toSet().length == ids.length,
      'TV content grid item IDs must be unique.',
    );
    for (final id in ids) {
      _focusNodes.putIfAbsent(
        id,
        () => FocusNode(
            debugLabel: '${widget.scopeId}:$id',
            onKeyEvent: (_, event) => _handleActivation(id, event)),
      );
    }
    final activeIds = ids.toSet();
    final removed =
        _focusNodes.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in removed) {
      _focusNodes.remove(id)?.dispose();
    }
  }

  // Only an explicit autofocus takes focus on mount. A remembered item is
  // restored when the user enters the grid, never by mounting it: that pulled
  // focus off the rail whenever a destination was selected.
  void _scheduleInitialFocus() {
    if (_scheduledInitialFocus || widget.items.isEmpty) return;
    if (!widget.autofocus) return;
    _scheduledInitialFocus = true;
    _requestPreferredFocus();
  }

  void _requestPreferredFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusPreferredItem();
    });
  }

  /// Returns whether focus moved, or is on its way once the grid scrolls the
  /// item into view.
  bool _focusPreferredItem() {
    if (widget.items.isEmpty) return false;
    final memory = TvFocusMemoryScope.maybeOf(context);
    final rememberedId = memory?.recall(widget.scopeId);
    final index =
        widget.items.indexWhere((item) => widget.itemId(item) == rememberedId);
    return _revealAndFocus(
      targetIndex: index < 0 ? 0 : index,
      columnCount: _columnCount,
      itemHeight: _itemHeight,
    );
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _holdTimer?.cancel();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleGridKey({
    required KeyEvent event,
    required int index,
    required int columnCount,
    required double itemHeight,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    int? targetIndex;
    if (key == LogicalKeyboardKey.arrowUp && index >= columnCount) {
      targetIndex = index - columnCount;
    } else if (key == LogicalKeyboardKey.arrowDown &&
        index + columnCount < widget.items.length) {
      targetIndex = index + columnCount;
    } else if (key == LogicalKeyboardKey.arrowLeft && index % columnCount > 0) {
      targetIndex = index - 1;
    } else if (key == LogicalKeyboardKey.arrowRight &&
        index % columnCount < columnCount - 1 &&
        index + 1 < widget.items.length) {
      targetIndex = index + 1;
    }
    if (targetIndex == null) {
      if (key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.arrowDown) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    _revealAndFocus(
      targetIndex: targetIndex,
      itemHeight: itemHeight,
      columnCount: columnCount,
    );
    return KeyEventResult.handled;
  }

  /// Focuses the item now when it is built, otherwise scrolls it into view
  /// first. Returns false only when the grid has not been laid out yet.
  bool _revealAndFocus({
    required int targetIndex,
    required int columnCount,
    required double itemHeight,
  }) {
    final targetId = widget.itemId(widget.items[targetIndex]);
    final targetNode = _focusNodes[targetId];
    if (targetNode?.context != null) {
      targetNode?.requestFocus();
      return true;
    }
    if (!_scrollController.hasClients) return false;
    unawaited(_scrollToAndFocus(
      targetId: targetId,
      targetRow: targetIndex ~/ columnCount,
      itemHeight: itemHeight,
    ));
    return true;
  }

  Future<void> _scrollToAndFocus({
    required String targetId,
    required int targetRow,
    required double itemHeight,
  }) async {
    final desiredOffset = widget.padding.top +
        (targetRow * (itemHeight + widget.verticalSpacing)) -
        (itemHeight * 0.35);
    final position = _scrollController.position;
    await _scrollController.animateTo(
      desiredOffset.clamp(0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[targetId]?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final memory = TvFocusMemoryScope.maybeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth -
            widget.padding.horizontal +
            widget.horizontalSpacing;
        final columnCount =
            (usableWidth / (widget.targetItemWidth + widget.horizontalSpacing))
                .floor()
                .clamp(1, 8);
        final itemWidth =
            (usableWidth / columnCount) - widget.horizontalSpacing;
        const focusPadding = 6.0;
        final contentWidth = itemWidth - (focusPadding * 2);
        final itemHeight = widget.itemExtent ??
            (contentWidth / widget.itemAspectRatio) +
                widget.itemDetailsExtent +
                (focusPadding * 2);

        _columnCount = columnCount;
        _itemHeight = itemHeight;

        return FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: GridView.builder(
            controller: _scrollController,
            clipBehavior: Clip.hardEdge,
            padding: widget.padding,
            itemCount: widget.items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              crossAxisSpacing: widget.horizontalSpacing,
              mainAxisSpacing: widget.verticalSpacing,
              childAspectRatio: itemWidth / itemHeight,
            ),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final id = widget.itemId(item);
              return TvFocusable(
                key: ValueKey<String>('${widget.scopeId}:$id'),
                focusNode: _focusNodes[id],
                semanticLabel: widget.semanticLabel(item),
                onFocusChanged: (hasFocus) {
                  if (!hasFocus && _heldId == id) {
                    _heldId = null;
                    _holdTimer?.cancel();
                  }
                  if (hasFocus) {
                    memory?.remember(scopeId: widget.scopeId, itemId: id);
                    widget.onItemFocused?.call(item);
                  }
                },
                onActivate: () => widget.onItemActivated(item),
                borderRadius: BorderRadius.circular(TvDesign.cardRadius + 2),
                onLongPress: widget.onItemMenu == null
                    ? null
                    : () => widget.onItemMenu!(item),
                onKeyEvent: (_, event) {
                  if (event.logicalKey == LogicalKeyboardKey.contextMenu &&
                      widget.onItemMenu != null) {
                    if (event is KeyDownEvent) widget.onItemMenu!(item);
                    return KeyEventResult.handled;
                  }
                  return _handleGridKey(
                    event: event,
                    index: index,
                    columnCount: columnCount,
                    itemHeight: itemHeight,
                  );
                },
                padding: const EdgeInsets.all(focusPadding),
                child: widget.itemBuilder(context, item, contentWidth),
              );
            },
          ),
        );
      },
    );
  }
}
