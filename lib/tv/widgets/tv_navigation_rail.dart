import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tv_design.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_focusable.dart';
import '../../widgets/app_logo.dart';

class TvNavigationDestination {
  const TvNavigationDestination({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// The shell's destinations as a floating column of icons that widens to show
/// labels while it has focus.
///
/// It paints no background of its own: collapsed, it sits over the screen's
/// artwork; [expanded], the shell supplies the scrim behind it.
class TvNavigationRail extends StatefulWidget {
  const TvNavigationRail({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    required this.metrics,
    this.expanded = false,
    this.autofocusId,
    this.onMoveRight,
    super.key,
  });

  final List<TvNavigationDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onDestinationSelected;
  final TvShellMetrics metrics;
  final bool expanded;
  final String? autofocusId;
  final bool Function(String destinationId)? onMoveRight;

  @override
  State<TvNavigationRail> createState() => TvNavigationRailState();
}

class TvNavigationRailState extends State<TvNavigationRail> {
  static const _motion = Duration(milliseconds: 220);

  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  String? _focusedId;

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
  }

  @override
  void didUpdateWidget(TvNavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusNodes();
  }

  void _syncFocusNodes() {
    final ids = widget.destinations.map((item) => item.id).toSet();
    assert(
      ids.length == widget.destinations.length,
      'TV navigation destination IDs must be unique.',
    );
    for (final destination in widget.destinations) {
      _focusNodes.putIfAbsent(
        destination.id,
        () => FocusNode(debugLabel: 'TV nav ${destination.label}'),
      );
    }
    final removedIds =
        _focusNodes.keys.where((id) => !ids.contains(id)).toList();
    for (final id in removedIds) {
      _focusNodes.remove(id)?.dispose();
    }
  }

  void requestFocus(String destinationId) {
    _focusNodes[destinationId]?.requestFocus();
  }

  bool get hasFocus => _focusNodes.values.any((node) => node.hasFocus);

  KeyEventResult _handleDestinationKey(
    String destinationId,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    return widget.onMoveRight?.call(destinationId) == true
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = TvFocusMemoryScope.maybeOf(context);
    final initialFocusId =
        memory?.recall('tv-navigation') ?? widget.autofocusId;
    final colors = Theme.of(context).colorScheme;
    final metrics = widget.metrics;
    final expanded = widget.expanded;

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: AnimatedContainer(
        duration: _motion,
        curve: Curves.easeOutCubic,
        width: expanded ? metrics.expandedRailWidth : metrics.railWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: metrics.navItemHeight,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: metrics.railWidth,
                    child: Center(
                      child: AppLogo(
                        fallbackAsset: 'assets/images/fq_svg.svg',
                        height: 24,
                        fallbackColor: colors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Label(
                      visible: expanded,
                      child: Text(
                        'FLIXQUEST',
                        style: TextStyle(
                          color: colors.primary,
                          fontFamily: 'FigtreeBold',
                          fontSize: 18,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                // Centered while every destination fits, scrolling otherwise.
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final destination in widget.destinations)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: metrics.navItemGap / 2,
                            ),
                            child: _buildDestination(
                              destination,
                              memory: memory,
                              autofocus: destination.id == initialFocusId,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestination(
    TvNavigationDestination destination, {
    required TvFocusMemory? memory,
    required bool autofocus,
  }) {
    final colors = Theme.of(context).colorScheme;
    final metrics = widget.metrics;
    final selected = destination.id == widget.selectedId;
    final focused = destination.id == _focusedId;
    // Focus reads as a filled pill, the strongest signal at ten feet; the
    // selected destination keeps its accent bar either way.
    final foreground = focused
        ? Colors.black
        : selected
            ? TvDesign.foreground
            : widget.expanded
                ? TvDesign.mutedText
                : TvDesign.mutedText.withValues(alpha: 0.75);

    return TvFocusable(
      focusNode: _focusNodes[destination.id],
      autofocus: autofocus,
      selected: selected,
      semanticLabel: destination.label,
      onKeyEvent: (_, event) => _handleDestinationKey(destination.id, event),
      onFocusChanged: (hasFocus) {
        if (hasFocus) {
          memory?.remember(scopeId: 'tv-navigation', itemId: destination.id);
        }
        final focusedId = hasFocus
            ? destination.id
            : (_focusedId == destination.id ? null : _focusedId);
        if (focusedId != _focusedId) setState(() => _focusedId = focusedId);
      },
      onActivate: () => widget.onDestinationSelected(destination.id),
      focusScale: 1,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(metrics.navItemHeight / 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: metrics.navItemHeight,
        decoration: BoxDecoration(
          color: focused ? const Color(0xf2ffffff) : Colors.transparent,
          borderRadius: BorderRadius.circular(metrics.navItemHeight / 2),
        ),
        child: Stack(
          children: <Widget>[
            if (selected && !focused)
              Positioned(
                left: 2,
                top: metrics.navItemHeight * 0.3,
                bottom: metrics.navItemHeight * 0.3,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Row(
              children: <Widget>[
                SizedBox(
                  // Two less than the rail, clearing the pill's 2px border.
                  width: metrics.railWidth - 4,
                  child: Icon(
                    selected
                        ? destination.selectedIcon ?? destination.icon
                        : destination.icon,
                    color: foreground,
                    size: metrics.compact ? 22 : 24,
                  ),
                ),
                Expanded(
                  child: _Label(
                    visible: widget.expanded,
                    child: Text(
                      destination.label,
                      style: TextStyle(
                        color: foreground,
                        fontFamily:
                            focused || selected ? 'FigtreeSB' : 'Figtree',
                        fontSize: metrics.compact ? 17 : 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A rail label, faded in as the rail widens and never wrapped or ellipsized
/// while the width animates.
class _Label extends StatelessWidget {
  const _Label({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: visible ? const Interval(0.3, 1) : Curves.easeOut,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: DefaultTextStyle.merge(
            maxLines: 1,
            softWrap: false,
            child: child,
          ),
        ),
      ),
    );
  }
}
