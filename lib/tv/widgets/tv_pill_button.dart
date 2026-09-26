import 'package:flutter/material.dart';

import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';

/// The TV's one button: translucent at rest, white with black text under
/// focus, the way the rail's destinations light up.
///
/// [prominent] marks a screen's main action with a brighter resting fill; the
/// focused button is white either way, so the accent colour never has to say
/// "this is the button".
class TvPillButton extends StatefulWidget {
  const TvPillButton({
    required this.label,
    required this.onActivate,
    this.icon,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.prominent = false,
    this.semanticLabel,
    this.onFocusChanged,
    this.height = 44,
    this.scrollAlignment = 0.45,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool prominent;
  final String? semanticLabel;
  final ValueChanged<bool>? onFocusChanged;
  final double height;

  /// Where a scrolling page brings the button to on focus; null leaves the
  /// page where it is.
  final double? scrollAlignment;

  @override
  State<TvPillButton> createState() => _TvPillButtonState();
}

class _TvPillButtonState extends State<TvPillButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final foreground = !widget.enabled
        ? palette.mutedText.withValues(alpha: 0.5)
        : _focused
            ? palette.onFocus
            : palette.foreground;
    final icon = widget.icon;
    return TvFocusable(
      focusNode: widget.focusNode,
      semanticLabel: widget.semanticLabel ?? widget.label,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onActivate: widget.onActivate,
      onFocusChanged: (hasFocus) {
        widget.onFocusChanged?.call(hasFocus);
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1.04,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      scrollAlignment: widget.scrollAlignment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _focused
              ? palette.focusFill
              : widget.prominent
                  ? palette.idleFillStrong
                  : palette.idleFill,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontFamily: 'FigtreeSB',
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
