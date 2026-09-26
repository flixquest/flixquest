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

class TvNavigationRail extends StatefulWidget {
  const TvNavigationRail({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    required this.metrics,
    this.autofocusId,
    this.onMoveRight,
    super.key,
  });

  final List<TvNavigationDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onDestinationSelected;
  final TvShellMetrics metrics;
  final String? autofocusId;
  final bool Function(String destinationId)? onMoveRight;

  @override
  State<TvNavigationRail> createState() => TvNavigationRailState();
}

class TvNavigationRailState extends State<TvNavigationRail> {
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};

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

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Container(
        width: widget.metrics.railWidth,
        decoration: const BoxDecoration(color: Color(0xb3000000)),
        padding: EdgeInsets.symmetric(
          horizontal: (widget.metrics.railWidth < 140) ? 5 : 9,
          vertical: (widget.metrics.railWidth < 140) ? 8 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                (widget.metrics.railWidth < 140) ? 10 : 8,
                0,
                (widget.metrics.railWidth < 140) ? 10 : 8,
                (widget.metrics.railWidth < 140) ? 8 : 14,
              ),
              child: (widget.metrics.railWidth < 140)
                  ? AppLogo(
                      fallbackAsset: 'assets/images/fq_svg.svg',
                      height: 22,
                      fallbackColor: colors.primary,
                    )
                  : Text(
                      'FLIXQUEST',
                      style: TextStyle(
                        color: colors.primary,
                        fontFamily: 'FigtreeBold',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemExtent =
                      widget.metrics.navItemHeight + widget.metrics.navItemGap;
                  final contentHeight = widget.destinations.isEmpty
                      ? 0.0
                      : widget.destinations.length * itemExtent -
                          widget.metrics.navItemGap;
                  final centeredInset =
                      ((constraints.maxHeight - contentHeight) / 2)
                          .clamp(0.0, double.infinity);
                  return ListView.separated(
                    padding: EdgeInsets.symmetric(vertical: centeredInset),
                    itemCount: widget.destinations.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: widget.metrics.navItemGap),
                    itemBuilder: (context, index) {
                      final destination = widget.destinations[index];
                      return TvFocusable(
                        focusNode: _focusNodes[destination.id],
                        autofocus: destination.id == initialFocusId,
                        selected: destination.id == widget.selectedId,
                        semanticLabel: destination.label,
                        onKeyEvent: (_, event) =>
                            _handleDestinationKey(destination.id, event),
                        onFocusChanged: (hasFocus) {
                          if (hasFocus) {
                            memory?.remember(
                              scopeId: 'tv-navigation',
                              itemId: destination.id,
                            );
                          }
                        },
                        onActivate: () =>
                            widget.onDestinationSelected(destination.id),
                        focusScale: 1.015,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(6)),
                        child: Container(
                          height: widget.metrics.navItemHeight,
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                (widget.metrics.railWidth < 140) ? 0 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: destination.id == widget.selectedId
                                ? Colors.white.withValues(alpha: 0.055)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              if (destination.id == widget.selectedId)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 2,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              Row(
                                mainAxisAlignment:
                                    (widget.metrics.railWidth < 140)
                                        ? MainAxisAlignment.center
                                        : MainAxisAlignment.start,
                                children: <Widget>[
                                  Icon(
                                    destination.id == widget.selectedId
                                        ? destination.selectedIcon ??
                                            destination.icon
                                        : destination.icon,
                                    color: destination.id == widget.selectedId
                                        ? colors.onSurface
                                        : colors.onSurfaceVariant,
                                    size: (widget.metrics.railWidth < 140)
                                        ? 22
                                        : 24,
                                  ),
                                  if (!(widget.metrics.railWidth <
                                      140)) ...<Widget>[
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        destination.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: destination.id ==
                                                  widget.selectedId
                                              ? colors.onSurface
                                              : colors.onSurfaceVariant,
                                          fontFamily: destination.id ==
                                                  widget.selectedId
                                              ? 'FigtreeSB'
                                              : 'Figtree',
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
