import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';

/// A list row: icon, label and current value, turning white under focus the
/// way Netflix's settings rows do.
class TvListRow extends StatefulWidget {
  const TvListRow({
    required this.label,
    required this.onActivate,
    this.icon,
    this.value,
    this.focusNode,
    this.autofocus = false,
    this.showsNext = true,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final IconData? icon;
  final String? value;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final bool autofocus;

  /// A caret for rows that open something.
  final bool showsNext;
  final String? semanticLabel;

  @override
  State<TvListRow> createState() => _TvListRowState();
}

class _TvListRowState extends State<TvListRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final foreground = _focused ? palette.onFocus : palette.foreground;
    final secondary = _focused ? palette.onFocusMuted : palette.mutedText;
    final icon = widget.icon;
    final value = widget.value;
    return TvFocusable(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      semanticLabel: widget.semanticLabel ??
          (value == null ? widget.label : '${widget.label}, $value'),
      onActivate: widget.onActivate,
      onFocusChanged: (hasFocus) {
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _focused ? palette.focusFill : Colors.transparent,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: secondary, size: 22),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontFamily: 'FigtreeSB',
                  fontSize: 18,
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: TextStyle(color: secondary, fontSize: 16),
              ),
            if (widget.showsNext) ...<Widget>[
              const SizedBox(width: 10),
              Icon(PhosphorIcons.caretRight(), color: secondary, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
