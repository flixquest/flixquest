import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';

/// A touch button in the TV's language: the main action solid ink (Play),
/// others a soft fill (My List). Never the accent.
class PillButton extends StatelessWidget {
  const PillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.busy = false,
    this.height = 40,
    this.onArtwork = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;

  /// Shows a small spinner in place of the icon while the action starts.
  final bool busy;
  final double height;

  /// Over artwork, which is dark in every theme: a white main button and a
  /// translucent white one, as on the player.
  final bool onArtwork;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final Color background;
    final Color foreground;
    if (onArtwork) {
      background = primary ? const Color(0xF2FFFFFF) : const Color(0x38FFFFFF);
      foreground = primary ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    } else {
      background = primary ? palette.focusFill : palette.idleFill;
      foreground = primary ? palette.onFocus : palette.foreground;
    }
    final icon = this.icon;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null || busy
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          splashColor: foreground.withValues(alpha: .12),
          highlightColor: foreground.withValues(alpha: .06),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 16, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (busy)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 20, color: foreground),
                  if (busy || icon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppType.semiBold,
                        fontSize: 15,
                        height: 1.2,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
