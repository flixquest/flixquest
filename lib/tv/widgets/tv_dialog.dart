import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../focus/tv_keymap.dart';

class TvDialogAction {
  const TvDialogAction({
    required this.label,
    required this.onPressed,
    this.autofocus = false,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool autofocus;
  final bool isPrimary;
}

Future<T?> showTvDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<TvDialogAction> actions,
  bool barrierDismissible = false,
  bool autofocusFirstAction = true,
}) {
  assert(actions.isNotEmpty);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => TvDialog(
      title: title,
      content: content,
      actions: actions,
      autofocusFirstAction: autofocusFirstAction,
    ),
  );
}

class TvDialog extends StatefulWidget {
  const TvDialog({
    required this.title,
    required this.content,
    required this.actions,
    this.autofocusFirstAction = true,
    super.key,
  });

  final String title;
  final Widget content;
  final List<TvDialogAction> actions;
  final bool autofocusFirstAction;

  @override
  State<TvDialog> createState() => _TvDialogState();
}

class _TvDialogState extends State<TvDialog> {
  late final FocusScopeNode _focusScopeNode;
  late List<FocusNode> _actionFocusNodes;

  List<FocusNode> _createActionFocusNodes() => List<FocusNode>.generate(
        widget.actions.length,
        (index) => FocusNode(
          debugLabel: widget.actions[index].label,
          onKeyEvent: (node, event) => _handleActionKey(index, event),
        ),
      );

  void _disposeActionFocusNodes() {
    for (final node in _actionFocusNodes) {
      node.dispose();
    }
  }

  KeyEventResult _handleActionKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Horizontal arrows step through choices, including a wrapped line.
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final target =
          index + (event.logicalKey == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      if (target >= 0 && target < _actionFocusNodes.length) {
        _actionFocusNodes[target].requestFocus();
      }
      return KeyEventResult.handled;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    _actionFocusNodes[index].focusInDirection(direction);
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    _focusScopeNode = FocusScopeNode(debugLabel: 'TV dialog');
    _actionFocusNodes = _createActionFocusNodes();
  }

  @override
  void didUpdateWidget(TvDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions.length != widget.actions.length) {
      _disposeActionFocusNodes();
      _actionFocusNodes = _createActionFocusNodes();
    }
  }

  @override
  void dispose() {
    _disposeActionFocusNodes();
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasExplicitAutofocus =
        widget.actions.any((action) => action.autofocus);

    return Dialog(
      backgroundColor: TvDesign.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.54),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FocusScope(
          node: _focusScopeNode,
          child: TvKeymap(
            onBack: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                clipBehavior: Clip.hardEdge,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: TvDesign.foreground,
                        fontFamily: 'FigtreeBold',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DefaultTextStyle(
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Figtree',
                        fontSize: 22,
                        height: 1.35,
                      ),
                      child: widget.content,
                    ),
                    const SizedBox(height: 30),
                    FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: <Widget>[
                          for (var index = 0;
                              index < widget.actions.length;
                              index++)
                            Builder(
                              builder: (context) {
                                final action = widget.actions[index];
                                return TvFocusable(
                                  semanticLabel: action.label,
                                  focusNode: _actionFocusNodes[index],
                                  autofocus: action.autofocus ||
                                      (widget.autofocusFirstAction &&
                                          !hasExplicitAutofocus &&
                                          index == 0),
                                  onActivate: action.onPressed,
                                  focusScale: 1.03,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 26,
                                      vertical: 15,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: action.isPrimary
                                          ? LinearGradient(
                                              colors: <Color>[
                                                colorScheme.primary,
                                                Color.lerp(
                                                  colorScheme.primary,
                                                  colorScheme.primaryContainer,
                                                  0.3,
                                                )!,
                                              ],
                                            )
                                          : null,
                                      color: action.isPrimary
                                          ? null
                                          : TvDesign.raisedSurface,
                                      border: Border.all(
                                        color: action.isPrimary
                                            ? colorScheme.primary
                                                .withValues(alpha: 0.5)
                                            : colorScheme.onSurface
                                                .withValues(alpha: 0.09),
                                      ),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      action.label,
                                      style: TextStyle(
                                        color: action.isPrimary
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurface,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
