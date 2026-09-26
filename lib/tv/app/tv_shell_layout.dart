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

/// Where a full-bleed screen's controls go: clear of the collapsed rail on the
/// leading edge and of the TV's overscan margins on the others.
///
/// Only [TvShellLayout.fullBleedDestinations] see it; every other screen is
/// laid out inside these insets already.
class TvShellInsets extends InheritedWidget {
  const TvShellInsets({
    required this.insets,
    required super.child,
    super.key,
  });

  final EdgeInsets insets;

  /// Zero outside a shell, so a full-bleed screen also lays out on its own.
  static EdgeInsets of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvShellInsets>()?.insets ??
      EdgeInsets.zero;

  @override
  bool updateShouldNotify(TvShellInsets oldWidget) =>
      insets != oldWidget.insets;
}

/// The navigation rail over the active destination's screen, and the D-pad
/// contract between them.
///
/// The rail floats: collapsed it is a column of icons at the leading edge, and
/// with focus it widens to show labels over a scrim that dims the screen.
class TvShellLayout extends StatefulWidget {
  const TvShellLayout({
    required this.destinations,
    required this.selectedId,
    required this.metrics,
    required this.onDestinationSelected,
    required this.screenBuilder,
    this.fullBleedDestinations = const <String>{},
    super.key,
  });

  final List<TvNavigationDestination> destinations;
  final String selectedId;
  final TvShellMetrics metrics;
  final ValueChanged<String> onDestinationSelected;
  final TvShellScreenBuilder screenBuilder;

  /// Screens that fill the whole display, artwork running under the rail to
  /// the screen edge, and place their controls with [TvShellInsets].
  final Set<String> fullBleedDestinations;

  @override
  State<TvShellLayout> createState() => TvShellLayoutState();
}

class TvShellLayoutState extends State<TvShellLayout>
    with SingleTickerProviderStateMixin {
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

  static const _railMotion = Duration(milliseconds: 220);

  /// A new destination fades in over the one it replaces. Only the incoming
  /// screen is faded, so the crossfade costs one offscreen layer, not two.
  late final AnimationController _pageFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final Animation<double> _pageOpacity =
      CurvedAnimation(parent: _pageFade, curve: Curves.easeOut);

  /// Each mounted screen's key, so a screen keeps its state while it moves
  /// in and out of the fade's wrappers.
  final Map<String, GlobalKey> _screenKeys = <String, GlobalKey>{};

  /// The screen being faded out, as last built, and the one showing now.
  Widget? _outgoingScreen;
  Widget? _currentScreen;

  /// Tracks focus in the rail rather than reading it while building, so the
  /// rail widens and the scrim fades in the frame focus arrives.
  bool _railExpanded = false;

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
    // Created up front: a lazy one first read in dispose() would look up
    // TickerMode on a deactivated element.
    _pageFade.value = 1;
    _railRegion.addListener(_syncRailExpanded);
  }

  void _syncRailExpanded() {
    final expanded = _railRegion.hasFocus;
    if (expanded != _railExpanded && mounted) {
      setState(() => _railExpanded = expanded);
    }
  }

  @override
  void didUpdateWidget(TvShellLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousId = oldWidget.selectedId;
    if (previousId == widget.selectedId) return;
    // A switch during a fade drops the screen already on its way out.
    final dropped = _outgoingScreen?.key;
    _outgoingScreen = _currentScreen;
    _screenKeys.removeWhere(
      (id, key) => identical(key, dropped) && id != widget.selectedId,
    );
    _pageFade.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted || _pageFade.isAnimating) return;
      setState(() {
        _screenKeys.removeWhere(
          (id, key) =>
              identical(key, _outgoingScreen?.key) && id != widget.selectedId,
        );
        _outgoingScreen = null;
      });
    });
  }

  @override
  void dispose() {
    _pageFade.dispose();
    _railRegion.removeListener(_syncRailExpanded);
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
    final palette = TvPalette.of(context);
    final metrics = widget.metrics;
    final system = MediaQuery.paddingOf(context);
    double safe(double systemInset) =>
        systemInset > metrics.safeInset ? systemInset : metrics.safeInset;
    final railInset = safe(system.left);
    final contentInsets = EdgeInsets.fromLTRB(
      railInset + metrics.railWidth + metrics.railGap,
      safe(system.top),
      safe(system.right),
      safe(system.bottom),
    );
    final screen = widget.screenBuilder(
      context,
      widget.selectedId,
      _controllerFor(widget.selectedId),
    );
    final current = _currentScreen = KeyedSubtree(
      key: _screenKeys.putIfAbsent(widget.selectedId, GlobalKey.new),
      child: widget.fullBleedDestinations.contains(widget.selectedId)
          ? TvShellInsets(insets: contentInsets, child: screen)
          : Padding(padding: contentInsets, child: screen),
    );
    final outgoing = _outgoingScreen;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FocusScope.withExternalFocusNode(
          focusScopeNode: _contentRegion,
          child: ClipRect(
            // Only the active destination stays mounted, apart from the one
            // fading out; keeping every screen alive held their images and
            // controllers in TV RAM.
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (outgoing != null)
                  ExcludeFocus(child: IgnorePointer(child: outgoing)),
                if (outgoing != null)
                  FadeTransition(opacity: _pageOpacity, child: current)
                else
                  current,
              ],
            ),
          ),
        ),
        // One gradient both backs the expanded labels and dims the screen, so
        // opening the rail costs a single full-screen draw.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _railExpanded ? 1 : 0,
            duration: _railMotion,
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // Opaque under the labels, where the screen's own text would
                  // otherwise ghost through them, then a dim over the rest.
                  colors: <Color>[
                    palette.scrim(1),
                    palette.scrim(0.97),
                    palette.scrim(0.6),
                    palette.scrim(0.45),
                  ],
                  stops: const <double>[0, 0.27, 0.5, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: railInset,
          top: contentInsets.top,
          bottom: contentInsets.bottom,
          child: FocusScope.withExternalFocusNode(
            focusScopeNode: _railRegion,
            child: TvNavigationRail(
              key: _railKey,
              destinations: widget.destinations,
              selectedId: widget.selectedId,
              autofocusId: widget.selectedId,
              metrics: metrics,
              expanded: _railExpanded,
              onDestinationSelected: widget.onDestinationSelected,
              onMoveRight: (_) => enterContent(),
            ),
          ),
        ),
      ],
    );
  }
}
