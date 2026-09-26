import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../focus/tv_screen_focus_controller.dart';
import '../widgets/tv_navigation_rail.dart';
import 'tv_design.dart';

typedef TvShellScreenBuilder = Widget Function(
  BuildContext context,
  String destinationId,
  TvScreenFocusController focusController,
);

/// The navigation rail beside the active destination's screen, and the D-pad
/// contract between them.
class TvShellLayout extends StatefulWidget {
  const TvShellLayout({
    required this.destinations,
    required this.selectedId,
    required this.metrics,
    required this.onDestinationSelected,
    required this.screenBuilder,
    super.key,
  });

  final List<TvNavigationDestination> destinations;
  final String selectedId;
  final TvShellMetrics metrics;
  final ValueChanged<String> onDestinationSelected;
  final TvShellScreenBuilder screenBuilder;

  @override
  State<TvShellLayout> createState() => TvShellLayoutState();
}

class TvShellLayoutState extends State<TvShellLayout> {
  final GlobalKey<TvNavigationRailState> _railKey =
      GlobalKey<TvNavigationRailState>();
  final Map<String, TvScreenFocusController> _focusControllers =
      <String, TvScreenFocusController>{};

  // Flutter's arrow-key traversal searches the whole focus scope, so the rail
  // and the screen beside it would otherwise leak into each other at their
  // edges. Whichever side does not hold focus is kept out of traversal.
  final FocusNode _railRegion = FocusNode(
    debugLabel: 'TV shell rail',
    canRequestFocus: false,
    skipTraversal: true,
  );
  late final FocusNode _contentRegion = FocusNode(
    debugLabel: 'TV shell content',
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _handleContentKey,
  );

  bool get railHasFocus => _railKey.currentState?.hasFocus == true;

  /// Focuses [destinationId] in the rail, or the selected destination.
  void focusRail([String? destinationId]) {
    _railKey.currentState?.requestFocus(destinationId ?? widget.selectedId);
  }

  TvScreenFocusController _controllerFor(String destinationId) {
    return _focusControllers.putIfAbsent(
      destinationId,
      TvScreenFocusController.new,
    );
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_syncTraversableRegion);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_syncTraversableRegion);
    _railRegion.dispose();
    _contentRegion.dispose();
    super.dispose();
  }

  // Runs after the focus manager has finished notifying nodes; flipping
  // traversability from a node's own focus callback would mutate the set the
  // manager is iterating.
  void _syncTraversableRegion() {
    final railFocused = _railRegion.hasFocus;
    if (!railFocused && !_contentRegion.hasFocus) return;
    _railRegion.descendantsAreTraversable = railFocused;
    _contentRegion.descendantsAreTraversable = !railFocused;
  }

  /// Sees every key the focused screen left unhandled. Left with nowhere to go
  /// inside the screen returns to the selected destination, not whichever
  /// rail item happens to sit level with the focused card.
  KeyEventResult _handleContentKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    if (focused != null && focused.focusInDirection(TraversalDirection.left)) {
      return KeyEventResult.handled;
    }
    focusRail();
    return KeyEventResult.handled;
  }

  /// Moves focus into the screen that is showing and returns whether it moved.
  ///
  /// Right from any rail item lands here, so it never switches destinations
  /// behind the user's back.
  bool enterContent() {
    final controller = _controllerFor(widget.selectedId);
    if (controller.isAttached && controller.requestFocus()) return true;
    // Screens without an entry point (or with nothing to enter yet) take the
    // nearest control to the right, like any other directional move.
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return false;
    final wasTraversable = _contentRegion.descendantsAreTraversable;
    _contentRegion.descendantsAreTraversable = true;
    final moved = focused.focusInDirection(TraversalDirection.right);
    if (!moved) _contentRegion.descendantsAreTraversable = wasTraversable;
    return moved;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Focus(
          focusNode: _railRegion,
          child: TvNavigationRail(
            key: _railKey,
            destinations: widget.destinations,
            selectedId: widget.selectedId,
            autofocusId: widget.selectedId,
            metrics: widget.metrics,
            onDestinationSelected: widget.onDestinationSelected,
            onMoveRight: (_) => enterContent(),
          ),
        ),
        SizedBox(width: widget.metrics.railGap),
        Expanded(
          child: Focus(
            focusNode: _contentRegion,
            child: ClipRect(
              // Only the active destination stays mounted; keeping every
              // screen alive held their images and controllers in TV RAM.
              child: KeyedSubtree(
                key: ValueKey<String>(widget.selectedId),
                child: widget.screenBuilder(
                  context,
                  widget.selectedId,
                  _controllerFor(widget.selectedId),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
