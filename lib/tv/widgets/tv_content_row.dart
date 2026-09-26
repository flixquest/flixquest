import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../focus/tv_focus_memory.dart';
import '../focus/tv_focusable.dart';
import '../app/tv_design.dart';

typedef TvContentItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
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
    this.autofocus = false,
    this.itemSpacing = 14,
    super.key,
  });

  final String title;
  final String scopeId;
  final List<T> items;
  final String Function(T item) itemId;
  final String Function(T item) semanticLabel;
  final TvContentItemBuilder<T> itemBuilder;
  final ValueChanged<T> onItemActivated;

  /// Secondary action for an item, reached by holding OK or by the remote's menu
  /// key. A remote has no room for an on-card button the way touch does, so the
  /// hold is the row's stand-in for a long press.
  final ValueChanged<T>? onItemMenu;

  /// Spelled out next to the title while the row has focus, because a hold is
  /// invisible until someone is told about it. Ignored without [onItemMenu].
  final String? itemMenuHint;

  final bool autofocus;
  final double itemSpacing;

  @override
  State<TvContentRow<T>> createState() => _TvContentRowState<T>();
}

class _TvContentRowState<T> extends State<TvContentRow<T>> {
  /// Matches Android's long-press timeout, so a deliberate press still resumes
  /// playback instead of tripping the secondary action.
  static const _holdDuration = Duration(milliseconds: 500);

  static const _activationKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  ];

  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  bool _scheduledInitialFocus = false;
  bool _rowHasFocus = false;
  Timer? _holdTimer;
  String? _holdItemId;
  bool _holdReached = false;

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleInitialFocus();
  }

  @override
  void didUpdateWidget(TvContentRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final memory = TvFocusMemoryScope.maybeOf(context);
    final rememberedId = memory?.recall(widget.scopeId);
    if (!widget.autofocus && rememberedId == null) {
      return;
    }
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

  @override
  void dispose() {
    _cancelHold();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
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
        if (item != null) widget.onItemActivated(item);
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

  void _handleItemFocusChanged({required String id, required bool hasFocus}) {
    if (!hasFocus && _holdItemId == id) _cancelHold();
    final rowHasFocus = _focusNodes.values.any((node) => node.hasFocus);
    if (_rowHasFocus != rowHasFocus && mounted) {
      setState(() => _rowHasFocus = rowHasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = TvFocusMemoryScope.maybeOf(context);
    final colors = Theme.of(context).colorScheme;
    final onItemMenu = widget.onItemMenu;
    final hint = onItemMenu == null ? null : widget.itemMenuHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: colors.onSurface,
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
                        color: colors.onSurfaceVariant,
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
          policy: ReadingOrderTraversalPolicy(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: TvDesign.focusOutset,
            ),
            child: Row(
              children: <Widget>[
                for (var index = 0; index < widget.items.length; index++) ...[
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
                          }
                          _handleItemFocusChanged(id: id, hasFocus: hasFocus);
                        },
                        onActivate: () => widget.onItemActivated(item),
                        onLongPress:
                            onItemMenu == null ? null : () => onItemMenu(item),
                        padding: const EdgeInsets.all(4),
                        scrollAlignment: 0.6,
                        borderRadius: BorderRadius.circular(
                          TvDesign.cardRadius + 2,
                        ),
                        child: widget.itemBuilder(context, item),
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
