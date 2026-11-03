import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef TvFocusListItemBuilder = Widget Function(
  BuildContext context,
  int index,
  FocusNode focusNode,
);

/// A column of rows of one height, steered with Up and Down.
///
/// Each row is built with its own focus node, and the list keeps the focused
/// row near its middle. Unlike directional traversal it reaches rows that
/// are not built yet, so a long list (every year, every country) can be
/// walked end to end, and it never wanders sideways off either end: Down on
/// the last row stays put, and Up on the first goes to [onExitUp] or stays.
/// Left and Right are left to whatever is around the list.
class TvFocusList extends StatefulWidget {
  const TvFocusList({
    required this.itemCount,
    required this.itemExtent,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onExitUp,
    this.padding = EdgeInsets.zero,
    this.debugLabel = 'TV focus list',
    super.key,
  });

  final int itemCount;
  final double itemExtent;
  final TvFocusListItemBuilder itemBuilder;

  /// The row [TvFocusListState.focus] lands on before any row has had focus.
  final int initialIndex;

  /// Up off the first row; returns whether focus left the list.
  final bool Function()? onExitUp;
  final EdgeInsets padding;
  final String debugLabel;

  @override
  State<TvFocusList> createState() => TvFocusListState();
}

class TvFocusListState extends State<TvFocusList> {
  final Map<int, FocusNode> _nodes = <int, FocusNode>{};
  final ScrollController _scrollController = ScrollController();
  late int _lastIndex = widget.initialIndex;

  bool get hasFocus => _nodes.values.any((node) => node.hasFocus);

  /// The row that has, or last had, focus.
  int get focusedIndex => _lastIndex;

  FocusNode _node(int index) => _nodes.putIfAbsent(
        index,
        () => FocusNode(debugLabel: '${widget.debugLabel} $index'),
      );

  /// Focuses row [index], or the one that last had focus, and returns
  /// whether focus moved or is on its way. A row out of view is scrolled
  /// to first; only a list not laid out yet returns false.
  bool focus([int? index]) {
    if (widget.itemCount == 0) return false;
    final target = (index ?? _lastIndex).clamp(0, widget.itemCount - 1);
    _lastIndex = target;
    final node = _nodes[target];
    if (node != null && node.context != null) {
      node.requestFocus();
      return true;
    }
    if (!_scrollController.hasClients) return false;
    // Jumping changes the scroll offset, which lays out a frame, so the
    // callback is sure to run.
    _scrollController.jumpTo(_offsetFor(target));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[target]?.requestFocus();
    });
    return true;
  }

  double _offsetFor(int index) {
    final position = _scrollController.position;
    final centred = widget.padding.top +
        index * widget.itemExtent -
        (position.viewportDimension - widget.itemExtent) / 2;
    return centred.clamp(0.0, position.maxScrollExtent);
  }

  void _reveal(int index) {
    if (!_scrollController.hasClients) return;
    final offset = _offsetFor(index);
    if ((offset - _scrollController.offset).abs() < 1) return;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (index + 1 < widget.itemCount) focus(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (index > 0) {
        focus(index - 1);
      } else {
        widget.onExitUp?.call();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(TvFocusList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount < oldWidget.itemCount) {
      final gone = _nodes.keys.where((index) => index >= widget.itemCount);
      for (final index in gone.toList()) {
        _nodes.remove(index)?.dispose();
      }
      if (_lastIndex >= widget.itemCount) {
        _lastIndex = widget.itemCount == 0 ? 0 : widget.itemCount - 1;
      }
    }
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemExtent: widget.itemExtent,
      itemCount: widget.itemCount,
      clipBehavior: Clip.hardEdge,
      itemBuilder: (context, index) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) => _handleKey(index, event),
        onFocusChange: (hasFocus) {
          if (!hasFocus) return;
          _lastIndex = index;
          _reveal(index);
        },
        child: widget.itemBuilder(context, index, _node(index)),
      ),
    );
  }
}
