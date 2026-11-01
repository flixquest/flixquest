import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import 'tv_pill_button.dart';

/// The arrow that points from the fields to the keyboard.
LogicalKeyboardKey tvTowardKeyboard(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;

/// A field as the remote sees it: a tile showing what has been typed, with a
/// cursor while it is the one the keyboard fills. Select, or the arrow
/// toward the keyboard, hands focus to it.
class TvFormFieldTile extends StatefulWidget {
  const TvFormFieldTile({
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.value,
    required this.obscured,
    required this.active,
    required this.compact,
    required this.onFocused,
    required this.onActivate,
    this.error,
    this.trailing,
    super.key,
  });

  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final String value;
  final bool obscured;
  final bool active;
  final bool compact;
  final String? error;
  final VoidCallback onFocused;
  final bool Function() onActivate;

  /// Beside the tile, where Right goes first.
  final Widget? trailing;

  @override
  State<TvFormFieldTile> createState() => _TvFormFieldTileState();
}

class _TvFormFieldTileState extends State<TvFormFieldTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final error = widget.error;
    final empty = widget.value.isEmpty;
    final foreground = _focused ? palette.onFocus : palette.foreground;
    final muted = _focused ? palette.onFocusMuted : palette.mutedText;
    final shown = widget.obscured ? '•' * widget.value.length : widget.value;
    final valueSize = widget.compact ? 18.0 : 21.0;
    final tile = TvFocusable(
      focusNode: widget.focusNode,
      semanticLabel: widget.label,
      onActivate: () => widget.onActivate(),
      onFocusChanged: (hasFocus) {
        if (hasFocus) widget.onFocused();
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      onKeyEvent: (_, event) {
        if (widget.trailing == null &&
            event is KeyDownEvent &&
            event.logicalKey == tvTowardKeyboard(context) &&
            widget.onActivate()) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      focusScale: 1,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: widget.compact ? 56 : 66,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _focused ? palette.focusFill : palette.idleFill,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius * 2),
          border: Border.all(
            color: error != null
                ? colors.error
                : widget.active && !_focused
                    ? palette.foreground
                    : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(widget.icon, color: muted, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: muted,
                      fontFamily: 'FigtreeSB',
                      fontSize: widget.compact ? 12 : 14,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Flexible(
                        // Scrolled to its end, so a long value shows what
                        // was typed last, where the cursor is.
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Text(
                            shown,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: foreground,
                              fontFamily: 'FigtreeSB',
                              fontSize: valueSize,
                              height: 1.15,
                              letterSpacing: widget.obscured ? 2 : 0,
                            ),
                          ),
                        ),
                      ),
                      if (widget.active)
                        Container(
                          width: 2,
                          height: valueSize + 2,
                          margin: EdgeInsetsDirectional.only(
                            start: empty ? 0 : 2,
                          ),
                          color: foreground,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.trailing == null)
          tile
        else
          Row(
            children: <Widget>[
              Expanded(child: tile),
              const SizedBox(width: 10),
              widget.trailing!,
            ],
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              error,
              style: TextStyle(
                color: colors.error,
                fontFamily: 'FigtreeSB',
                fontSize: widget.compact ? 13 : 15,
              ),
            ),
          ),
      ],
    );
  }
}

/// Shows or hides the password, beside its field.
class TvRevealPasswordButton extends StatelessWidget {
  const TvRevealPasswordButton({
    required this.revealed,
    required this.onActivate,
    required this.onExitTowardKeyboard,
    super.key,
  });

  final bool revealed;
  final VoidCallback onActivate;

  /// Toward the keyboard, past this button.
  final bool Function() onExitTowardKeyboard;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final label = revealed ? tr('tv_hide_password') : tr('tv_show_password');
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == tvTowardKeyboard(context) &&
            onExitTowardKeyboard()) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TvPillButton(
        label: label,
        icon: revealed ? PhosphorIcons.eyeSlash() : PhosphorIcons.eye(),
        onActivate: onActivate,
        height: 46,
      ),
    );
  }
}
