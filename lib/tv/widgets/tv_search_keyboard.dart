import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';

/// Search's own keyboard: letters and digits in a six-column grid under
/// Space, Delete and Clear, steered with the D-pad, the way Netflix's is.
///
/// Arrows move key to key by column, so Up and Down land where expected even
/// between the wide keys and the letters. Right off the last column and Left
/// off the first are handed to [onExitRight] and to whatever is around the
/// keyboard. A hardware keyboard types straight in while any key has focus.
class TvSearchKeyboard extends StatefulWidget {
  const TvSearchKeyboard({
    required this.onType,
    required this.onDelete,
    required this.onClear,
    this.onExitRight,
    this.width = 300,
    super.key,
  });

  final ValueChanged<String> onType;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  /// Right off the last column; returns whether focus left the keyboard.
  final bool Function()? onExitRight;
  final double width;

  static const columns = 6;

  /// The letters and digits, a row per [columns].
  static const characters = 'abcdefghijklmnopqrstuvwxyz1234567890';

  @override
  State<TvSearchKeyboard> createState() => TvSearchKeyboardState();
}

/// A key's place in the grid: its row and the columns it spans.
class _KeySpec {
  const _KeySpec({
    required this.id,
    required this.row,
    required this.column,
    this.span = 1,
  });

  final String id;
  final int row;
  final int column;
  final int span;

  bool covers(int col) => col >= column && col < column + span;
}

class TvSearchKeyboardState extends State<TvSearchKeyboard> {
  static const _space = 'space';
  static const _delete = 'delete';
  static const _clear = 'clear';

  static final List<_KeySpec> _keys = <_KeySpec>[
    const _KeySpec(id: _space, row: 0, column: 0, span: 2),
    const _KeySpec(id: _delete, row: 0, column: 2, span: 2),
    const _KeySpec(id: _clear, row: 0, column: 4, span: 2),
    for (var i = 0; i < TvSearchKeyboard.characters.length; i++)
      _KeySpec(
        id: TvSearchKeyboard.characters[i],
        row: 1 + i ~/ TvSearchKeyboard.columns,
        column: i % TvSearchKeyboard.columns,
      ),
  ];

  static final int _rowCount = _keys.map((key) => key.row).reduce(
            (a, b) => a > b ? a : b,
          ) +
      1;

  final Map<String, FocusNode> _nodes = <String, FocusNode>{};

  /// The key focus returns to, and the column Up and Down aim for, so moving
  /// through a wide key keeps to the column it was entered from.
  String _lastKey = 'a';
  int _column = 0;

  FocusNode _node(String id) => _nodes.putIfAbsent(
        id,
        () => FocusNode(
          debugLabel: 'TV keyboard $id',
          onKeyEvent: (_, event) => _handleKey(id, event),
        ),
      );

  /// Focuses the key last used, and returns whether focus moved.
  bool requestFocus() {
    final node = _nodes[_lastKey];
    if (node == null || node.context == null) return false;
    node.requestFocus();
    return true;
  }

  bool get hasFocus => _nodes.values.any((node) => node.hasFocus);

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  _KeySpec _spec(String id) => _keys.firstWhere((key) => key.id == id);

  _KeySpec? _at(int row, int column) {
    for (final key in _keys) {
      if (key.row == row && key.covers(column)) return key;
    }
    return null;
  }

  void _focus(_KeySpec key) => _nodes[key.id]?.requestFocus();

  KeyEventResult _handleKey(String id, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final spec = _spec(id);
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (spec.column == 0) return KeyEventResult.ignored;
      final target = _at(spec.row, spec.column - 1)!;
      _column = target.column;
      _focus(target);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final next = spec.column + spec.span;
      if (next >= TvSearchKeyboard.columns) {
        widget.onExitRight?.call();
        return KeyEventResult.handled;
      }
      final target = _at(spec.row, next)!;
      _column = target.column;
      _focus(target);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final row = spec.row + (key == LogicalKeyboardKey.arrowUp ? -1 : 1);
      // Nothing above or below: stay rather than wander out of the keyboard.
      if (row >= 0 && row < _rowCount) {
        final column = spec.covers(_column) ? _column : spec.column;
        final target = _at(row, column) ?? _at(row, 0)!;
        _column = column;
        _focus(target);
      }
      return KeyEventResult.handled;
    }
    // A hardware keyboard types straight in.
    if (key == LogicalKeyboardKey.backspace) {
      widget.onDelete();
      return KeyEventResult.handled;
    }
    final character = event.character?.toLowerCase();
    if (character != null &&
        character.length == 1 &&
        (TvSearchKeyboard.characters.contains(character) || character == ' ')) {
      widget.onType(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activate(String id) {
    switch (id) {
      case _space:
        widget.onType(' ');
      case _delete:
        widget.onDelete();
      case _clear:
        widget.onClear();
      default:
        widget.onType(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.width / TvSearchKeyboard.columns;
    Widget row(int index) => Row(
          children: <Widget>[
            for (final key in _keys.where((key) => key.row == index))
              SizedBox(
                width: unit * key.span,
                height: unit * 0.82,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _Key(
                    focusNode: _node(key.id),
                    label: switch (key.id) {
                      _space => 'Space',
                      _delete => 'Delete',
                      _clear => 'Clear',
                      final letter => letter,
                    },
                    icon: switch (key.id) {
                      _space => PhosphorIcons.arrowsHorizontal(),
                      _delete => PhosphorIcons.backspace(),
                      _clear => PhosphorIcons.x(),
                      _ => null,
                    },
                    onFocused: () {
                      _lastKey = key.id;
                      if (!key.covers(_column)) _column = key.column;
                    },
                    onActivate: () => _activate(key.id),
                  ),
                ),
              ),
          ],
        );
    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          row(0),
          const SizedBox(height: 6),
          for (var index = 1; index < _rowCount; index++) row(index),
        ],
      ),
    );
  }
}

/// A key: its label in muted type, and a white tile under focus, the way
/// the rail's destinations light up.
class _Key extends StatefulWidget {
  const _Key({
    required this.focusNode,
    required this.label,
    required this.onFocused,
    required this.onActivate,
    this.icon,
  });

  final FocusNode focusNode;
  final String label;
  final IconData? icon;
  final VoidCallback onFocused;
  final VoidCallback onActivate;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final foreground = _focused ? palette.onFocus : palette.foreground;
    final icon = widget.icon;
    return TvFocusable(
      focusNode: widget.focusNode,
      semanticLabel: widget.label,
      onActivate: widget.onActivate,
      onFocusChanged: (hasFocus) {
        if (hasFocus) widget.onFocused();
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      scrollAlignment: null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _focused ? palette.focusFill : palette.idleFillFaint,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: icon != null
            ? Icon(icon, color: foreground, size: 20)
            : Text(
                widget.label,
                style: TextStyle(
                  color: foreground,
                  fontFamily: 'FigtreeSB',
                  fontSize: 18,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
