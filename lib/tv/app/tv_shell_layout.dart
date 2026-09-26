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

  // Flutter's arrow-key traversal searches the nearest focus scope, so giving
  // the rail and the screen a scope each keeps them from leaking into each
  // other at their edges; crossing between them is always explicit.
  //
  // Toggling `descendantsAreTraversable` on one shared scope did the same job
  // but broke traversal for good: a `Focus` given a node copies the node's
  // inherited skip-traversal state into it whenever it rebuilds, so anything
  // rebuilt while its side was switched off stayed unreachable.
  final FocusScopeNode _railRegion = FocusScopeNode(
    debugLabel: 'TV shell rail',
    skipTraversal: true,
  );
  late final FocusScopeNode _contentRegion = FocusScopeNode(
    debugLabel: 'TV shell content',
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
  void dispose() {
    _railRegion.dispose();
    _contentRegion.dispose();
    super.dispose();
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
    if (focused == null || focused.context == null) return false;
    final target = _nearestContentNode(focused.rect);
    target?.requestFocus();
    return target != null;
  }

  /// The content control a move right from [origin] lands on: the leftmost
  /// one level with it, else the closest. Directional traversal cannot find it
  /// itself, since it stays inside the rail's scope.
  FocusNode? _nearestContentNode(Rect origin) {
    final candidates = _contentRegion.traversalDescendants
        .where((node) => node is! FocusScopeNode && node.context != null)
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    final level = candidates.where(
      (node) => node.rect.top < origin.bottom && node.rect.bottom > origin.top,
    );
    if (level.isNotEmpty) {
      return level.reduce((a, b) => b.rect.left < a.rect.left ? b : a);
    }
    double distance(FocusNode node) =>
        (node.rect.center - origin.center).distanceSquared;
    return candidates.reduce((a, b) => distance(b) < distance(a) ? b : a);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FocusScope.withExternalFocusNode(
          focusScopeNode: _railRegion,
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
          child: FocusScope.withExternalFocusNode(
            focusScopeNode: _contentRegion,
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
